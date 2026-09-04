import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';

class BackupException implements Exception {
  BackupException(this.message);
  final String message;

  @override
  String toString() => message;
}

class BackupExport {
  const BackupExport({required this.file, required this.createdAt});
  final File file;
  final DateTime createdAt;
}

class BackupRepository {
  BackupRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  static const _formatVersion = 1;
  static const _iterations = 210000;
  static const _databaseEntry = 'database/syari_finance.db';
  static const _manifestEntry = 'manifest.json';

  final AppDatabase _database;
  final _cipher = AesGcm.with256bits();

  Future<BackupExport> createEncryptedBackup({
    required String password,
  }) async {
    _validatePassword(password);
    final createdAt = DateTime.now().toUtc();
    final databaseBytes = await _database.exportBytes();
    final manifest = <String, Object>{
      'formatVersion': _formatVersion,
      'schemaVersion': AppDatabase.schemaVersion,
      'createdAt': createdAt.toIso8601String(),
      'databaseFile': _databaseEntry,
      'databaseBytes': databaseBytes.length,
    };

    final archive = Archive()
      ..addFile(
          ArchiveFile(_databaseEntry, databaseBytes.length, databaseBytes))
      ..addFile(ArchiveFile(
        _manifestEntry,
        utf8.encode(jsonEncode(manifest)).length,
        utf8.encode(jsonEncode(manifest)),
      ));
    final zipped = ZipEncoder().encode(archive);
    if (zipped == null) {
      throw BackupException('Gagal menyiapkan berkas cadangan.');
    }

    final salt = await SecretKeyData.random(length: 16).extractBytes();
    final secretKey = await _deriveKey(password, salt);
    final secretBox = await _cipher.encrypt(zipped, secretKey: secretKey);

    final envelope = jsonEncode(<String, Object>{
      'type': 'syari-finance-backup',
      'formatVersion': _formatVersion,
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': _iterations,
      'cipher': 'AES-256-GCM',
      'salt': base64Encode(salt),
      'nonce': base64Encode(secretBox.nonce),
      'mac': base64Encode(secretBox.mac.bytes),
      'cipherText': base64Encode(secretBox.cipherText),
    });

    final directory = await _database.backupDirectory();
    final fileName = 'syari-finance-' + _fileStamp(createdAt) + '.syaribackup';
    final file = File(p.join(directory.path, fileName));
    await file.writeAsBytes(utf8.encode(envelope), flush: true);
    return BackupExport(file: file, createdAt: createdAt.toLocal());
  }

  Future<void> restoreEncryptedBackup({
    required File file,
    required String password,
  }) async {
    _validatePassword(password);
    if (!await file.exists()) {
      throw BackupException('Berkas cadangan tidak ditemukan.');
    }

    try {
      final envelope =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      if (envelope['type'] != 'syari-finance-backup' ||
          envelope['formatVersion'] != _formatVersion) {
        throw BackupException('Format cadangan tidak didukung aplikasi ini.');
      }

      final salt = base64Decode(envelope['salt'] as String);
      final secretKey = await _deriveKey(password, salt);
      final clearText = await _cipher.decrypt(
        SecretBox(
          base64Decode(envelope['cipherText'] as String),
          nonce: base64Decode(envelope['nonce'] as String),
          mac: Mac(base64Decode(envelope['mac'] as String)),
        ),
        secretKey: secretKey,
      );

      final archive = ZipDecoder().decodeBytes(clearText, verify: true);
      final manifestFile = archive.findFile(_manifestEntry);
      final databaseFile = archive.findFile(_databaseEntry);
      if (manifestFile == null || databaseFile == null) {
        throw BackupException('Isi cadangan tidak lengkap.');
      }

      final manifest = jsonDecode(
        utf8.decode(manifestFile.content as List<int>),
      ) as Map<String, dynamic>;
      final backupSchemaVersion = manifest['schemaVersion'];
      if (backupSchemaVersion is! int ||
          backupSchemaVersion > AppDatabase.schemaVersion) {
        throw BackupException(
          'Cadangan dibuat oleh versi aplikasi yang lebih baru.',
        );
      }

      final restoredBytes =
          Uint8List.fromList(databaseFile.content as List<int>);
      if (restoredBytes.isEmpty) {
        throw BackupException('Database pada cadangan kosong atau rusak.');
      }
      await _database.restoreBytes(restoredBytes);
    } on SecretBoxAuthenticationError {
      throw BackupException(
          'Kata sandi salah atau berkas cadangan telah diubah.');
    } on FormatException {
      throw BackupException(
          'Berkas ini bukan cadangan Syari Finance yang valid.');
    }
  }

  Future<DateTime?> lastBackupAt() async {
    final db = await _database.database;
    final rows = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['last_backup_at'],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DateTime.tryParse(rows.first['value'] as String)?.toLocal();
  }

  Future<void> recordBackup(DateTime createdAt) async {
    final db = await _database.database;
    await db.insert(
      'settings',
      {'key': 'last_backup_at', 'value': createdAt.toUtc().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<SecretKey> _deriveKey(String password, List<int> salt) {
    return Pbkdf2.hmacSha256(iterations: _iterations, bits: 256)
        .deriveKeyFromPassword(password: password, nonce: salt);
  }

  void _validatePassword(String password) {
    if (password.trim().length < 8) {
      throw BackupException('Kata sandi backup minimal 8 karakter.');
    }
  }

  String _fileStamp(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return value.year.toString() +
        two(value.month) +
        two(value.day) +
        '-' +
        two(value.hour) +
        two(value.minute);
  }
}
