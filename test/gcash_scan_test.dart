import 'package:flutter_test/flutter_test.dart';

import 'package:tindaflow_app/data/gcash_receipt_reader.dart';

void main() {
  test('parses amount, reference, date and type from a GCash receipt text', () {
    const text = '''
GCash
You received PHP 1,250.00
Ref No. 1234 567 890123
Date: Nov 13, 2026
Fee: 15.00
''';
    final r = GcashReceiptReader.parse(text);
    expect(r.amount, 1250.0);
    expect(r.fee, 15.0);
    expect(r.reference, '1234567890123');
    expect(r.date, DateTime(2026, 11, 13));
    expect(r.type, 'Cash In');
  });

  test('detects cash out', () {
    const text = 'GCash\nYou sent PHP 500.00\nRef 9876 543 210987\n13/11/2026';
    final r = GcashReceiptReader.parse(text);
    expect(r.amount, 500.0);
    expect(r.type, 'Cash Out');
  });

  test('parses time, bullet name and +63 phone (converted to 0)', () {
    const text = '''
GCash
• Juan Dela Cruz
You sent PHP 500.00
Ref 9876 543 210987
13/11/2026 10:30 AM
To: +63 917 123 4567
''';
    final r = GcashReceiptReader.parse(text);
    expect(r.amount, 500.0);
    expect(r.type, 'Cash Out');
    expect(r.name, 'Juan Dela Cruz');
    expect(r.phone, '09171234567');
    expect(r.hour, 10);
    expect(r.minute, 30);
    expect(r.date, DateTime(2026, 11, 13));
  });

  test('detects 24-hour time', () {
    const text = 'GCash\nSent PHP 100.00\nRef 1111 222 333444\n2026-11-13 22:15';
    final r = GcashReceiptReader.parse(text);
    expect(r.hour, 22);
    expect(r.minute, 15);
  });

  test('reads name from a bullet-mask line (•••• then name below)', () {
    const text = '''
GCash
You sent PHP 250.00
Ref 1234 567 890123
To: •••• 4567
JUAN DELA CRUZ
''';
    final r = GcashReceiptReader.parse(text);
    expect(r.name, 'Juan Dela Cruz');
    expect(r.type, 'Cash Out');
  });

  test('reads ALL-CAPS name after a bullet', () {
    const text = 'GCash\n• JUAN DELA CRUZ\nSent PHP 500.00\nRef 9876 543 210987';
    final r = GcashReceiptReader.parse(text);
    expect(r.name, 'Juan Dela Cruz');
  });

  test('converts +63 without spaces to 0-prefixed number', () {
    const text = 'GCash\nTo: +639203238664\nSent PHP 100.00\nRef 1111 222 333444';
    final r = GcashReceiptReader.parse(text);
    expect(r.phone, '09203238664');
  });

  test('normalizes 09xx and bare 9xx numbers', () {
    expect(GcashReceiptReader.parse('To: 0917 123 4567').phone, '09171234567');
    expect(GcashReceiptReader.parse('To: 9171234567').phone, '09171234567');
  });

  test('reads phone with dot / middot separators (OCR artifacts)', () {
    expect(GcashReceiptReader.parse('To: 0917.123.4567').phone, '09171234567');
    expect(GcashReceiptReader.parse('To: 0917·123·4567').phone, '09171234567');
    expect(GcashReceiptReader.parse('To: +63 917 123 4567').phone, '09171234567');
  });

  test('extracts masked name with bullets preserved', () {
    const text = '''
GCash
You sent PHP 500.00
Ref 9876 543 210987
FR••H AN•••W E.
''';
    final r = GcashReceiptReader.parse(text);
    expect(r.name, 'FR••H AN•••W E.');
  });

  test('extracts masked name after a label', () {
    const text = 'GCash\nTo: FR••H AN•••W E.\nSent PHP 500.00\nRef 9876 543 210987';
    final r = GcashReceiptReader.parse(text);
    expect(r.name, 'FR••H AN•••W E.');
  });

  test('extracts masked phone with bullets, +63 to 0, max 11', () {
    const text = 'GCash\nTo: +63 9•• ••• 4567\nSent PHP 100.00\nRef 1111 222 333444';
    final r = GcashReceiptReader.parse(text);
    expect(r.phone, '09•••••4567');
  });

  test('extracts masked phone starting with 0', () {
    const text = 'GCash\n09•• ••• 4567\nSent PHP 100.00\nRef 1111 222 333444';
    final r = GcashReceiptReader.parse(text);
    expect(r.phone, '09•••••4567');
  });

  test('fixes OCR misread bullets (o -> •) in masked name', () {
    // OCR read "FR••H" as "FRo•H" and "AN•••W" as "ANo••W".
    const text = 'GCash\nFRo•H ANo••WE.\nSent PHP 500.00\nRef 9876 543 210987';
    final r = GcashReceiptReader.parse(text);
    // Bullets restored, ALL CAPS, space before the middle initial restored.
    expect(r.name, 'FR••H AN•••W E.');
  });

  test('fixes OCR misread bullets after a label', () {
    const text = 'GCash\nTo: FRo•H ANo••WE.\nSent PHP 500.00\nRef 9876 543 210987';
    final r = GcashReceiptReader.parse(text);
    expect(r.name, 'FR••H AN•••W E.');
  });

  test('fixes the reported "e" bullet misread and lost spacing', () {
    // Exact case from the device: "FR••H AN•••W E." came back as
    // "Fre•H ANeoWE." — bullets read as "e", casing lost, space dropped.
    const text = 'GCash\nFre•H ANeoWE.\nSent PHP 500.00\nRef 9876 543 210987';
    final r = GcashReceiptReader.parse(text);
    expect(r.name, 'FR••H AN••W E.');
  });

  test('repairs a fully misread masked name (no real bullets at all)', () {
    // Every bullet was read as a letter, so the line has no "•" at all.
    const text = 'GCash\nFRoH ANoeWE.\nSent PHP 500.00\nRef 9876 543 210987';
    final r = GcashReceiptReader.parse(text);
    expect(r.name, 'FR•H AN••W E.');
  });

  test('uppercases a lower-case masked name', () {
    const text = 'GCash\nfr••h an•••w e.\nSent PHP 500.00\nRef 9876 543 210987';
    final r = GcashReceiptReader.parse(text);
    expect(r.name, 'FR••H AN•••W E.');
  });

  test('does not turn a real name with "o"/"a" into bullets', () {
    // A normal (unmasked) name must be left alone — only masked words are
    // repaired, and this line has no bullets at all.
    const text = 'GCash\nTo: JUAN DELA CRUZ\nSent PHP 500.00\nRef 9876 543 210987';
    final r = GcashReceiptReader.parse(text);
    expect(r.name, 'Juan Dela Cruz');
  });

  test('returns nulls when text is unrelated', () {
    final r = GcashReceiptReader.parse('hello world this is not a receipt');
    expect(r.amount, isNull);
    expect(r.reference, isNull);
    expect(r.type, isNull);
    expect(r.name, isNull);
    expect(r.phone, isNull);
    expect(r.hour, isNull);
  });

  test('does not read "Total Amount Sent" as the customer name', () {
    // Long/clear receipts contain this label line; it must not leak into name.
    final r = GcashReceiptReader.parse(
      'GCash Receipt\n'
      'You sent ₱500.00\n'
      'To: JUAN DELA CRUZ\n'
      'Total Amount Sent\n'
      '500.00\n'
      'Reference 123 456 789012\n',
    );
    expect(r.name, 'Juan Dela Cruz');
  });

  test('reads name and number from a long multi-section receipt', () {
    // Simulates a tall receipt where the name/number sit far from the amount.
    final r = GcashReceiptReader.parse(
      'GCash\n'
      'Transaction Details\n'
      'You sent PHP 2,000.00\n'
      'Ref No. 1234 567 890123\n'
      'Date: Nov 13, 2026\n'
      'Time: 10:30 AM\n'
      'Fee: 20.00\n'
      'To: MARIA SANTOS\n'
      'Mobile: +63 917 123 4567\n'
      'Balance: 5,000.00\n'
      'Thank you for using GCash\n',
    );
    expect(r.name, 'Maria Santos');
    expect(r.phone, '09171234567');
    expect(r.amount, 2000.0);
    expect(r.reference, '1234567890123');
  });

  test('reads a masked GCash name and number together', () {
    final r = GcashReceiptReader.parse(
      'GCash\n'
      'You received PHP 300.00\n'
      'To: FR••H AN•••W E.\n'
      '09•• ••• 4567\n',
    );
    expect(r.name, 'FR••H AN•••W E.');
    expect(r.phone, '09•••••4567');
  });

  group('isGcashReceipt', () {
    test('accepts a real GCash receipt', () {
      expect(
        GcashReceiptReader.isGcashReceipt(
          'GCash\nYou sent PHP 500.00\nRef No. 1234 567 890123\n'
          'To: JUAN DELA CRUZ\nBalance: 1,000.00',
        ),
        isTrue,
      );
    });

    test('accepts a receipt with noisy OCR text', () {
      expect(
        GcashReceiptReader.isGcashReceipt(
          'gcash\nTotal Amount Sent\n1,250.00\nref 9876 543 210987\nfee 15.00',
        ),
        isTrue,
      );
    });

    test('rejects a random photo with no receipt keywords', () {
      expect(
        GcashReceiptReader.isGcashReceipt(
          'a photo of my dog running in the park on a sunny day',
        ),
        isFalse,
      );
    });

    test('rejects a receipt with no transaction signal', () {
      // Receipt-like words but no amount and no reference number.
      expect(
        GcashReceiptReader.isGcashReceipt(
          'GCash\nTransaction Details\nThank you for using GCash',
        ),
        isFalse,
      );
    });

    test('rejects an amount with no receipt keywords', () {
      expect(
        GcashReceiptReader.isGcashReceipt(
          'The price is 250.00 dollars for the item you bought today',
        ),
        isFalse,
      );
    });

    test('rejects very short text', () {
      expect(GcashReceiptReader.isGcashReceipt('GCash 500.00'), isFalse);
    });

    test('rejects an empty string', () {
      expect(GcashReceiptReader.isGcashReceipt(''), isFalse);
    });
  });
}