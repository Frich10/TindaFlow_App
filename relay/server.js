'use strict';

/**
 * TindaFlow OTP SMTP Relay
 * -------------------------
 * Runs on your own PC (no cloud / no Blaze). It holds the Gmail app password
 * locally and exposes a tiny HTTP endpoint the TindaFlow app calls on the same
 * Wi-Fi to email a password-reset OTP.
 *
 *   npm install
 *   npm start
 *
 * Then set the app's "Relay server URL" (see OTP RELAY section in
 * lib/data/otp_service.dart) to:  http://<this-pc-LAN-IP>:5000
 *
 * Environment overrides (optional):
 *   SMTP_HOST (default smtp.gmail.com)
 *   SMTP_PORT (default 465)
 *   SMTP_USER (default tindaflowofficial@gmail.com)
 *   SMTP_PASS (default the app password below — change for your setup)
 *   RELAY_PORT (default 5000)
 */

const http = require('http');
const nodemailer = require('nodemailer');

// ─── Config ────────────────────────────────────────────────────────────────
const SMTP_HOST = process.env.SMTP_HOST || 'smtp.gmail.com';
const SMTP_PORT = Number(process.env.SMTP_PORT || 465);
const SMTP_USER = process.env.SMTP_USER || 'tindaflowofficial@gmail.com';
// On a public host, set SMTP_PASS as an environment variable (Render secret).
// No hardcoded fallback — the relay refuses to start without it.
const SMTP_PASS = process.env.SMTP_PASS || '';
// Honor platform-injected PORT (Render/Heroku/Cloud Run), then RELAY_PORT.
const RELAY_PORT = Number(process.env.PORT || process.env.RELAY_PORT || 5000);
// Shared secret the app must send in the X-Relay-Token header. If set, requests
// without a matching token are rejected (prevents random internet callers).
const RELAY_TOKEN = process.env.RELAY_TOKEN || '';
// Rate limit: max N sends per IP+email per hour.
const RATE_LIMIT_PER_HOUR = Number(process.env.RATE_LIMIT_PER_HOUR || 5);

const APP_NAME = 'TindaFlow';
const FROM_EMAIL = SMTP_USER;

const MAIL_SUBJECT = 'TindaFlow password reset code';
const MAIL_BODY = (code) =>
  `Hello,\n\n` +
  `We received a request to reset the password for your ${APP_NAME} account.\n\n` +
  `Your password reset code is:\n\n    ${code}\n\n` +
  `This code expires in 10 minutes. If you did not request a password reset, ` +
  `you can safely ignore this email.\n\n` +
  `— The ${APP_NAME} team`;

// ─── Mailer ────────────────────────────────────────────────────────────────
if (!SMTP_PASS) {
  console.error('[relay] SMTP_PASS is not set. Set it as an environment variable.');
  process.exit(1);
}

const transporter = nodemailer.createTransport({
  host: SMTP_HOST,
  port: SMTP_PORT,
  secure: SMTP_PORT === 465,
  auth: { user: SMTP_USER, pass: SMTP_PASS },
});

async function sendOtpEmail(to, code) {
  return transporter.sendMail({
    from: `"${APP_NAME}" <${FROM_EMAIL}>`,
    to,
    subject: MAIL_SUBJECT,
    text: MAIL_BODY(code),
  });
}

// ─── HTTP ──────────────────────────────────────────────────────────────────
function isValidEmail(email) {
  return typeof email === 'string' && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim());
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let data = '';
    let size = 0;
    req.on('data', (chunk) => {
      size += chunk.length;
      if (size > 10000) {
        reject(new Error('payload_too_large'));
        req.destroy();
        return;
      }
      data += chunk;
    });
    req.on('end', () => {
      try {
        resolve(data ? JSON.parse(data) : {});
      } catch (_) {
        reject(new Error('invalid_json'));
      }
    });
    req.on('error', reject);
  });
}

// ─── Rate limiter (in-memory) ───────────────────────────────────────────────
// Key: IP + email. Sliding window of 1 hour, max RATE_LIMIT_PER_HOUR sends.
const _rate = new Map(); // key -> array of timestamps (ms)
function rateAllow(key) {
  const now = Date.now();
  const windowStart = now - 60 * 60 * 1000;
  const hits = (_rate.get(key) || []).filter((t) => t > windowStart);
  if (hits.length >= RATE_LIMIT_PER_HOUR) {
    _rate.set(key, hits);
    return false;
  }
  hits.push(now);
  _rate.set(key, hits);
  return true;
}
// Periodically drop stale entries so the map does not grow unbounded.
setInterval(() => {
  const cutoff = Date.now() - 60 * 60 * 1000;
  for (final [k, v] of _rate) {
    const kept = v.filter((t) => t > cutoff);
    if (kept.length === 0) _rate.delete(k);
    else _rate.set(k, kept);
  }
}, 10 * 60 * 1000).unref();

function clientIp(req) {
  return (req.headers['x-forwarded-for'] || '').split(',')[0].trim() ||
      req.socket.remoteAddress || 'unknown';
}

const server = http.createServer(async (req, res) => {
  // CORS: allow the Flutter web app (served from another origin) to call us.
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('Access-Control-Max-Age', '86400');

  // Browser preflight for cross-origin POST.
  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  // Only the OTP endpoint is exposed; everything else is 404.
  if (req.method !== 'POST' || req.url !== '/sendOtp') {
    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: false, message: 'Not found.' }));
    return;
  }

  // Shared-secret check (if configured). Only the app knows RELAY_TOKEN.
  if (RELAY_TOKEN && req.headers['x-relay-token'] !== RELAY_TOKEN) {
    res.writeHead(401, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: false, message: 'Unauthorized.' }));
    return;
  }

  try {
    const body = await readBody(req);
    const email = String(body.email || '').trim();
    const code = String(body.code || '').trim();

    if (!isValidEmail(email)) {
      res.writeHead(400, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ ok: false, message: 'Enter a valid email address.' }));
      return;
    }
    if (!/^\d{4,8}$/.test(code)) {
      res.writeHead(400, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ ok: false, message: 'Invalid code format.' }));
      return;
    }

    // Rate limit per IP + email.
    const rateKey = clientIp(req) + '|' + email.toLowerCase();
    if (!rateAllow(rateKey)) {
      res.writeHead(429, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ ok: false, message: 'Too many requests. Please wait before trying again.' }));
      return;
    }

    const info = await sendOtpEmail(email, code);
    console.log(`[relay] sent code to ${email} (${info.messageId})`);

    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: true, message: 'Code sent to ' + email + '.' }));
  } catch (err) {
    console.error('[relay] send failed:', err.message);
    res.writeHead(502, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: false, message: 'Could not send the code. Is the PC online and the app password valid?' }));
  }
});

server.listen(RELAY_PORT, '0.0.0.0', () => {
  console.log('TindaFlow OTP relay listening on http://0.0.0.0:' + RELAY_PORT);
  console.log('Set the app relay URL to: http://<this-pc-LAN-IP>:' + RELAY_PORT);
  console.log('Sending as:', SMTP_USER, 'via', SMTP_HOST + ':' + SMTP_PORT);
});