import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';

class DashboardData {
  const DashboardData({
    required this.customerCount,
    required this.activeFinancingCount,
    required this.outstanding,
    required this.dueTodayCount,
    required this.overdueCount,
    required this.totalDisbursed,
    required this.plannedMargin,
    required this.overdueAmount,
    required this.collectedThisMonth,
    required this.dueToday,
    required this.recentPayments,
    required this.monthlyCollections,
  });

  final int customerCount;
  final int activeFinancingCount;
  final int outstanding;
  final int dueTodayCount;
  final int overdueCount;
  final int totalDisbursed;
  final int plannedMargin;
  final int overdueAmount;
  final int collectedThisMonth;
  final List<DashboardInstallment> dueToday;
  final List<RecentPayment> recentPayments;
  final List<MonthlyCollection> monthlyCollections;
}

class DashboardInstallment {
  const DashboardInstallment({
    required this.customerName,
    required this.financingNumber,
    required this.number,
    required this.amount,
  });

  final String customerName;
  final String financingNumber;
  final int number;
  final int amount;
}

class RecentPayment {
  const RecentPayment({
    required this.customerName,
    required this.amount,
    required this.date,
  });

  final String customerName;
  final int amount;
  final DateTime date;
}

class MonthlyCollection {
  const MonthlyCollection({
    required this.month,
    required this.amount,
  });

  final DateTime month;
  final int amount;
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
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final tomorrow = dayStart.add(const Duration(days: 1));
    final monthStart = DateTime(now.year, now.month);
    final start = dayStart.toIso8601String();
    final end = tomorrow.toIso8601String();
    final monthStartValue = monthStart.toIso8601String();

    final results = await Future.wait([
      db.rawQuery('SELECT COUNT(*) AS count FROM customers'),
      db.rawQuery(
          "SELECT COUNT(*) AS count FROM financings WHERE status = 'Aktif'"),
      db.rawQuery(
          "SELECT COALESCE(SUM(i.amount - i.paid_amount), 0) AS total FROM installments i JOIN financings f ON f.id = i.financing_id WHERE f.status = 'Aktif'"),
      db.rawQuery(
          '''SELECT c.name AS customer_name, f.financing_number, i.installment_number, i.amount, i.paid_amount
        FROM installments i JOIN financings f ON f.id = i.financing_id JOIN customers c ON c.id = f.customer_id
        WHERE i.due_date >= ? AND i.due_date < ? AND i.paid_amount < i.amount ORDER BY i.due_date''',
          [start, end]),
      db.rawQuery(
          'SELECT COUNT(*) AS count FROM installments WHERE due_date < ? AND paid_amount < amount',
          [start]),
      db.rawQuery(
          'SELECT COALESCE(SUM(i.amount - i.paid_amount), 0) AS total FROM installments i WHERE i.due_date < ? AND i.paid_amount < i.amount',
          [start]),
      db.rawQuery(
          "SELECT COALESCE(SUM(principal), 0) AS total FROM financings WHERE status IN ('Aktif', 'Lunas')"),
      db.rawQuery(
          "SELECT COALESCE(SUM(margin), 0) AS total FROM financings WHERE status IN ('Aktif', 'Lunas')"),
      db.rawQuery(
          "SELECT COALESCE(SUM(amount), 0) AS total FROM payments WHERE status = 'posted' AND payment_date >= ?",
          [monthStartValue]),
      db.rawQuery(
          '''SELECT c.name AS customer_name, p.amount, p.payment_date FROM payments p
        JOIN customers c ON c.id = p.customer_id WHERE p.status = 'posted' ORDER BY p.payment_date DESC LIMIT 5'''),
      db.rawQuery(
          """SELECT substr(payment_date, 1, 7) AS month, COALESCE(SUM(amount), 0) AS total
        FROM payments WHERE status = 'posted' AND payment_date >= ?
        GROUP BY substr(payment_date, 1, 7) ORDER BY month ASC""",
          [DateTime(now.year, now.month - 5).toIso8601String()]),
    ]);

    int number(Map<String, Object?> row, String key) =>
        (row[key] as num?)?.toInt() ?? 0;
    final dueRows = results[3];
    final monthlyRows = results[10];
    return DashboardData(
      customerCount: number(results[0].single, 'count'),
      activeFinancingCount: number(results[1].single, 'count'),
      outstanding: number(results[2].single, 'total'),
      dueTodayCount: dueRows.length,
      overdueCount: number(results[4].single, 'count'),
      overdueAmount: number(results[5].single, 'total'),
      totalDisbursed: number(results[6].single, 'total'),
      plannedMargin: number(results[7].single, 'total'),
      collectedThisMonth: number(results[8].single, 'total'),
      dueToday: dueRows
          .map((row) => DashboardInstallment(
                customerName: row['customer_name']! as String,
                financingNumber: row['financing_number']! as String,
                number: number(row, 'installment_number'),
                amount: number(row, 'amount') - number(row, 'paid_amount'),
              ))
          .toList(),
      recentPayments: results[9]
          .map((row) => RecentPayment(
                customerName: row['customer_name']! as String,
                amount: number(row, 'amount'),
                date: DateTime.parse(row['payment_date']! as String),
              ))
          .toList(),
      monthlyCollections: monthlyRows
          .map((row) => MonthlyCollection(
                month: DateTime.parse('${row['month']! as String}-01'),
                amount: number(row, 'total'),
              ))
          .toList(),
    );
  }
}
