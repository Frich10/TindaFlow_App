'use strict';

/**
 * TindaFlow OTP Relay (Brevo transactional email)
 * ------------------------------------------------
 * Public HTTP endpoint that emails a password-reset / MPIN-reset OTP code using
 * the Brevo (formerly Sendinblue) transactional email API. Works from any cloud
 * host (Render, etc.) — unlike Gmail SMTP, which cloud IPs often block.
 *
 * Deploy: push to GitHub, import on Render (see render.yaml).
 *
 * Environment variables:
 *   BREVO_API_KEY   (required) — Brevo API key (v3). Get it at
 *                   https://app.brevo.com/settings/keys/api
 *   FROM_EMAIL      (required) — verified sender, e.g. tindaflowofficial@gmail.com
 *   FROM_NAME       (optional) — sender display name (default "TindaFlow")
 *   RELAY_TOKEN     (recommended) — shared secret the app sends as X-Relay-Token
 *   RATE_LIMIT_PER_HOUR (optional, default 5)
 *   PORT / RELAY_PORT (optional, default 5000)
 */

const http = require('http');

// ─── Config ────────────────────────────────────────────────────────────────
const BREVO_API_KEY = process.env.BREVO_API_KEY || '';
const FROM_EMAIL = process.env.FROM_EMAIL || 'tindaflowofficial@gmail.com';
const FROM_NAME = process.env.FROM_NAME || 'TindaFlow';
// Honor platform-injected PORT (Render/Heroku/Cloud Run), then RELAY_PORT.
const RELAY_PORT = Number(process.env.PORT || process.env.RELAY_PORT || 5000);
// Shared secret the app must send in the X-Relay-Token header. If set, requests
// without a matching token are rejected (prevents random internet callers).
const RELAY_TOKEN = process.env.RELAY_TOKEN || '';
// Rate limit: max N sends per IP+email per hour.
const RATE_LIMIT_PER_HOUR = Number(process.env.RATE_LIMIT_PER_HOUR || 5);

const APP_NAME = 'TindaFlow';
const MAIL_SUBJECT = 'TindaFlow password reset code';
const MAIL_BODY = (code) =>
  `Hello,\n\n` +
  `We received a request to reset the password for your ${APP_NAME} account.\n\n` +
  `Your password reset code is:\n\n    ${code}\n\n` +
  `This code expires in 10 minutes. If you did not request a password reset, ` +
  `you can safely ignore this email.\n\n` +
  `— The ${APP_NAME} team`;

// ─── Mailer (Brevo API) ────────────────────────────────────────────────────
if (!BREVO_API_KEY) {
  console.error('[relay] BREVO_API_KEY is not set. Set it as an environment variable.');
  process.exit(1);
}

async function sendOtpEmail(to, code) {
  const res = await fetch('https://api.brevo.com/v3/smtp/email', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'api-key': BREVO_API_KEY,
    },
    body: JSON.stringify({
      sender: { name: FROM_NAME, email: FROM_EMAIL },
      to: [{ email: to }],
      subject: MAIL_SUBJECT,
      textContent: MAIL_BODY(code),
    }),
  });
  if (!res.ok) {
    const errText = await res.text().catch(() => '');
    throw new Error(`Brevo API ${res.status}: ${errText.slice(0, 200)}`);
  }
  return res.json();
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
      } catch (e) {
        console.error('[relay] invalid_json, raw body length=', data.length, 'body=', JSON.stringify(data).slice(0, 300));
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
  res.setHeader('Access-Control-Allow-Methods', 'POST, GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, X-Relay-Token');
  res.setHeader('Access-Control-Max-Age', '86400');

  // Browser preflight for cross-origin POST.
  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  // Health check endpoint (Render pings GET / for liveness).
  if (req.method === 'GET' && req.url === '/') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: true, service: 'tindaflow-otp-relay' }));
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
    console.log(`[relay] sent code to ${email} (${info.messageId || 'ok'})`);

    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: true, message: 'Code sent to ' + email + '.' }));
  } catch (err) {
    console.error('[relay] send failed:', err.message);
    const hint = /sender/i.test(err.message)
      ? ' Verify the sender email in Brevo (Settings > Senders & Domains).'
      : /api.?key|unauthorized|forbidden|401|403/i.test(err.message)
        ? ' Check the BREVO_API_KEY env var in Render.'
        : '';
    res.writeHead(502, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: false, message: 'Could not send the code. Please try again later.' + hint }));
  }
});

server.listen(RELAY_PORT, '0.0.0.0', () => {
  console.log('TindaFlow OTP relay listening on http://0.0.0.0:' + RELAY_PORT);
  console.log('Set the app relay URL to: http://<this-pc-LAN-IP>:' + RELAY_PORT);
  console.log('Sending as:', FROM_NAME, '<' + FROM_EMAIL + '>', 'via Brevo API');
});