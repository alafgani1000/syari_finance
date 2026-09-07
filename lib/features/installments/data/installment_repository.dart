import '../../../core/database/app_database.dart';
import '../domain/installment.dart';

class InstallmentRepository {
  InstallmentRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;
  final AppDatabase _database;

  Future<List<Installment>> getOpenInstallments() async {
    final db = await _database.database;
    final rows =
        await db.rawQuery('''SELECT i.*, f.financing_number, f.item_name,
        c.name AS customer_name,
        c.phone AS customer_phone
      FROM installments i
      JOIN financings f ON f.id = i.financing_id
      JOIN customers c ON c.id = f.customer_id
      WHERE i.paid_amount < i.amount AND f.status = 'Aktif'
      ORDER BY i.due_date ASC''');
    return rows.map(_fromRow).toList();
  }

  Future<List<Installment>> getForFinancing(String financingNumber) async {
    final db = await _database.database;
    final rows = await db.rawQuery('''
      SELECT i.*, f.financing_number, f.item_name, c.name AS customer_name,
        c.phone AS customer_phone
      FROM installments i
      JOIN financings f ON f.id = i.financing_id
      JOIN customers c ON c.id = f.customer_id
      WHERE f.financing_number = ?
      ORDER BY i.installment_number ASC
    ''', [financingNumber]);
    return rows.map(_fromRow).toList();
  }

  Future<List<Installment>> getDueToday() async {
    final all = await getOpenInstallments();
    final today = DateTime.now();
    return all
        .where((item) =>
            item.dueDate.year == today.year &&
            item.dueDate.month == today.month &&
            item.dueDate.day == today.day)
        .toList();
  }

  Installment _fromRow(Map<String, Object?> row) => Installment(
        id: row['id']! as String,
        financingNumber: row['financing_number']! as String,
        customerName: row['customer_name']! as String,
        customerPhone: row['customer_phone']! as String,
        itemName: row['item_name']! as String,
        number: row['installment_number']! as int,
        dueDate: DateTime.parse(row['due_date']! as String),
        amount: row['amount']! as int,
        paidAmount: row['paid_amount']! as int,
      );
}
