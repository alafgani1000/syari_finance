import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';

class DashboardData {
  const DashboardData(
      {required this.customerCount,
      required this.activeFinancingCount,
      required this.outstanding,
      required this.dueTodayCount,
      required this.overdueCount,
      required this.dueToday,
      required this.recentPayments});
  final int customerCount;
  final int activeFinancingCount;
  final int outstanding;
  final int dueTodayCount;
  final int overdueCount;
  final List<DashboardInstallment> dueToday;
  final List<RecentPayment> recentPayments;
}

class DashboardInstallment {
  const DashboardInstallment(
      {required this.customerName,
      required this.financingNumber,
      required this.number,
      required this.amount});
  final String customerName, financingNumber;
  final int number, amount;
}

class RecentPayment {
  const RecentPayment(
      {required this.customerName, required this.amount, required this.date});
  final String customerName;
  final int amount;
  final DateTime date;
}

class DashboardRepository {
  DashboardRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;
  final AppDatabase _database;

  Future<DashboardData> load() async {
    DatabaseException? lastClosedError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        return await _load();
      } on DatabaseException catch (error) {
        if (!error.toString().contains('database_closed')) rethrow;
        lastClosedError = error;
        await _database.waitUntilReady();
        if (attempt < 2) {
          await Future<void>.delayed(const Duration(milliseconds: 40));
        }
      }
    }
    throw lastClosedError!;
  }

  Future<DashboardData> _load() async {
    final db = await _database.database;
    final today = DateTime.now();
    final start =
        DateTime(today.year, today.month, today.day).toIso8601String();
    final end =
        DateTime(today.year, today.month, today.day + 1).toIso8601String();
    final customers =
        await db.rawQuery('SELECT COUNT(*) AS count FROM customers');
    final active = await db.rawQuery(
        "SELECT COUNT(*) AS count FROM financings WHERE status = 'Aktif'");
    final outstanding = await db.rawQuery(
        "SELECT COALESCE(SUM(i.amount - i.paid_amount), 0) AS total FROM installments i JOIN financings f ON f.id = i.financing_id WHERE f.status = 'Aktif'");
    final dueRows = await db.rawQuery(
        '''SELECT c.name AS customer_name, f.financing_number, i.installment_number, i.amount, i.paid_amount
      FROM installments i JOIN financings f ON f.id = i.financing_id JOIN customers c ON c.id = f.customer_id
      WHERE i.due_date >= ? AND i.due_date < ? AND i.paid_amount < i.amount ORDER BY i.due_date''',
        [start, end]);
    final overdue = await db.rawQuery(
        'SELECT COUNT(*) AS count FROM installments WHERE due_date < ? AND paid_amount < amount',
        [start]);
    final payments = await db.rawQuery(
        '''SELECT c.name AS customer_name, p.amount, p.payment_date FROM payments p
      JOIN customers c ON c.id = p.customer_id WHERE p.status = 'posted' ORDER BY p.payment_date DESC LIMIT 5''');
    int number(Map<String, Object?> row, String key) =>
        (row[key] as num?)?.toInt() ?? 0;
    return DashboardData(
        customerCount: number(customers.single, 'count'),
        activeFinancingCount: number(active.single, 'count'),
        outstanding: number(outstanding.single, 'total'),
        dueTodayCount: dueRows.length,
        overdueCount: number(overdue.single, 'count'),
        dueToday: dueRows
            .map((row) => DashboardInstallment(
                customerName: row['customer_name']! as String,
                financingNumber: row['financing_number']! as String,
                number: number(row, 'installment_number'),
                amount: number(row, 'amount') - number(row, 'paid_amount')))
            .toList(),
        recentPayments: payments
            .map((row) => RecentPayment(
                customerName: row['customer_name']! as String,
                amount: number(row, 'amount'),
                date: DateTime.parse(row['payment_date']! as String)))
            .toList());
  }
}
