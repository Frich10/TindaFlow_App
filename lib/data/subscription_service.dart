import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'store.dart';

/// Optional build-time settings (--dart-define):
///   TINDAFLOW_GCASH_NAME, TINDAFLOW_GCASH_NUMBER
/// If the number is set, the receipt must also show the last 4 digits of it.
class PaymentConfig {
  static const accountName = String.fromEnvironment('TINDAFLOW_GCASH_NAME', defaultValue: 'TindaFlow');
  static const accountNumber = String.fromEnvironment('TINDAFLOW_GCASH_NUMBER');
  /// Web-only OCR key (ocr.space). 'helloworld' is a shared demo key; get a free key at ocr.space/ocrapi
  static const ocrKey = String.fromEnvironment('TINDAFLOW_OCR_KEY', defaultValue: 'helloworld');
  static const qrAsset = 'assets/images/gcash_qr.png'; // your QR that is already set to ₱39
  static const double amount = 39;
}

enum PayStatus { pending, failed, active, expired }

class PaymentRequest {
  PaymentRequest({
    required this.fullName,
    required this.phone,
    required this.email,
    required this.amount,
    required this.createdAt,
    this.status = PayStatus.pending,
    this.message,
    this.reference,
    this.startedAt,
    this.expiresAt,
    this.seen = false,
  });

  String fullName;
  String phone;
  String email;
  double amount;
  DateTime createdAt;
  PayStatus status;
  String? message;
  String? reference; // GCash reference number from the accepted receipt
  DateTime? startedAt;
  DateTime? expiresAt;
  bool seen; // success screen already shown

  Map<String, dynamic> toJson() => {
        'fullName': fullName, 'phone': phone, 'email': email, 'amount': amount,
        'createdAt': createdAt.toIso8601String(), 'status': status.name, 'message': message,
        'reference': reference, 'startedAt': startedAt?.toIso8601String(),
        'expiresAt': expiresAt?.toIso8601String(), 'seen': seen,
      };

  factory PaymentRequest.fromJson(Map<String, dynamic> j) => PaymentRequest(
        fullName: j['fullName'] as String,
        phone: j['phone'] as String,
        email: j['email'] as String,
        amount: (j['amount'] as num).toDouble(),
        createdAt: DateTime.parse(j['createdAt'] as String),
        status: PayStatus.values.firstWhere((s) => s.name == j['status'], orElse: () => PayStatus.pending),
        message: j['message'] as String?,
        reference: j['reference'] as String?,
        startedAt: j['startedAt'] == null ? null : DateTime.parse(j['startedAt'] as String),
        expiresAt: j['expiresAt'] == null ? null : DateTime.parse(j['expiresAt'] as String),
        seen: (j['seen'] as bool?) ?? false,
      );
}

DateTime addOneMonth(DateTime d) {
  final y = d.month == 12 ? d.year + 1 : d.year;
  final m = d.month == 12 ? 1 : d.month + 1;
  final last = DateTime(y, m + 1, 0).day;
  return DateTime(y, m, d.day > last ? last : d.day, d.hour, d.minute);
}

// ───────────────────────── receipt check ─────────────────────────

class ReceiptResult {
  const ReceiptResult(this.ok, this.message);
  final bool ok;
  final String message;
}

/// Digits only -> "0000 000 000000".
String formatRef(String input) {
  final d = input.replaceAll(RegExp(r'\D'), '');
  final t = d.length > 13 ? d.substring(0, 13) : d;
  final b = StringBuffer();
  for (var i = 0; i < t.length; i++) {
    if (i == 4 || i == 7) b.write(' ');
    b.write(t[i]);
  }
  return b.toString();
}

/// Reads the receipt photo on the phone (OCR) and compares it with what the user typed.
/// IMPORTANT: this proves the typed reference matches the picture. It cannot prove that
/// the money really reached your GCash account (an edited or old receipt could pass).
class ReceiptValidator {
  static String digitsOf(String s) => s.replaceAll(RegExp(r'\D'), '');

  /// OCR often reads 0 as O and 1 as l/I; fix those before looking for the reference.
  static String _fixDigits(String s) => s
      .replaceAll(RegExp('[Oo]'), '0')
      .replaceAll(RegExp('[lI|]'), '1')
      .replaceAll(RegExp('[Ss]'), '5')
      .replaceAll('B', '8')
      .replaceAll('Z', '2');

  static bool _looksLikeGcashReceipt(String text) {
    final t = text.toLowerCase();
    if (t.contains('gcash')) return true;
    const keys = ['ref no', 'reference no', 'express send', 'sent via', 'total amount', 'amount sent', 'send money', 'transfer'];
    return keys.where(t.contains).length >= 2;
  }

  /// Reads the text on the receipt picture.
  /// Android / iOS: Google ML Kit on the phone. Web browser: ocr.space online reader.
  static Future<String> _readText(String path, Uint8List bytes) async {
    if (!kIsWeb) {
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      try {
        return (await recognizer.processImage(InputImage.fromFilePath(path))).text;
      } finally {
        await recognizer.close();
      }
    }
    final isPng = bytes.length > 4 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47;
    final res = await http.post(
      Uri.parse('https://api.ocr.space/parse/image'),
      body: {
        'apikey': PaymentConfig.ocrKey,
        'base64Image': 'data:${isPng ? 'image/png' : 'image/jpeg'};base64,${base64Encode(bytes)}',
        'language': 'eng',
        'OCREngine': '2',
        'scale': 'true',
        'isOverlayRequired': 'false',
      },
    ).timeout(const Duration(seconds: 45));
    if (res.statusCode != 200) throw Exception('ocr ${res.statusCode}');
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    if (j['IsErroredOnProcessing'] == true) throw Exception('ocr error');
    final parsed = (j['ParsedResults'] as List?) ?? const [];
    return parsed.map((e) => ((e as Map)['ParsedText'] ?? '').toString()).join('\n');
  }

  static Future<ReceiptResult> validate({
    required String path,
    required Uint8List bytes,
    required String reference,
    required Set<String> usedRefs,
  }) async {
    ReceiptResult fail(String m) => ReceiptResult(false, m);
    final ref = digitsOf(reference);
    if (ref.length != 13) return fail('The reference number must be 13 digits, like 0000 000 000000.');
    if (usedRefs.contains(ref)) return fail('This reference number was already used for a payment.');

    final text = await _readText(path, bytes);
    // If the text cannot be read, the picture is blurry, too dark or not a receipt.
    if (text.trim().length < 25) {
      return fail('This is not a receipt, or it is too blurry to read. Please upload your GCash receipt or take a clear picture of it.');
    }
    if (!_looksLikeGcashReceipt(text)) {
      return fail('This is not a GCash receipt. Please upload your GCash payment receipt.');
    }
    final fixed = _fixDigits(text);
    if (!digitsOf(fixed).contains(ref)) {
      // Is there a reference number on the receipt at all (0000 000 000000)?
      final found = RegExp(r'\d{4}\s*\d{3}\s*\d{6}').hasMatch(fixed);
      if (!found) {
        return fail('We could not read the reference number on the receipt. Please upload a clearer picture where the reference number is visible.');
      }
      return fail('The reference number is wrong. It does not match the reference number on your receipt.');
    }
    if (!RegExp(r'39[.,]00').hasMatch(text)) return fail('We could not find the ₱39.00 amount on the receipt.');
    final acct = digitsOf(PaymentConfig.accountNumber);
    if (acct.length >= 4 && !digitsOf(text).contains(acct.substring(acct.length - 4))) {
      return fail('This receipt does not show payment to our GCash account.');
    }
    return const ReceiptResult(true, 'ok');
  }
}

// ───────────────────────── service ─────────────────────────

class SubscriptionService extends ChangeNotifier {
  PaymentRequest? request;
  bool loaded = false;
  bool verifying = false;
  final Set<String> _usedRefs = {};

  static const _key = 'sub_request';
  static const _usedKey = 'sub_used_refs';

  bool get isPending => request?.status == PayStatus.pending;

  Future<void> ensureLoaded() async {
    if (!loaded) {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw != null) {
        try {
          request = PaymentRequest.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        } catch (_) {
          request = null;
        }
      }
      _usedRefs.addAll(p.getStringList(_usedKey) ?? const []);
      loaded = true;
    }
    await checkExpiry();
    notifyListeners();
  }

  Future<void> checkExpiry() async {
    final r = request;
    if (r != null && r.status == PayStatus.active && r.expiresAt != null && !DateTime.now().isBefore(r.expiresAt!)) {
      r.status = PayStatus.expired;
      store.setPlan('Free');
      await _save();
      notifyListeners();
    }
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    if (request == null) {
      await p.remove(_key);
    } else {
      await p.setString(_key, jsonEncode(request!.toJson()));
    }
    await p.setStringList(_usedKey, _usedRefs.toList());
  }

  Future<void> startPayment({required String fullName, required String phone, required String email}) async {
    request = PaymentRequest(
      fullName: fullName.trim(),
      phone: phone.trim(),
      email: email.trim().toLowerCase(),
      amount: PaymentConfig.amount,
      createdAt: DateTime.now(),
    );
    await _save();
    notifyListeners();
  }

  /// Checks the receipt photo against the typed reference. Premium activates only if it passes.
  Future<void> verifyReceipt({required String path, required Uint8List bytes, required String reference}) async {
    final r = request;
    if (r == null || r.status != PayStatus.pending || verifying) return;
    verifying = true;
    notifyListeners();
    ReceiptResult res;
    try {
      res = await ReceiptValidator.validate(path: path, bytes: bytes, reference: reference, usedRefs: _usedRefs);
    } catch (e) {
      res = ReceiptResult(
          false,
          kIsWeb
              ? 'We could not read the receipt. Check your internet connection and try again with a clear picture.'
              : 'We could not read the receipt. Please try again with a clear picture.');
    }
    verifying = false;
    if (res.ok) {
      final now = DateTime.now();
      final ref = ReceiptValidator.digitsOf(reference);
      _usedRefs.add(ref);
      r.status = PayStatus.active;
      r.reference = ref;
      r.startedAt = now;
      r.expiresAt = addOneMonth(now);
      r.message = null;
      r.seen = false;
      store.setPlan('Premium'); // persisted by the store
    } else {
      r.status = PayStatus.failed;
      r.message = res.message;
    }
    await _save();
    notifyListeners();
  }

  /// Back to the upload screen after a failed check.
  Future<void> retry() async {
    final r = request;
    if (r == null || r.status == PayStatus.active) return;
    r.status = PayStatus.pending;
    r.message = null;
    await _save();
    notifyListeners();
  }

  Future<void> markSeen() async {
    request?.seen = true;
    await _save();
    notifyListeners();
  }

  Future<void> reset() async {
    if (request?.status == PayStatus.active) return;
    request = null;
    await _save();
    notifyListeners();
  }
}

final SubscriptionService subscription = SubscriptionService();