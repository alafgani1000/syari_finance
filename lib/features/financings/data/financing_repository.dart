import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../domain/financing.dart';
import '../domain/installment_generator.dart';
import '../domain/murabahah_calculator.dart';

class FinancingRepository {
  FinancingRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;
  final AppDatabase _database;
  final _uuid = const Uuid();

  Future<List<Financing>> getAll() async {
    final db = await _database.database;
    final rows = await db.rawQuery('''
      SELECT f.*, c.name AS customer_name,
        COALESCE(SUM(i.amount - i.paid_amount), 0) AS remaining_amount
      FROM financings f
      JOIN customers c ON c.id = f.customer_id
      LEFT JOIN installments i ON i.financing_id = f.id
      GROUP BY f.id
      ORDER BY f.created_at DESC
    ''');
    return rows.map(_fromRow).toList();
  }

  Future<void> save(Financing financing) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      final customerId = financing.customerId;
      final financingId = _uuid.v4();
      final firstDueDate = addMonthsClamped(financing.startDate, 1);
      await txn.insert('financings', {
        'id': financingId,
        'customer_id': customerId,
        'order_id': financing.orderId,
        'financing_number': financing.number,
        'item_name': financing.itemName,
        'item_price': financing.itemPrice,
        'down_payment': financing.downPayment,
        'principal': financing.calculation.principal,
        'margin': financing.margin,
        'sale_price': financing.calculation.salePrice,
        'tenor': financing.tenor,
        'monthly_installment': financing.calculation.installment,
        'start_date': financing.startDate.toIso8601String(),
        'first_due_date': firstDueDate.toIso8601String(),
        'status': 'Aktif',
        'created_at': now,
        'updated_at': now,
      });
      if (financing.orderId != null) {
        await txn.update(
          'orders',
          {
            'status': 'Akad aktif',
            'commitment_status': 'Dikonversi',
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [financing.orderId],
        );
      }
      final schedules = InstallmentGenerator().generate(
        startDate: financing.startDate,
        tenor: financing.tenor,
        totalAmount: financing.calculation.salePrice,
      );
      for (final schedule in schedules) {
        await txn.insert('installments', {
          'id': _uuid.v4(),
          'financing_id': financingId,
          'installment_number': schedule.number,
          'due_date': schedule.dueDate.toIso8601String(),
          'amount': schedule.amount,
          'paid_amount': 0,
          'status': 'Belum Bayar',
          'created_at': now,
          'updated_at': now,
        });
      }
    });
  }

  Financing _fromRow(Map<String, Object?> row) => Financing(
        number: row['financing_number']! as String,
        orderId: row['order_id'] as String?,
        customerId: row['customer_id']! as String,
        customerName: row['customer_name']! as String,
        itemName: row['item_name']! as String,
        calculation: FinancingCalculation(
          principal: row['principal']! as int,
          salePrice: row['sale_price']! as int,
          installment: row['monthly_installment']! as int,
          finalInstallment: (row['sale_price']! as int) -
              ((row['monthly_installment']! as int) *
                  ((row['tenor']! as int) - 1)),
        ),
        itemPrice: row['item_price']! as int,
        downPayment: row['down_payment']! as int,
        margin: row['margin']! as int,
        tenor: row['tenor']! as int,
        startDate: DateTime.parse(row['start_date']! as String),
        status: row['status']! as String,
        remainingAmount: row['remaining_amount']! as int,
      );
}
