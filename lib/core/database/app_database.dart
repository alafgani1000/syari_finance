import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final instance = AppDatabase._();

  static const databaseName = 'syari_finance.db';
  static const schemaVersion = 1;

  Database? _database;

  Future<Database> get database async => _database ??= await openDatabase(
        await databasePath,
        version: schemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await db.execute('''CREATE TABLE customers (
            id TEXT PRIMARY KEY, nik TEXT, name TEXT NOT NULL, phone TEXT NOT NULL,
            address TEXT, occupation TEXT, income INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL, updated_at TEXT NOT NULL)''');
          await db.execute('''CREATE TABLE financings (
            id TEXT PRIMARY KEY, customer_id TEXT NOT NULL, financing_number TEXT NOT NULL UNIQUE,
            item_name TEXT NOT NULL, item_price INTEGER NOT NULL, down_payment INTEGER NOT NULL,
            principal INTEGER NOT NULL, margin INTEGER NOT NULL, sale_price INTEGER NOT NULL,
            tenor INTEGER NOT NULL, monthly_installment INTEGER NOT NULL, start_date TEXT NOT NULL,
            first_due_date TEXT NOT NULL, status TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
            FOREIGN KEY(customer_id) REFERENCES customers(id))''');
          await db.execute('''CREATE TABLE installments (
            id TEXT PRIMARY KEY, financing_id TEXT NOT NULL, installment_number INTEGER NOT NULL,
            due_date TEXT NOT NULL, amount INTEGER NOT NULL, paid_amount INTEGER NOT NULL DEFAULT 0,
            status TEXT NOT NULL, paid_date TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
            FOREIGN KEY(financing_id) REFERENCES financings(id))''');
          await db.execute('''CREATE TABLE payments (
            id TEXT PRIMARY KEY, customer_id TEXT NOT NULL, financing_id TEXT NOT NULL,
            installment_id TEXT NOT NULL, payment_date TEXT NOT NULL, amount INTEGER NOT NULL,
            payment_method TEXT NOT NULL, notes TEXT, status TEXT NOT NULL DEFAULT 'posted', created_at TEXT NOT NULL,
            FOREIGN KEY(customer_id) REFERENCES customers(id), FOREIGN KEY(financing_id) REFERENCES financings(id),
            FOREIGN KEY(installment_id) REFERENCES installments(id))''');
          await db.execute(
            '''CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)''',
          );
        },
      );

  Future<String> get databasePath async =>
      join(await getDatabasesPath(), databaseName);

  Future<Directory> backupDirectory() async {
    final directory = await getTemporaryDirectory();
    final backupDirectory =
        Directory(join(directory.path, 'syari_finance_backup'));
    if (!await backupDirectory.exists()) {
      await backupDirectory.create(recursive: true);
    }
    return backupDirectory;
  }

  Future<Uint8List> exportBytes() async {
    await database;
    await close();
    try {
      final file = File(await databasePath);
      if (!await file.exists()) {
        throw StateError('Database aplikasi tidak ditemukan.');
      }
      return Uint8List.fromList(await file.readAsBytes());
    } finally {
      await database;
    }
  }

  Future<void> restoreBytes(Uint8List restoredBytes) async {
    final path = await databasePath;
    final source = File(path);
    final temporary = File(path + '.restore_tmp');
    final rollback = File(path + '.pre_restore');

    await temporary.writeAsBytes(restoredBytes, flush: true);
    try {
      await _validateDatabase(temporary.path);
      await close();
      if (await source.exists()) {
        await source.copy(rollback.path);
      }
      await temporary.copy(path);
      await database;
      await _validateDatabase(path);
      if (await rollback.exists()) {
        await rollback.delete();
      }
    } catch (_) {
      await close();
      if (await rollback.exists()) {
        await rollback.copy(path);
      }
      rethrow;
    } finally {
      if (await temporary.exists()) {
        await temporary.delete();
      }
      await database;
    }
  }

  Future<void> close() async {
    final openDatabase = _database;
    _database = null;
    await openDatabase?.close();
  }

  Future<void> _validateDatabase(String path) async {
    final db = await openDatabase(path, readOnly: true);
    try {
      final integrity = await db.rawQuery('PRAGMA integrity_check');
      if (integrity.isEmpty || integrity.first.values.first != 'ok') {
        throw StateError('Database cadangan rusak.');
      }
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN ('customers', 'financings', 'installments', 'payments')",
      );
      if (tables.length != 4) {
        throw StateError('Struktur database cadangan tidak lengkap.');
      }
    } finally {
      await db.close();
    }
  }
}
