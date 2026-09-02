import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../domain/order.dart';

class OrderDraft {
  const OrderDraft(
      {required this.customerId,
      required this.customerName,
      required this.itemName,
      required this.estimatedPrice,
      required this.commitmentAmount,
      this.supplierName});
  final String customerId, customerName, itemName;
  final int estimatedPrice, commitmentAmount;
  final String? supplierName;
}

class OrderRepository {
  OrderRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;
  final AppDatabase _database;
  final _uuid = const Uuid();
  Future<List<Order>> getAll() async {
    final db = await _database.database;
    final rows = await db.rawQuery(
        'SELECT o.*, c.name AS customer_name FROM orders o JOIN customers c ON c.id = o.customer_id ORDER BY o.created_at DESC');
    return rows.map(_fromRow).toList();
  }

  Future<Order?> getById(String id) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      'SELECT o.*, c.name AS customer_name FROM orders o JOIN customers c ON c.id = o.customer_id WHERE o.id = ?',
      [id],
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  Future<void> markContracted(String id) => _update(id, {
        'status': 'Akad aktif',
        'commitment_status': 'Dikonversi',
      });
  Future<void> create(OrderDraft draft, String number) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();
    await db.insert('orders', {
      'id': _uuid.v4(),
      'order_number': number,
      'customer_id': draft.customerId,
      'item_name': draft.itemName,
      'estimated_price': draft.estimatedPrice,
      'supplier_name': draft.supplierName?.trim().isEmpty ?? true
          ? null
          : draft.supplierName,
      'commitment_amount': draft.commitmentAmount,
      'commitment_status': 'Belum diterima',
      'status': 'Pemesanan',
      'created_at': now,
      'updated_at': now
    });
  }

  Future<void> receiveCommitment(Order order) => _update(order.id, {
        'commitment_status': 'Diterima',
        'commitment_received_at': DateTime.now().toIso8601String()
      });
  Future<void> markPurchased(Order order, int purchasePrice) =>
      _update(order.id, {
        'purchase_price': purchasePrice,
        'purchased_at': DateTime.now().toIso8601String(),
        'status': 'Barang dibeli'
      });
  Future<void> confirmOwnership(Order order) => _update(order.id, {
        'ownership_confirmed_at': DateTime.now().toIso8601String(),
        'status': 'Siap akad'
      });
  Future<void> cancel(Order order,
      {required String reason, required int actualLoss}) {
    final refund =
        (order.commitmentAmount - actualLoss).clamp(0, order.commitmentAmount);
    return _update(order.id, {
      'status': 'Batal',
      'cancellation_reason': reason,
      'actual_loss': actualLoss,
      'refund_amount': refund,
      'commitment_status': actualLoss == 0 ? 'Dikembalikan' : 'Dipakai kerugian'
    });
  }

  Future<void> _update(String id, Map<String, Object?> values) async {
    final db = await _database.database;
    await db.update(
        'orders', {...values, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [id]);
  }

  Order _fromRow(Map<String, Object?> row) => Order(
      id: row['id']! as String,
      number: row['order_number']! as String,
      customerId: row['customer_id']! as String,
      customerName: row['customer_name']! as String,
      itemName: row['item_name']! as String,
      estimatedPrice: row['estimated_price']! as int,
      supplierName: row['supplier_name'] as String?,
      commitmentAmount: row['commitment_amount']! as int,
      commitmentStatus: row['commitment_status']! as String,
      status: row['status']! as String,
      purchasePrice: row['purchase_price'] as int?,
      actualLoss: row['actual_loss']! as int,
      refundAmount: row['refund_amount']! as int,
      createdAt: DateTime.parse(row['created_at']! as String));
}
