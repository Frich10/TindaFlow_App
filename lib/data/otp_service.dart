import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'firebase_sync.dart';
import 'store.dart';

/// Result of an OTP/password-reset step.
class OtpResult {
  const OtpResult({required this.ok, required this.message});
  final bool ok;
  final String message;
}

/// Deliver password-reset OTP codes by email without any cloud server.
///
/// Flow:
///  1. App generates a 6-digit code, stores only its SHA-256 hash in Firebase
///     (so the code can never be read back from the database), and asks the
///     local SMTP relay (running on the owner's PC) to email the code.
///  2. The user types the code + new password; the app re-hashes and compares.
///  3. On match the new password is written to the account (local + Firebase).
class OtpService {
  OtpService._();
  static final OtpService instance = OtpService._();

  // ─── OTP RELAY ──────────────────────────────────────────────────────────
  // Where the local SMTP relay runs. Override at build time with:
  //   flutter run --dart-define=OTP_RELAY_URL=http://<pc-LAN-IP>:5000
  // Update the default below if your PC's Wi-Fi IP changes (DHCP).
  static const String relayUrl = String.fromEnvironment(
    'OTP_RELAY_URL',
    defaultValue: 'http://10.247.229.49:5000',
  );

  static const int _otpLength = 6;
  static const int _otpTtlMs = 10 * 60 * 1000; // 10 minutes
  static const int _maxAttempts = 5;

  FirebaseDatabase? get _db {
    if (!Firebase.apps.any((a) => a.name == '[DEFAULT]')) return null;
    return firebaseSync.database;
  }

  /// Mirrors FirebaseSyncService.safeUserKey so the key matches the account.
  String _safeUserKey(String email) =>
      email.trim().toLowerCase().replaceAll(RegExp(r'[.#$\[\]/]'), '_');

  String _hash(String value) => sha256.convert(utf8.encode(value)).toString();

  String _generateCode() {
    final rng = Random.secure();
    final max = pow(10, _otpLength).toInt();
    return rng.nextInt(max).toString().padLeft(_otpLength, '0');
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('SocketException') ||
        text.contains('ClientException') ||
        text.contains('Failed host lookup') ||
        text.contains('Connection refused')) {
      return 'Cannot reach the email service on your PC. Make sure it is running and you are on the same Wi-Fi.';
    }
    return 'Something went wrong. Please try again.';
  }

  /// Step 1: generate a code, store its hash in Firebase, and email it.
  /// Returns ok=false only when the email could not be sent or no account
  /// exists; the response stays generic so accounts cannot be enumerated.
  Future<OtpResult> sendOtp(String email) async {
    final db = _db;
    if (db == null) {
      return const OtpResult(ok: false, message: 'Email service is not available right now.');
    }
    final key = _safeUserKey(email);
    debugPrint('[OtpService] sendOtp email=$email key=$key');
    try {
      debugPrint('[OtpService] reading users/$key/account ...');
      final accountSnap = await db.ref('users/$key/account').get();
      debugPrint('[OtpService] account exists=${accountSnap.exists}');
      if (!accountSnap.exists || accountSnap.value == null) {
        return const OtpResult(ok: true, message: 'If that email is registered, a code has been sent.');
      }

      final code = _generateCode();
      final now = DateTime.now().millisecondsSinceEpoch;
      debugPrint('[OtpService] writing otp/$key ...');
      await db.ref('otp/$key').set({
        'hash': _hash(code),
        'expiresAt': now + _otpTtlMs,
        'attempts': 0,
        'lastSentAt': now,
      });
      debugPrint('[OtpService] otp write ok');

      final res = await http.post(
        Uri.parse('$relayUrl/sendOtp'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim(), 'code': code}),
      );
      final body = _decode(res.body);
      if (res.statusCode == 200 && body?['ok'] == true) {
        return OtpResult(ok: true, message: body!['message'] as String? ?? 'Code sent.');
      }
      // Email failed: remove the stored code so it cannot be verified.
      await db.ref('otp/$key').remove();
      return OtpResult(ok: false, message: body?['message'] as String? ?? _friendlyError(res.body));
    } catch (e) {
      debugPrint('[OtpService] sendOtp error: $e');
      if (e.toString().contains('permission-denied') || e.toString().contains('PERMISSION_DENIED')) {
        return const OtpResult(ok: false, message: 'Database permission denied. Deploy the latest database rules (firebase deploy --only database).');
      }
      return OtpResult(ok: false, message: _friendlyError(e));
    }
  }

  /// Step 2: verify [code] and, on success, reset the password to
  /// [newPassword] (local store + Firebase).
  Future<OtpResult> verifyOtpAndReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final db = _db;
    if (db == null) {
      return const OtpResult(ok: false, message: 'Email service is not available right now.');
    }
    final key = _safeUserKey(email);
    try {
      final snap = await db.ref('otp/$key').get();
      if (!snap.exists || snap.value == null) {
        return const OtpResult(ok: false, message: 'No code was requested for that email.');
      }
      final rec = Map<String, dynamic>.from(snap.value as Map);
      final now = DateTime.now().millisecondsSinceEpoch;
      final expiresAt = (rec['expiresAt'] as num?)?.toInt() ?? 0;
      final attempts = (rec['attempts'] as num?)?.toInt() ?? 0;
      final storedHash = rec['hash'] as String? ?? '';

      if (expiresAt < now) {
        await db.ref('otp/$key').remove();
        return const OtpResult(ok: false, message: 'That code has expired. Request a new one.');
      }
      if (attempts >= _maxAttempts) {
        await db.ref('otp/$key').remove();
        return const OtpResult(ok: false, message: 'Too many incorrect attempts. Request a new code.');
      }
      if (code.trim().isEmpty || _hash(code.trim()) != storedHash) {
        await db.ref('otp/$key/attempts').set(attempts + 1);
        return const OtpResult(ok: false, message: 'Incorrect code. Please check and try again.');
      }

      final resetOk = await store.resetPasswordAsync(email, newPassword);
      await db.ref('otp/$key').remove();
      if (!resetOk) {
        return const OtpResult(ok: false, message: 'No account found with that email.');
      }
      return const OtpResult(ok: true, message: 'Password updated. You can log in now.');
    } catch (e) {
      debugPrint('[OtpService] verifyOtpAndReset error: $e');
      return OtpResult(ok: false, message: _friendlyError(e));
    }
  }

  Map<String, dynamic>? _decode(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}

final OtpService otpService = OtpService.instance;