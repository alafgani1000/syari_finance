import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final instance = AppDatabase._();

  static const databaseName = 'syari_finance.db';
  static const schemaVersion = 4;

  Database? _database;
  Completer<void>? _restoreCompleter;
  Future<Database>? _openingDatabase;

  Future<Database> get database async {
    final restoring = _restoreCompleter;
    if (restoring != null) await restoring.future;

    final current = _database;
    if (current != null && current.isOpen) return current;
    _database = null;

    final existingOpening = _openingDatabase;
    if (existingOpening != null) return existingOpening;

    final opening = _openConfiguredDatabase();
    _openingDatabase = opening;
    try {
      final opened = await opening;
      _database = opened;
      return opened;
    } finally {
      if (identical(_openingDatabase, opening)) {
        _openingDatabase = null;
      }
    }
  }

  Future<void> waitUntilReady() async {
    final restoring = _restoreCompleter;
    if (restoring != null) await restoring.future;
  }

  Future<Database> _openConfiguredDatabase() async => openDatabase(
        await databasePath,
        version: schemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await db.execute('''CREATE TABLE customers (
            id TEXT PRIMARY KEY, nik TEXT, name TEXT NOT NULL, phone TEXT NOT NULL,
            address TEXT, occupation TEXT, income INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL, updated_at TEXT NOT NULL)''');
          await db.execute('''CREATE TABLE financings (
            id TEXT PRIMARY KEY, customer_id TEXT NOT NULL, order_id TEXT, financing_number TEXT NOT NULL UNIQUE,
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
            payment_method TEXT NOT NULL, notes TEXT, status TEXT NOT NULL DEFAULT 'posted',
            voided_at TEXT, voided_by TEXT, void_reason TEXT, reversal_of TEXT, created_at TEXT NOT NULL,
            FOREIGN KEY(customer_id) REFERENCES customers(id), FOREIGN KEY(financing_id) REFERENCES financings(id),
            FOREIGN KEY(installment_id) REFERENCES installments(id))''');
          await _createOrderTables(db);
          await _createPaymentIndexes(db);
          await db.execute(
            '''CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)''',
          );
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await _createOrderTables(db);
          }
          if (oldVersion < 3) {
            await db.execute('ALTER TABLE financings ADD COLUMN order_id TEXT');
          }
          if (oldVersion < 4) {
            await db.execute('ALTER TABLE payments ADD COLUMN voided_at TEXT');
            await db.execute('ALTER TABLE payments ADD COLUMN voided_by TEXT');
            await db
                .execute('ALTER TABLE payments ADD COLUMN void_reason TEXT');
            await db
                .execute('ALTER TABLE payments ADD COLUMN reversal_of TEXT');
            await _createPaymentIndexes(db);
          }
        },
      );

  Future<void> _createPaymentIndexes(DatabaseExecutor db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_payments_history ON payments(created_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_payments_installment ON payments(installment_id)',
    );
  }

  Future<void> _createOrderTables(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE orders (
      id TEXT PRIMARY KEY, order_number TEXT NOT NULL UNIQUE,
      customer_id TEXT NOT NULL, item_name TEXT NOT NULL,
      estimated_price INTEGER NOT NULL, supplier_name TEXT,
      commitment_amount INTEGER NOT NULL DEFAULT 0,
      commitment_received_at TEXT, commitment_status TEXT NOT NULL DEFAULT 'Belum diterima',
      purchase_price INTEGER, purchased_at TEXT, ownership_confirmed_at TEXT,
      status TEXT NOT NULL DEFAULT 'Pemesanan', notes TEXT,
      cancellation_reason TEXT, actual_loss INTEGER NOT NULL DEFAULT 0,
      refund_amount INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
      FOREIGN KEY(customer_id) REFERENCES customers(id))''');
    await db.execute(
      'CREATE INDEX idx_orders_customer_status ON orders(customer_id, status)',
    );
  }

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
    final temporary = File('$path.restore_tmp');
    final rollback = File('$path.pre_restore');

    await temporary.writeAsBytes(restoredBytes, flush: true);
    Completer<void>? restoreCompleter;
    try {
      await _validateDatabase(temporary.path);
      restoreCompleter = Completer<void>();
      _restoreCompleter = restoreCompleter;

      await close();
      if (await source.exists()) {
        await source.copy(rollback.path);
      }
      await temporary.copy(path);
      _database = await _openConfiguredDatabase();
      await _validateDatabase(path);
      if (await rollback.exists()) {
        await rollback.delete();
      }
    } catch (_) {
      if (restoreCompleter != null) {
        await close();
        if (await rollback.exists()) {
          await rollback.copy(path);
        }
        _database = await _openConfiguredDatabase();
      }
      rethrow;
    } finally {
      if (await temporary.exists()) {
        await temporary.delete();
      }
      _database ??= await _openConfiguredDatabase();
      _restoreCompleter = null;
      restoreCompleter?.complete();
    }
  }

  Future<void> close() async {
    final current = _database;
    final opening = _openingDatabase;
    _database = null;

    if (current != null && current.isOpen) {
      await current.close();
    }
    if (opening != null) {
      final opened = await opening;
      if (!identical(opened, current) && opened.isOpen) {
        await opened.close();
      }
      if (identical(_database, opened)) {
        _database = null;
      }
    }
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
