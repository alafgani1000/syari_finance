import 'dart:io';

import 'package:flutter/services.dart';

enum BackupDestination { googleDrive, device, other }

class BackupFileChannel {
  BackupFileChannel._();

  static const _channel = MethodChannel('syari_finance/backup_files');

  static Future<String?> saveBackup(
    File file, {
    required BackupDestination destination,
  }) async {
    final savedLocation = await _channel.invokeMethod<String>(
      'saveBackup',
      <String, String>{
        'sourcePath': file.path,
        'fileName': file.uri.pathSegments.last,
        'destination': destination.name,
      },
    );
    return savedLocation;
  }

  static Future<File?> pickBackup() async {
    final path = await _channel.invokeMethod<String>('pickBackup');
    return path == null ? null : File(path);
  }
}
