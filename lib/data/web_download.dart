import 'dart:typed_data';

/// No-op on non-web platforms (web-only helper).
Future<void> downloadBytesOnWeb(Uint8List bytes, String filename) async {}