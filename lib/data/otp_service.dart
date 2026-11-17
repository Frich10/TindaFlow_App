import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'store.dart';

/// Result of an OTP/password-reset step.
class OtpResult {
  const OtpResult({required this.ok, required this.message});
  final bool ok;
  final String message;
}

/// Deliver password-reset OTP codes by email without Firebase.
/// Code/hash state is stored locally (SharedPreferences) and the code is sent
/// via the OTP relay HTTP endpoint.
class OtpService {
  OtpService._();
  static final OtpService instance = OtpService._();

  // Public HTTPS relay. Override at build time with: --dart-define=OTP_RELAY_URL=https://...
  static const String relayUrl = String.fromEnvironment(
    'OTP_RELAY_URL',
    defaultValue: 'https://tindaflow-otp-relay.onrender.com',
  );
  static const String relayToken = String.fromEnvironment(
    'RELAY_TOKEN',
    defaultValue: '5WGLrGh7cWIlMnYcy+e/akheXxewyKVQ',
  );

  static const int _otpLength = 6;
  static const int _otpTtlMs = 10 * 60 * 1000; // 10 minutes
  static const int _maxAttempts = 5;
  static const String _otpKey = 'local_otp';

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
      return 'Cannot reach the email service. Check your connection and try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  Future<Map<String, dynamic>> _loadAll() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_otpKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveAll(Map<String, dynamic> all) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_otpKey, jsonEncode(all));
  }

  /// Step 1: generate a code, store its hash locally, and email it.
  Future<OtpResult> sendOtp(String email) async {
    final normalized = email.trim().toLowerCase();
    final a = store.account;
    if (a == null || a.email != normalized) {
      return const OtpResult(ok: true, message: 'If that email is registered, a code has been sent.');
    }
    final key = _safeUserKey(normalized);
    try {
      final code = _generateCode();
      final now = DateTime.now().millisecondsSinceEpoch;
      final all = await _loadAll();
      all[key] = {
        'hash': _hash(code),
        'expiresAt': now + _otpTtlMs,
        'attempts': 0,
        'verified': false,
      };
      await _saveAll(all);

      final res = await http
          .post(
            Uri.parse('$relayUrl/sendOtp'),
            headers: {
              'Content-Type': 'application/json',
              if (relayToken.isNotEmpty) 'X-Relay-Token': relayToken,
            },
            body: jsonEncode({'email': normalized, 'code': code}),
          )
          .timeout(const Duration(seconds: 60));
      final body = _decode(res.body);
      if (res.statusCode == 200 && body?['ok'] == true) {
        return OtpResult(ok: true, message: body!['message'] as String? ?? 'Code sent.');
      }
      all.remove(key);
      await _saveAll(all);
      return OtpResult(ok: false, message: body?['message'] as String? ?? _friendlyError(res.body));
    } catch (e) {
      debugPrint('[OtpService] sendOtp error: $e');
      return OtpResult(ok: false, message: _friendlyError(e));
    }
  }

  /// Step 2a: verify [code] for [email].
  Future<OtpResult> verifyOtp({required String email, required String code}) async {
    final key = _safeUserKey(email);
    try {
      final all = await _loadAll();
      final rec = (all[key] as Map?)?.cast<String, dynamic>();
      if (rec == null) {
        return const OtpResult(ok: false, message: 'No code was requested for that email.');
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      final expiresAt = (rec['expiresAt'] as num?)?.toInt() ?? 0;
      final attempts = (rec['attempts'] as num?)?.toInt() ?? 0;
      final storedHash = rec['hash'] as String? ?? '';

      if (expiresAt < now) {
        all.remove(key);
        await _saveAll(all);
        return const OtpResult(ok: false, message: 'That code has expired. Request a new one.');
      }
      if (attempts >= _maxAttempts) {
        all.remove(key);
        await _saveAll(all);
        return const OtpResult(ok: false, message: 'Too many incorrect attempts. Request a new code.');
      }
      if (code.trim().isEmpty || _hash(code.trim()) != storedHash) {
        rec['attempts'] = attempts + 1;
        all[key] = rec;
        await _saveAll(all);
        return const OtpResult(ok: false, message: 'Incorrect code. Please check and try again.');
      }

      rec['verified'] = true;
      all[key] = rec;
      await _saveAll(all);
      return const OtpResult(ok: true, message: 'Code verified.');
    } catch (e) {
      debugPrint('[OtpService] verifyOtp error: $e');
      return OtpResult(ok: false, message: _friendlyError(e));
    }
  }

  /// Step 2b: reset the password for [email] to [newPassword].
  Future<OtpResult> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    final key = _safeUserKey(email);
    try {
      final all = await _loadAll();
      final rec = (all[key] as Map?)?.cast<String, dynamic>();
      if (rec == null || rec['verified'] != true) {
        return const OtpResult(ok: false, message: 'Verify the code first.');
      }
      final resetOk = await store.resetPasswordAsync(email, newPassword);
      all.remove(key);
      await _saveAll(all);
      if (!resetOk) {
        return const OtpResult(ok: false, message: 'No account found with that email.');
      }
      return const OtpResult(ok: true, message: 'Password updated. You can log in now.');
    } catch (e) {
      debugPrint('[OtpService] resetPassword error: $e');
      return OtpResult(ok: false, message: _friendlyError(e));
    }
  }

  Future<OtpResult> verifyOtpAndReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final v = await verifyOtp(email: email, code: code);
    if (!v.ok) return v;
    return resetPassword(email: email, newPassword: newPassword);
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