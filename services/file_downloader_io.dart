import 'dart:io';
import 'dart:typed_data';

Future<String?> downloadBytes(Uint8List bytes, String filename) async {
  final candidates = <String>[];

  if (Platform.isAndroid) {
    candidates.addAll([
      '/storage/emulated/0/Download',
      '/sdcard/Download',
    ]);
  } else {
    candidates.addAll([
      Directory.current.path,
      Directory.systemTemp.path,
    ]);
  }

  for (final folder in candidates) {
    try {
      final dir = Directory(folder);
      if (!await dir.exists()) continue;
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      // try next location
    }
  }

  return null;
}
