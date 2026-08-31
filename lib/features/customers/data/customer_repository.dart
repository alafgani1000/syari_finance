import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../presentation/customers_page.dart';

class CustomerChoice {
  const CustomerChoice(
      {required this.id, required this.name, required this.phone});
  final String id;
  final String name;
  final String phone;
}

class CustomerRepository {
  CustomerRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;
  final AppDatabase _database;
  final _uuid = const Uuid();

  Future<List<Customer>> getAll() async {
    final db = await _database.database;
    final rows = await db.query('customers', orderBy: 'created_at DESC');
    return rows
        .map((row) => Customer(
            name: row['name']! as String,
            phone: row['phone']! as String,
            nik: row['nik'] as String? ?? '',
            income: row['income']! as int))
        .toList();
  }

  Future<List<CustomerChoice>> getChoices() async {
    final db = await _database.database;
    final rows = await db.query('customers',
        columns: ['id', 'name', 'phone'], orderBy: 'name COLLATE NOCASE');
    return rows
        .where((row) => row['phone'] != '-')
        .map((row) => CustomerChoice(
            id: row['id']! as String,
            name: row['name']! as String,
            phone: row['phone']! as String))
        .toList();
  }

  Future<void> save(Customer customer) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();
    final existing = await db.query('customers',
        where: 'name = ? AND phone = ?',
        whereArgs: [customer.name, customer.phone],
        limit: 1);
    if (existing.isEmpty)
      await db.insert('customers', {
        'id': _uuid.v4(),
        'nik': customer.nik.isEmpty ? null : customer.nik,
        'name': customer.name,
        'phone': customer.phone,
        'income': customer.income,
        'created_at': now,
        'updated_at': now
      });
  }
}
