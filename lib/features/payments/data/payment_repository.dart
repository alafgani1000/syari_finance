import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../installments/domain/installment.dart';

class PaymentRepository {
  PaymentRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;
  final AppDatabase _database;
  final _uuid = const Uuid();

  Future<void> record(
      {required Installment installment,
      required int amount,
      required String method,
      String? notes}) async {
    if (amount <= 0 || amount > installment.remaining)
      throw ArgumentError('Nominal pembayaran tidak valid');
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      final row = (await txn.rawQuery(
              'SELECT i.*, f.customer_id, f.id AS financing_id FROM installments i JOIN financings f ON f.id = i.financing_id WHERE i.id = ?',
              [installment.id]))
          .single;
      final paid = (row['paid_amount']! as int) + amount;
      final due = row['amount']! as int;
      if (paid > due)
        throw ArgumentError('Nominal pembayaran melebihi sisa angsuran');
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
        'created_at': now
      });
      await txn.update(
          'installments',
          {
            'paid_amount': paid,
            'status': paid == due ? 'Lunas' : 'Sebagian',
            'paid_date': paid == due ? now : null,
            'updated_at': now
          },
          where: 'id = ?',
          whereArgs: [installment.id]);
      final unpaid = Sqflite.firstIntValue(await txn.rawQuery(
              'SELECT COUNT(*) FROM installments WHERE financing_id = ? AND paid_amount < amount',
              [row['financing_id']])) ??
          0;
      if (unpaid == 0)
        await txn.update('financings', {'status': 'Lunas', 'updated_at': now},
            where: 'id = ?', whereArgs: [row['financing_id']]);
    });
  }
}
