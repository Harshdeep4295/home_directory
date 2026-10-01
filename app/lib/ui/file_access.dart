import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Picking and saving files (config backups, tinytuya devices.json).
abstract interface class FileAccess {
  Future<(String, Uint8List)?> pick({List<String>? extensions});

  /// Returns where the file went (for the confirmation message), or null if cancelled.
  Future<String?> save(
    String name,
    Uint8List bytes, {
    String mimeType = 'application/json',
  });
}

class PluginFileAccess implements FileAccess {
  @override
  Future<(String, Uint8List)?> pick({List<String>? extensions}) async {
    final files = await FilePicker.pickFiles(
      type: extensions == null ? FileType.any : FileType.custom,
      allowedExtensions: extensions,
    );
    if (files.isEmpty) return null;
    final f = files.first;
    return (f.name, await f.xFile.readAsBytes());
  }

  @override
  Future<String?> save(
    String name,
    Uint8List bytes, {
    String mimeType = 'application/json',
  }) async => (await FilePicker.saveFile(
    fileName: name,
    bytes: bytes,
    mimeType: mimeType,
  ))?.toString();
}

final fileAccessProvider = Provider<FileAccess>((ref) => PluginFileAccess());
