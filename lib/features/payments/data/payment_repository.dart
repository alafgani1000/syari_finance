import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../installments/domain/installment.dart';

class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.customerName,
    required this.financingNumber,
    required this.installmentNumber,
    required this.amount,
    required this.paymentDate,
    required this.paymentMethod,
    required this.status,
    this.notes,
    this.voidedAt,
    this.voidedBy,
    this.voidReason,
    this.reversalOf,
  });

  final String id;
  final String customerName;
  final String financingNumber;
  final int installmentNumber;
  final int amount;
  final DateTime paymentDate;
  final String paymentMethod;
  final String status;
  final String? notes;
  final DateTime? voidedAt;
  final String? voidedBy;
  final String? voidReason;
  final String? reversalOf;

  bool get canReverse => status == 'posted';
  bool get isVoided => status == 'Dibatalkan';
  bool get isReversal => status == 'Pembalik';
}

class PaymentRepository {
  PaymentRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;
  final _uuid = const Uuid();

  Future<void> record({
    required Installment installment,
    required int amount,
    required String method,
    String? notes,
  }) async {
    if (amount <= 0 || amount > installment.remaining) {
      throw ArgumentError('Nominal pembayaran tidak valid');
    }
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      final row = (await txn.rawQuery(
        '''SELECT i.*, f.customer_id, f.id AS financing_id
           FROM installments i
           JOIN financings f ON f.id = i.financing_id
           WHERE i.id = ?''',
        [installment.id],
      ))
          .single;
      final paid = (row['paid_amount']! as int) + amount;
      final due = row['amount']! as int;
      if (paid > due) {
        throw ArgumentError('Nominal pembayaran melebihi sisa angsuran');
      }
      await txn.insert('payments', {
        'id': _uuid.v4(),
        'customer_id': row['customer_id'],
        'financing_id': row['financing_id'],
        'installment_id': installment.id,
        'payment_date': now,
        'amount': amount,
        'payment_method': method,
        'notes': notes,
        'status': 'posted',
        'created_at': now,
      });
      await txn.update(
        'installments',
        {
          'paid_amount': paid,
          'status': paid == due ? 'Lunas' : 'Sebagian',
          'paid_date': paid == due ? now : null,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [installment.id],
      );
      await _refreshFinancingStatus(txn, row['financing_id']! as String, now);
    });
  }

  Future<List<PaymentRecord>> getHistory({int limit = 40}) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      '''SELECT p.*, c.name AS customer_name, f.financing_number,
           i.installment_number
         FROM payments p
         JOIN customers c ON c.id = p.customer_id
         JOIN financings f ON f.id = p.financing_id
         JOIN installments i ON i.id = p.installment_id
         ORDER BY p.created_at DESC
         LIMIT ?''',
      [limit],
    );
    return rows.map(_recordFromRow).toList();
  }

  Future<void> reverse({
    required PaymentRecord payment,
    required String reason,
    required String officer,
  }) async {
    final normalizedReason = reason.trim();
    final normalizedOfficer = officer.trim();
    if (normalizedReason.isEmpty) {
      throw ArgumentError('Alasan pembatalan wajib diisi');
    }
    if (normalizedOfficer.isEmpty) {
      throw ArgumentError('Nama petugas wajib diisi');
    }

    final db = await _database.database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      final rows = await txn.rawQuery(
        '''SELECT p.*, i.paid_amount, i.amount AS installment_amount
           FROM payments p
           JOIN installments i ON i.id = p.installment_id
           WHERE p.id = ?''',
        [payment.id],
      );
      if (rows.isEmpty) {
        throw StateError('Pembayaran tidak ditemukan');
      }
      final row = rows.single;
      if (row['status'] != 'posted') {
        throw StateError('Pembayaran ini sudah tidak dapat dibatalkan');
      }

      final amount = row['amount']! as int;
      final paidAmount = row['paid_amount']! as int;
      final updatedPaidAmount = paidAmount - amount;
      if (updatedPaidAmount < 0) {
        throw StateError('Saldo angsuran tidak konsisten');
      }

      await txn.update(
        'payments',
        {
          'status': 'Dibatalkan',
          'voided_at': now,
          'voided_by': normalizedOfficer,
          'void_reason': normalizedReason,
        },
        where: 'id = ?',
        whereArgs: [payment.id],
      );
      await txn.insert('payments', {
        'id': _uuid.v4(),
        'customer_id': row['customer_id'],
        'financing_id': row['financing_id'],
        'installment_id': row['installment_id'],
        'payment_date': now,
        'amount': -amount,
        'payment_method': row['payment_method'],
        'notes': 'Transaksi pembalik pembayaran yang dibatalkan',
        'status': 'Pembalik',
        'reversal_of': payment.id,
        'created_at': now,
      });
      final installmentAmount = row['installment_amount']! as int;
      await txn.update(
        'installments',
        {
          'paid_amount': updatedPaidAmount,
          'status': updatedPaidAmount == 0 ? 'Belum Bayar' : 'Sebagian',
          'paid_date': updatedPaidAmount == installmentAmount ? now : null,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [row['installment_id']],
      );
      await _refreshFinancingStatus(
        txn,
        row['financing_id']! as String,
        now,
      );
    });
  }

  Future<void> _refreshFinancingStatus(
    Transaction txn,
    String financingId,
    String now,
  ) async {
    final unpaid = Sqflite.firstIntValue(
          await txn.rawQuery(
            'SELECT COUNT(*) FROM installments WHERE financing_id = ? AND paid_amount < amount',
            [financingId],
          ),
        ) ??
        0;
    await txn.update(
      'financings',
      {'status': unpaid == 0 ? 'Lunas' : 'Aktif', 'updated_at': now},
      where: 'id = ?',
      whereArgs: [financingId],
    );
  }

  PaymentRecord _recordFromRow(Map<String, Object?> row) => PaymentRecord(
        id: row['id']! as String,
        customerName: row['customer_name']! as String,
        financingNumber: row['financing_number']! as String,
        installmentNumber: row['installment_number']! as int,
        amount: row['amount']! as int,
        paymentDate: DateTime.parse(row['payment_date']! as String),
        paymentMethod: row['payment_method']! as String,
        status: row['status']! as String,
        notes: row['notes'] as String?,
        voidedAt: row['voided_at'] == null
            ? null
            : DateTime.tryParse(row['voided_at']! as String),
        voidedBy: row['voided_by'] as String?,
        voidReason: row['void_reason'] as String?,
        reversalOf: row['reversal_of'] as String?,
      );
}
