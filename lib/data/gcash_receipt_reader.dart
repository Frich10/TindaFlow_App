import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Result of reading a GCash receipt photo.
class GcashScanResult {
  const GcashScanResult({
    required this.text,
    this.amount,
    this.fee,
    this.date,
    this.hour,
    this.minute,
    this.reference,
    this.name,
    this.phone,
    this.type,
  });

  final String text;
  final double? amount;
  final double? fee;
  final DateTime? date;
  final int? hour; // 0-23
  final int? minute; // 0-59
  final String? reference;
  final String? name;
  final String? phone;
  final String? type; // 'Cash In' | 'Cash Out'

  bool get isEmpty => text.trim().isEmpty;
}

/// Reads a GCash receipt (on-device ML Kit, or ocr.space on web) and extracts
/// the fields we can reliably find. The caller should let the user review and
/// edit everything before saving — OCR is best-effort, not exact.
class GcashReceiptReader {
  /// Shared ocr.space key (same free/demo key used by the subscription flow).
  static const _webOcrKey = String.fromEnvironment('TINDAFLOW_OCR_KEY', defaultValue: 'helloworld');

  static String _digitsOf(String s) => s.replaceAll(RegExp(r'\D'), '');

  static const _months = {
    'jan': 1, 'january': 1, 'feb': 2, 'february': 2, 'mar': 3, 'march': 3,
    'apr': 4, 'april': 4, 'may': 5, 'jun': 6, 'june': 6, 'jul': 7, 'july': 7,
    'aug': 8, 'august': 8, 'sep': 9, 'sept': 9, 'september': 9, 'oct': 10,
    'october': 10, 'nov': 11, 'november': 11, 'dec': 12, 'december': 12,
  };

  /// Reads the raw text from the image.
  ///
  /// Mobile: preprocess the photo (upscale small text, boost contrast, sharpen)
  /// and, for long receipts, split it into overlapping horizontal tiles so ML Kit
  /// can read every line. If ML Kit still returns too little text, fall back to
  /// the ocr.space cloud engine (the same path web uses, which is more tolerant).
  ///
  /// Web: always uses ocr.space (ML Kit is a native mobile-only library).
  static Future<String> readText(String path, Uint8List bytes) async {
    if (kIsWeb) return _readTextViaCloud(bytes);

    // ── Mobile: on-device ML Kit with preprocessing + tiling ──
    String? best;
    try {
      best = await _readTextViaMlKit(path, bytes);
    } catch (e) {
      debugPrint('[GcashReceiptReader] ML Kit failed: $e');
    }

    // Accept the ML Kit result only if it actually looks like a receipt.
    if (best != null && _looksLikeReceipt(best)) return best;

    // ── Fallback: cloud OCR (same engine that works on web) ──
    try {
      final cloud = await _readTextViaCloud(bytes);
      if (_looksLikeReceipt(cloud)) return cloud;
      // Keep whichever produced more text.
      if (best != null && best.trim().length > cloud.trim().length) return best;
      return cloud;
    } catch (e) {
      debugPrint('[GcashReceiptReader] cloud OCR failed: $e');
      if (best != null) return best;
      rethrow;
    }
  }

  /// True when [text] contains enough receipt-like signal to trust it.
  static bool _looksLikeReceipt(String text) {
    final t = text.toLowerCase();
    if (t.trim().length < 20) return false;
    const hints = [
      'gcash', 'ref no', 'reference', 'amount', 'total', 'sent', 'received',
      'cash in', 'cash out', 'fee', 'balance', 'to ', 'from',
    ];
    var hits = 0;
    for (final h in hints) {
      if (t.contains(h)) hits++;
    }
    return hits >= 2;
  }

  /// Preprocesses [bytes] and runs ML Kit. Long receipts are split into
  /// overlapping tiles so every line is read at a usable resolution.
  static Future<String> _readTextViaMlKit(String path, Uint8List bytes) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      // Fall back to the original file if the image package cannot decode it.
      return _runMlKitOnFile(path);
    }

    // Work on a copy so we never mutate the caller's image.
    img.Image base = img.Image.from(decoded);

    // Upscale small images so short receipt text is legible to ML Kit.
    final shortest = base.width < base.height ? base.width : base.height;
    if (shortest > 0 && shortest < 1000) {
      final factor = (1000 / shortest).ceil().clamp(1, 3);
      base = img.copyResize(
        base,
        width: (base.width * factor).clamp(1, 4000),
        height: (base.height * factor).clamp(1, 4000),
        interpolation: img.Interpolation.cubic,
      );
    }

    // Boost contrast + grayscale: receipts are dark text on a light slip, and
    // grayscale removes colour noise that confuses the recognizer.
    base = img.grayscale(base);
    base = img.adjustColor(base, contrast: 1.35);

    // Long receipts (tall images) are tiled with overlap so no line is lost.
    const tileHeight = 1400;
    const overlap = 120;
    final out = StringBuffer();
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      if (base.height <= tileHeight) {
        final file = await _writeTempImage(base);
        try {
          out.write((await recognizer.processImage(InputImage.fromFilePath(file.path))).text);
        } finally {
          await _deleteTemp(file);
        }
      } else {
        for (var y = 0; y < base.height; y += tileHeight - overlap) {
          final h = (y + tileHeight > base.height) ? base.height - y : tileHeight;
          if (h <= 0) break;
          final tile = img.copyCrop(base, x: 0, y: y, width: base.width, height: h);
          final file = await _writeTempImage(tile);
          try {
            final part = (await recognizer.processImage(InputImage.fromFilePath(file.path))).text;
            if (part.trim().isNotEmpty) {
              if (out.isNotEmpty) out.write('\n');
              out.write(part);
            }
          } finally {
            await _deleteTemp(file);
          }
          if (y + tileHeight >= base.height) break;
        }
      }
    } finally {
      await recognizer.close();
    }
    return out.toString();
  }

  /// Runs ML Kit directly on the original file (no preprocessing).
  static Future<String> _runMlKitOnFile(String path) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      return (await recognizer.processImage(InputImage.fromFilePath(path))).text;
    } finally {
      await recognizer.close();
    }
  }

  /// Writes [image] to a temp JPEG and returns the file.
  static Future<File> _writeTempImage(img.Image image) async {
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/gcash_tile_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(img.encodeJpg(image, quality: 92));
    return file;
  }

  static Future<void> _deleteTemp(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// Sends the image to ocr.space (the cloud engine used on web).
  static Future<String> _readTextViaCloud(Uint8List bytes) async {
    final isPng = bytes.length > 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47;
    final res = await http.post(
      Uri.parse('https://api.ocr.space/parse/image'),
      body: {
        'apikey': _webOcrKey,
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

  /// Scans [path]/[bytes] and extracts the GCash fields we can detect.
  static Future<GcashScanResult> scan({
    required String path,
    required Uint8List bytes,
  }) async {
    final raw = await readText(path, bytes);
    return parse(raw);
  }

  /// True when [text] is clearly a GCash (or similar e-wallet) transaction
  /// receipt rather than a random photo, screenshot or handwritten note.
  ///
  /// A receipt must have BOTH a transaction signal (amount / "sent" / "received"
  /// / a reference number) AND a receipt signal ("gcash", "reference", "total",
  /// "balance", a peso sign, ...). Requiring both keeps ordinary photos out
  /// while accepting real receipts even when OCR is noisy.
  static bool isGcashReceipt(String text) {
    final t = text.toLowerCase();
    if (t.trim().length < 20) return false;

    // ── Transaction signal: evidence that money actually moved. ──
    var hasAmount = false;
    if (RegExp(r'[₱$]|php|peso').hasMatch(t)) hasAmount = true;
    if (RegExp(r'\b\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?\b').hasMatch(t) &&
        RegExp(r'amount|total|sent|received|paid|fee|balance|cash\s*in|cash\s*out')
            .hasMatch(t)) {
      hasAmount = true;
    }
    // A 13-digit GCash reference number is a strong transaction signal.
    final hasRef = RegExp(r'\b\d{4}\s*\d{3}\s*\d{6}\b').hasMatch(t) ||
        RegExp(r'\b\d{13}\b').hasMatch(t);
    if (!hasAmount && !hasRef) return false;

    // ── Receipt signal: evidence this is an e-wallet receipt. ──
    const receiptHints = [
      'gcash', 'g-cash', 'gcash receipt', 'reference', 'ref no', 'ref no.',
      'total amount', 'amount sent', 'amount received', 'you sent',
      'you received', 'sent via', 'express send', 'send money', 'cash in',
      'cash out', 'transaction details', 'balance', 'fee', 'charge',
      'payment', 'transfer', 'received from', 'sent to',
    ];
    var hits = 0;
    for (final h in receiptHints) {
      if (t.contains(h)) hits++;
    }
    return hits >= 2;
  }

  /// Pure parser over the OCR [text] (exposed for testing).
  static GcashScanResult parse(String text) {
    final lower = text.toLowerCase();

    // ── Reference: 13-digit GCash ref, possibly written as 0000 000 000000.
    // Apply OCR digit fixes only here (not to the whole text, which would
    // corrupt words like "hello" -> "he110").
    String? reference;
    final refMatch = RegExp(r'\d{4}\s*\d{3}\s*\d{6}').firstMatch(text) ??
        RegExp(r'\d{13}').firstMatch(_digitsOf(text));
    if (refMatch != null) {
      reference = _digitsOf(refMatch.group(0)!);
    }

    // ── Fee / charge: look for a "fee" / "charge" labelled number.
    double? fee;
    final feeMatch = RegExp(r'(?:fee|charge)[^\d]{0,12}([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)',
        caseSensitive: false)
        .firstMatch(text);
    if (feeMatch != null) {
      fee = double.tryParse((feeMatch.group(1) ?? '').replaceAll(',', ''));
    }

    // ── Amount: remove the reference number so its digits are not mistaken
    //    for an amount, then collect money-looking values.
    var scanText = text;
    if (refMatch != null) {
      scanText = scanText.replaceAll(refMatch.group(0)!, ' ');
    }
    scanText = scanText.replaceAll(RegExp(r'\d{4}\s*\d{3}\s*\d{6}'), ' ');
    // Drop date-like tokens so day/month/year digits are not treated as amounts.
    scanText = scanText.replaceAll(RegExp(r'\b\d{1,4}[-/.]\d{1,2}[-/.]\d{1,4}\b'), ' ');

    // Values explicitly labelled as the sent/received amount win over other
    // money on the slip (e.g. "Balance", "Total Balance", "Available").
    double? labelledAmount;
    final amountLabelRe = RegExp(
      r'(?:amount(?:\s+(?:sent|transferred|received))?|total(?:\s+amount)?|you\s+(?:sent|received)|sent|received|paid|purchase)'
      r'[^\d₱]{0,20}(?:₱|php|peso)?\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    );
    final labelledCandidates = <double>[];
    for (final m in amountLabelRe.allMatches(scanText)) {
      // Skip "balance" style labels captured inside the window.
      final v = double.tryParse((m.group(1) ?? '').replaceAll(',', ''));
      if (v != null && v > 0) labelledCandidates.add(v);
    }
    if (labelledCandidates.isNotEmpty) {
      labelledCandidates.sort();
      labelledAmount = labelledCandidates.last;
    }

    double? amount;
    final candidates = <double>[];
    final decimalOrPeso = RegExp(
            r'(?:₱|php|peso)\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)|([0-9]{1,3}(?:,[0-9]{3})*\.[0-9]{1,2}|[0-9]+\.[0-9]{1,2})',
            caseSensitive: false)
        .allMatches(scanText);
    for (final m in decimalOrPeso) {
      final raw = (m.group(1) ?? m.group(2))?.replaceAll(',', '');
      final v = double.tryParse(raw ?? '');
      if (v != null && v > 0) candidates.add(v);
    }
    if (candidates.isNotEmpty) {
      candidates.sort();
      amount = candidates.last;
    } else {
      // Fallback: any plain integer amount (no peso/decimal) — still exclude
      // values that are clearly dates/refs by requiring reasonable length.
      final plain = RegExp(r'(?<![\d.,])([0-9]{1,7})(?![\d.,])')
          .allMatches(scanText)
          .map((m) => double.tryParse(m.group(1)!))
          .whereType<double>()
          .where((v) => v > 0)
          .toList();
      if (plain.isNotEmpty) {
        plain.sort();
        amount = plain.last;
      }
    }
    // A labelled amount ("You sent", "Total Amount") is the real transaction
    // value; prefer it over an unlabelled maximum such as the balance.
    if (labelledAmount != null) amount = labelledAmount;

    // ── Date.
    DateTime? date;
    final dateCandidates = _extractDates(text);
    if (dateCandidates.isNotEmpty) {
      dateCandidates.sort();
      date = dateCandidates.last;
    }

    // ── Type: cash in vs cash out (a received/"you received"/"sent" hint).
    String? type;
    if (lower.contains('cash in') ||
        lower.contains('received') ||
        lower.contains('you got') ||
        lower.contains('credited')) {
      type = 'Cash In';
    } else if (lower.contains('cash out') ||
        lower.contains('sent') ||
        lower.contains('you sent') ||
        lower.contains('debited') ||
        lower.contains('paid')) {
      type = 'Cash Out';
    }

    // ── Time: e.g. "10:30 AM", "10:30:45", "22:30", "10:30 PM".
    int? hour;
    int? minute;
    final timeMatch = RegExp(r'\b([01]?\d|2[0-3]):([0-5]\d)(?::[0-5]\d)?\s*([ap]\.?m\.?)?', caseSensitive: false)
        .firstMatch(text);
    if (timeMatch != null) {
      var h = int.parse(timeMatch.group(1)!);
      final m = int.parse(timeMatch.group(2)!);
      final ampm = (timeMatch.group(3) ?? '').toLowerCase().replaceAll('.', '');
      if (ampm == 'pm' && h < 12) h += 12;
      if (ampm == 'am' && h == 12) h = 0;
      if (h >= 0 && h <= 23 && m >= 0 && m <= 59) {
        hour = h;
        minute = m;
      }
    }

    // ── Name: GCash receipts show a masked name, e.g. "FR••H AN•••W E."
    //    (bullets hide middle letters). Preserve the bullets so the user sees
    //    exactly what the receipt shows.
    String? name = _extractMaskedName(text) ?? _extractName(text);

    // ── Phone: +63 / 63 / 09xx / 9xx, normalized to 09XXXXXXXXX (0 prefix).
    // Use scanText so the 13-digit reference / date tokens are not misread.
    String? phone = _extractPhone(scanText);

    return GcashScanResult(
      text: text,
      amount: amount,
      fee: fee,
      date: date,
      hour: hour,
      minute: minute,
      reference: reference,
      type: type,
      name: name,
      phone: phone,
    );
  }

  /// Collects every date in [text] as (year, month, day).
  static List<DateTime> _extractDates(String text) {
    final out = <DateTime>[];
    void add(int? y, int? m, int? d) {
      if (y == null || m == null || d == null) return;
      if (m < 1 || m > 12 || d < 1 || d > 31) return;
      try {
        final dt = DateTime(y, m, d);
        if (dt.month == m && dt.day == d) out.add(dt);
      } catch (_) {}
    }

    final lower = text.toLowerCase();

    final monthFirst = RegExp(r'\b([a-z]{3,9})\s+(\d{1,2})(?:st|nd|rd|th)?,?\s+(\d{4})');
    for (final m in monthFirst.allMatches(lower)) {
      final mo = _months[m.group(1)];
      if (mo != null) add(int.parse(m.group(3)!), mo, int.parse(m.group(2)!));
    }

    final dayFirst = RegExp(r'\b(\d{1,2})(?:st|nd|rd|th)?\s+([a-z]{3,9}),?\s+(\d{4})');
    for (final m in dayFirst.allMatches(lower)) {
      final mo = _months[m.group(2)];
      if (mo != null) add(int.parse(m.group(3)!), mo, int.parse(m.group(1)!));
    }

    final ymd = RegExp(r'\b(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})\b');
    for (final m in ymd.allMatches(lower)) {
      add(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
    }

    final slash = RegExp(r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})\b');
    for (final m in slash.allMatches(lower)) {
      var y = int.parse(m.group(3)!);
      if (y < 100) y += 2000;
      final a = int.parse(m.group(1)!);
      final b = int.parse(m.group(2)!);
      add(y, a, b);
      add(y, b, a);
    }
    return out;
  }

  // ── Name extraction ─────────────────────────────────────────────────────
  // Words that are UI labels, not names.
  static const _nameStopwords = {
    'to', 'from', 'sent', 'received', 'you', 'your', 'gcash', 'cash',
    'payment', 'paid', 'pay', 'transfer', 'reference', 'ref', 'amount',
    'total', 'fee', 'charge', 'balance', 'date', 'time', 'name', 'phone',
    'number', 'mobile', 'account', 'via', 'using', 'the', 'and', 'for',
    'new', 'available', 'success', 'successful', 'completed', 'confirmed',
    'thank', 'thanks', 'receipt', 'transaction', 'details', 'summary',
  };

  /// Returns a cleaned name candidate from [raw], or null if it does not look
  /// like a person/merchant name.
  static String? _cleanName(String raw) {
    var s = raw
        .replaceAll(RegExp(r'[•·\u2022]'), ' ') // bullets -> space
        .replaceAll(RegExp(r'[|_]+'), ' ') // separators -> space
        .trim();
    // Drop leading label words / punctuation.
    s = s.replaceAll(RegExp(r'^[\s:.\-–—]+'), '').trim();
    // Keep only letters, spaces, apostrophes, dots and hyphens.
    s = s.replaceAll(RegExp(r"[^A-Za-z\s'.-]"), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Strip a trailing single-letter token or stray punctuation.
    s = s.replaceAll(RegExp(r"[\s.]+$"), '').trim();
    if (s.isEmpty) return null;

    final words = s.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty || words.length > 5) return null;
    // Each word should be at least 2 chars (allow "Li", "Ma", "Dela", "Cruz").
    if (words.any((w) => w.replaceAll(RegExp(r"[^A-Za-z]"), '').length < 2)) {
      return null;
    }
    // Reject if any word is a UI label/stopword — real names never contain
    // words like "amount", "sent", "total", "cash", "payment". This prevents
    // "Total Amount Sent" (or OCR fragments of it) from being read as a name.
    if (words.any((w) => _nameStopwords.contains(w.toLowerCase()))) return null;

    // Title-case the result for consistent display.
    return words.map((w) {
      final lower = w.toLowerCase();
      return lower[0].toUpperCase() + lower.substring(1);
    }).join(' ');
  }

  /// Finds the masked GCash name (e.g. "FR••H AN•••W E.") and returns it
  /// with the bullet masks preserved. GCash shows the first and last letters of
  /// each word and hides the middle with "•".
  static String? _extractMaskedName(String text) {
    final lines = text.split('\n');

    bool looksMasked(String s) {
      final t = s.trim();
      if (t.isEmpty) return false;
      // Only letters, bullets, spaces, periods, apostrophes, hyphens and digits
      // (OCR often reads a bullet as "e", "o", "a" or "0").
      if (!RegExp(r"^[A-Za-z0-9•·.'\- ]+$").hasMatch(t)) return false;
      final tokens = t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      if (tokens.length < 2 || tokens.length > 5) return false;
      // A standalone leading bullet ("• JUAN DELA CRUZ") is not a mask — that is
      // a plain name and is handled by the unmasked name extractor.
      if (tokens.length >= 2 && (tokens[0] == '•' || tokens[0] == '·')) {
        return false;
      }
      // Require at least one token that is clearly a masked word.
      return tokens.any((w) => _isMaskedWord(w));
    }

    // 1) Labelled masked name: "To: FR••H AN•••W E." / "Name: FR••H".
    //    \b ensures "to" does not match inside words like "Total".
    final labelRe = RegExp(
      r'\b(?:to|from|recipient|sender|name)\b\s*[:\-–]?\s*(.+)',
      caseSensitive: false,
    );
    for (final line in lines) {
      final m = labelRe.firstMatch(line.trim());
      if (m == null) continue;
      if (looksMasked(m.group(1)!)) return _normalizeMaskedName(m.group(1)!);
    }

    // 2) Any line that is entirely a masked name.
    for (final line in lines) {
      if (looksMasked(line)) return _normalizeMaskedName(line);
    }

    return null;
  }

  /// Cleans up OCR artifacts in a masked name.
  ///
  /// GCash masks the middle letters of each word with bullets, e.g.
  /// "FR••H AN•••W E.". OCR on phones frequently misreads those bullets as the
  /// letters "e", "o", "a" or "0", drops the space before a trailing middle
  /// initial, and loses the ALL-CAPS styling. This restores all of that:
  ///
  ///  - "Fre•H ANeoWE."  -> "FR••H AN•••W E."
  ///  - "FRoH ANe•W E."  -> "FR•H AN••W E."
  static String _normalizeMaskedName(String raw) {
    // 1) Work token by token so a stray letter cannot merge words together.
    var tokens = raw.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    // 2) Repair misread bullets BEFORE upper-casing. GCash keeps the FIRST and
    //    LAST letter of every word and masks only the middle, so an artifact
    //    letter in an interior position is a misread "•". The artifact test is
    //    case-sensitive (lower-case e/o/a/0), so it must run on the raw OCR text.
    tokens = tokens.map((token) {
      if (!_isMaskedToken(token) && !_isMaskedWord(token)) return token;
      final chars = token.split('');
      for (var i = 1; i < chars.length - 1; i++) {
        if (!_isMaskArtifact(chars[i])) continue;
        final prevOk = RegExp(r'[A-Za-z•·]').hasMatch(chars[i - 1]);
        final nextOk = RegExp(r'[A-Za-z•·]').hasMatch(chars[i + 1]);
        if (prevOk && nextOk) chars[i] = '•';
      }
      return chars.join();
    }).toList();

    // 3) GCash renders masked names in ALL CAPS.
    tokens = tokens.map((t) => t.toUpperCase()).toList();

    // 4) Restore a space dropped before a trailing single-letter initial + dot
    //    ("AN••WE." -> "AN••W" + "E."). Runs after bullet repair so the token is
    //    now recognisably a masked word.
    final expanded = <String>[];
    for (final token in tokens) {
      final m = RegExp(r'^(.*[A-Za-z•·])([A-Za-z]\.)$').firstMatch(token);
      if (m != null && _isMaskedWord(m.group(1)!)) {
        expanded.add(m.group(1)!);
        expanded.add(m.group(2)!);
      } else {
        expanded.add(token);
      }
    }
    tokens = expanded;

    // 5) Re-join with single spaces.
    return tokens.join(' ');
  }

  /// True when [token] contains a real bullet AND at least one letter — i.e. it
  /// is a masked *name* ("FR••H"), not a masked phone fragment ("••••").
  static bool _isMaskedToken(String token) {
    if (!token.contains('•') && !token.contains('·')) return false;
    return RegExp(r'[A-Za-z]').hasMatch(token);
  }

  /// True when [token] is a masked word whose bullets were all misread as
  /// letters/digits, e.g. "FRoH" or "Fre•H".
  ///
  /// GCash masks are round dots that OCR reads as a small "e"/"o"/"a"/"0" in an
  /// interior position. A token qualifies when it is uppercase-dominant (GCash
  /// masks are ALL CAPS) and has such an interior artifact. Requiring an
  /// uppercase-dominant token keeps ordinary sentences ("Transaction Details",
  /// "Thank you for using GCash") from being mistaken for a name.
  static bool _isMaskedWord(String token) {
    if (_isMaskedToken(token)) return true;
    final chars = token.split('');
    if (chars.length < 3) return false;

    var letters = 0;
    var digits = 0;
    var upper = 0;
    var artifacts = 0;
    for (var i = 0; i < chars.length; i++) {
      final c = chars[i];
      if (RegExp(r'[A-Za-z]').hasMatch(c)) letters++;
      if (RegExp(r'[0-9]').hasMatch(c)) digits++;
      if (RegExp(r'[A-Z]').hasMatch(c)) upper++;
      // An artifact must sit between two letters, never next to a digit, so
      // reference numbers ("REF NO. 1234 567 890123") are not misread.
      if (i > 0 && i < chars.length - 1 &&
          _isMaskArtifact(c) &&
          RegExp(r'[A-Za-z•·]').hasMatch(chars[i - 1]) &&
          RegExp(r'[A-Za-z•·]').hasMatch(chars[i + 1])) {
        artifacts++;
      }
    }
    if (artifacts < 1) return false;
    // Must be a word, not a number, and uppercase-dominant (GCash masks are ALL
    // CAPS), allowing for the artifact letters OCR lower-cased.
    if (digits > 0) return false;
    return upper >= (letters / 2);
  }

  /// True when [c] is a letter/digit OCR commonly misreads a bullet "•" as.
  ///
  /// Only lower-case artifacts count: GCash masks are round dots, which OCR
  /// reads as small "e"/"o"/"a"/"0", never as capital letters. Excluding upper
  /// case keeps real ALL-CAPS names ("MARIA SANTOS") from being turned into
  /// bullets.
  static bool _isMaskArtifact(String c) {
    return c == 'e' || c == 'o' || c == 'a' || c == '0';
  }

  /// Finds a name in [text] using labelled lines, bullet lines and, as a last
  /// resort, an ALL-CAPS name-looking line.
  static String? _extractName(String text) {
    final lines = text.split('\n');

    // 1) Labelled: "To: Juan", "From - Juan", "Name: JUAN DELA CRUZ".
    //    \b ensures "to" does not match inside words like "Total".
    final labelRe = RegExp(
      r'\b(?:to|from|recipient|sender|name)\b\s*[:\-–]?\s*(.+)',
      caseSensitive: false,
    );
    for (final line in lines) {
      final m = labelRe.firstMatch(line.trim());
      if (m == null) continue;
      final cleaned = _cleanName(m.group(1)!);
      if (cleaned != null) return cleaned;
    }

    // 2) Bullet-prefixed: "• JUAN DELA CRUZ" (a single bullet before the name).
    final bulletRe = RegExp(r'^[•·\u2022]\s*(.+)$');
    for (final line in lines) {
      final m = bulletRe.firstMatch(line.trim());
      if (m == null) continue;
      final cleaned = _cleanName(m.group(1)!);
      if (cleaned != null) return cleaned;
    }

    // 3) ALL-CAPS line that looks like a name (2-4 words, each 2+ letters),
    //    preferring lines that follow a bullet/separator line.
    for (var i = 0; i < lines.length; i++) {
      final t = lines[i].trim();
      if (t.isEmpty) continue;
      if (!RegExp(r"^[A-Z][A-Z.'\- ]+$").hasMatch(t)) continue;
      final cleaned = _cleanName(t);
      if (cleaned == null) continue;
      final words = cleaned.split(' ');
      if (words.length < 2 || words.length > 4) continue;
      return cleaned;
    }

    return null;
  }

  // ── Phone extraction ────────────────────────────────────────────────────
  /// Finds a Philippine mobile number in [text] and returns it as
  /// 09XXXXXXXXX (0 prefix, max 11 significant chars). Handles +63, 63, 0 and
  /// bare 9 prefixes, with spaces or dashes between groups, AND masked numbers
  /// where hidden digits are shown as bullets (e.g. "09•• ••• 4567").
  /// Bullet masks are preserved so the user sees exactly what the receipt shows.
  static String? _extractPhone(String text) {
    // Real (unmasked) mobile numbers: +63 / 63 / 0 / 9 prefixes.
    // Allow spaces, dashes, dots and middots as group separators (OCR often
    // misreads the spacing between digit groups).
    final sep = r'[\s\-.\·]';
    final realRe = RegExp('(?:\\+?63|0)$sep?9\\d{2}$sep?\\d{3}$sep?\\d{4}');
    for (final m in realRe.allMatches(text)) {
      final norm = _normalizePhone(_digitsOf(m.group(0)!));
      if (norm != null) return norm;
    }
    // Bare 9XXXXXXXXX (10 digits, no 0/63 prefix).
    final bareRe = RegExp('(?<!\\d)9\\d{2}$sep?\\d{3}$sep?\\d{4}(?!\\d)');
    for (final m in bareRe.allMatches(text)) {
      final norm = _normalizePhone(_digitsOf(m.group(0)!));
      if (norm != null) return norm;
    }

    // Masked numbers: groups of digits and bullets, e.g. "09•• ••• 4567",
    // "+63 9•• ••• 4567". Match a run that starts with 0/63/+63/9 and mixes
    // digits and bullets.
    final maskedRe = RegExp(
      '(?:\\+?63|0)?$sep?(?:9|0)[0-9•·]{2}$sep?(?:[0-9•·]{3})$sep?(?:[0-9•·]{4})',
    );
    for (final m in maskedRe.allMatches(text)) {
      final raw = m.group(0)!;
      // Skip if this is purely digits (already handled above).
      if (!raw.contains('•') && !raw.contains('·')) continue;
      final norm = _normalizeMaskedPhone(raw);
      if (norm != null) return norm;
    }
    return null;
  }

  /// Normalizes a digits-only phone string to 09XXXXXXXXX (or null if invalid).
  static String? _normalizePhone(String digits) {
    if (digits.startsWith('63') && digits.length == 12) {
      return '0${digits.substring(2)}'; // +639XXXXXXXXX -> 09XXXXXXXXX
    }
    if (digits.length == 11 && digits.startsWith('9')) return '0$digits';
    if (digits.length == 10 && digits.startsWith('9')) return '0$digits';
    if (digits.length == 11 && digits.startsWith('0')) return digits;
    return null;
  }

  /// Normalizes a masked phone (digits + bullets) to a 0-prefixed string,
  /// preserving bullet masks and limiting to 11 significant characters.
  static String? _normalizeMaskedPhone(String raw) {
    // Drop the country code prefix (+63 / 63) and surrounding spaces/dashes.
    var s = raw.trim();
    s = s.replaceAll(RegExp(r'^\+?63[\s-]?'), ''); // +63 / 63 -> ''
    // Remove spaces and dashes (keep digits and bullets).
    s = s.replaceAll(RegExp(r'[\s-]'), '');
    // If it still starts with 63 (e.g. "63" glued to number), strip it.
    if (s.startsWith('63') && s.length > 11) s = s.substring(2);
    // Ensure a leading 0.
    if (!s.startsWith('0') && !s.startsWith('•')) s = '0$s';
    // Limit to 11 significant characters (digits + bullets).
    final chars = s.split('');
    if (chars.length > 11) {
      s = chars.take(11).join();
    }
    // Must contain at least one digit and at least one bullet to be a mask.
    if (!RegExp(r'\d').hasMatch(s)) return null;
    if (!RegExp(r'[•·]').hasMatch(s)) return null;
    return s;
  }
}