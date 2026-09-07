import 'package:flutter/services.dart';

import '../database/app_database.dart';

class DueReminderService {
  DueReminderService({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  static const _channel = MethodChannel('syari_finance/due_reminders');
  final AppDatabase _database;

  Future<bool> requestPermission() async =>
      (await _channel.invokeMethod<bool>('requestPermission')) ?? false;

  Future<bool> isPermissionGranted() async =>
      (await _channel.invokeMethod<bool>('isPermissionGranted')) ?? false;

  Future<int> scheduleUpcoming() async {
    final db = await _database.database;
    final now = DateTime.now();
    final latest = DateTime(now.year, now.month + 4, now.day);
    final rows = await db.rawQuery(
      '''SELECT i.id, i.installment_number, i.due_date, i.amount, i.paid_amount,
          c.name AS customer_name, f.financing_number
         FROM installments i
         JOIN financings f ON f.id = i.financing_id
         JOIN customers c ON c.id = f.customer_id
         WHERE i.paid_amount < i.amount AND i.due_date >= ? AND i.due_date <= ?
         ORDER BY i.due_date ASC''',
      [
        DateTime(now.year, now.month, now.day).toIso8601String(),
        latest.toIso8601String()
      ],
    );
    final reminders = rows.map((row) {
      final due = DateTime.parse(row['due_date']! as String);
      final notificationTime = DateTime(due.year, due.month, due.day, 9);
      return {
        'id': _stableId(row['id']! as String),
        'timestamp': notificationTime.millisecondsSinceEpoch,
        'title': 'Jatuh tempo angsuran hari ini',
        'body':
            '${row['customer_name']! as String} • ${row['financing_number']! as String} angsuran #${row['installment_number']}',
      };
    }).toList();
    final scheduled =
        await _channel.invokeMethod<int>('schedule', {'reminders': reminders});
    return scheduled ?? 0;
  }

  int _stableId(String value) {
    var hash = 2166136261;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 16777619) & 0x7fffffff;
    }
    return hash;
  }
}
