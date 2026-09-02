import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../customers/data/customer_repository.dart';
import '../data/order_repository.dart';
import '../domain/order.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final _repository = OrderRepository();
  final _customerRepository = CustomerRepository();
  final _orders = <Order>[];
  bool _loading = true;
  int _sequence = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await _repository.getAll();
      if (!mounted) return;
      setState(() {
        _orders
          ..clear()
          ..addAll(items);
        _sequence = items.length + 1;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createOrder() async {
    final customers = await _customerRepository.getChoices();
    if (!mounted) return;
    if (customers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tambahkan nasabah terlebih dahulu')),
      );
      return;
    }
    final draft = await showModalBottomSheet<OrderDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _OrderFormSheet(customers: customers),
    );
    if (!mounted || draft == null) return;
    await _runAction(() async {
      await _repository.create(
        draft,
        'PSN-${DateTime.now().year}-${_sequence.toString().padLeft(6, '0')}',
      );
    }, 'Pemesanan berhasil dibuat');
  }

  Future<void> _runAction(
      Future<void> Function() action, String success) async {
    try {
      await action();
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(success)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proses gagal disimpan')),
      );
    }
  }

  Future<void> _purchase(Order order) async {
    final controller = TextEditingController(
      text: order.estimatedPrice.toString(),
    );
    final amount = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Catat pembelian barang'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: const [_MoneyFormatter()],
          decoration: const InputDecoration(
            labelText: 'Harga perolehan aktual',
            prefixText: 'Rp ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final value = _amount(controller);
              if (value > 0) Navigator.pop(dialogContext, value);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    // Dialog masih merender ketika animasi penutup berjalan.
    Future<void>.delayed(
      const Duration(milliseconds: 350),
      controller.dispose,
    );
    if (amount == null) return;
    await _runAction(
      () => _repository.markPurchased(order, amount),
      'Pembelian barang dicatat',
    );
  }

  Future<void> _cancel(Order order) async {
    final reason = TextEditingController();
    final loss = TextEditingController(text: '0');
    final values = await showDialog<(String, int)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Batalkan pemesanan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Uang kesungguhan ${formatCurrency(order.commitmentAmount)}. Hanya kerugian riil yang boleh dicatat.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reason,
              decoration: const InputDecoration(labelText: 'Alasan pembatalan'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: loss,
              keyboardType: TextInputType.number,
              inputFormatters: const [_MoneyFormatter()],
              decoration: const InputDecoration(
                labelText: 'Kerugian riil',
                prefixText: 'Rp ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Kembali'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(
              dialogContext,
              (reason.text.trim(), _amount(loss)),
            ),
            child: const Text('Konfirmasi batal'),
          ),
        ],
      ),
    );
    reason.dispose();
    loss.dispose();
    if (values == null) return;
    await _runAction(
      () => _repository.cancel(order, reason: values.$1, actualLoss: values.$2),
      'Pembatalan dan pengembalian tercatat',
    );
  }

  int _amount(TextEditingController controller) =>
      int.tryParse(controller.text.replaceAll('.', '').replaceAll(',', '')) ??
      0;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Text(
                    'Pemesanan',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Catat proses sebelum akad Murabahah dibuat',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: const Color(0xFF68736E)),
                  ),
                  const SizedBox(height: 16),
                  const _ProcessGuide(),
                  const SizedBox(height: 20),
                  if (_orders.isEmpty)
                    const _EmptyOrders()
                  else
                    ..._orders.map(
                      (order) => _OrderCard(
                        order: order,
                        onReceive: () => _runAction(
                          () => _repository.receiveCommitment(order),
                          'Uang kesungguhan diterima',
                        ),
                        onPurchase: () => _purchase(order),
                        onConfirmOwnership: () => _runAction(
                          () => _repository.confirmOwnership(order),
                          'Barang telah dikonfirmasi sebagai milik penjual',
                        ),
                        onCancel: () => _cancel(order),
                        onCreateContract: () =>
                            context.go('/financings?orderId=${order.id}'),
                      ),
                    ),
                ],
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _createOrder,
          icon: const Icon(Icons.add),
          label: const Text('Buat pesanan'),
        ),
      );
}

class _ProcessGuide extends StatelessWidget {
  const _ProcessGuide();

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFFF0F6F3),
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Text(
            '1. Pesanan  •  2. Uang kesungguhan  •  3. Barang dibeli  •  4. Kepemilikan dikonfirmasi  •  5. Akad',
            style: TextStyle(fontWeight: FontWeight.w600, height: 1.5),
          ),
        ),
      );
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.shopping_bag_outlined,
                  size: 42, color: Color(0xFF087F5B)),
              const SizedBox(height: 12),
              const Text('Belum ada pemesanan',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                'Buat pesanan sebelum membeli barang atau membuat akad.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
}

class _OrderCard extends StatelessWidget {
  const _OrderCard(
      {required this.order,
      required this.onReceive,
      required this.onPurchase,
      required this.onConfirmOwnership,
      required this.onCancel,
      required this.onCreateContract});

  final Order order;
  final VoidCallback onReceive,
      onPurchase,
      onConfirmOwnership,
      onCancel,
      onCreateContract;

  @override
  Widget build(BuildContext context) {
    final color = order.isCancelled
        ? const Color(0xFFB42318)
        : order.isReadyForContract
            ? const Color(0xFF087F5B)
            : const Color(0xFF5B6670);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                  child: Text(order.customerName,
                      style: const TextStyle(fontWeight: FontWeight.w800))),
              Chip(
                  label: Text(order.status),
                  labelStyle:
                      TextStyle(color: color, fontWeight: FontWeight.w700),
                  visualDensity: VisualDensity.compact),
            ]),
            const SizedBox(height: 4),
            Text('${order.number} • ${order.itemName}'),
            const SizedBox(height: 12),
            _OrderLine('Estimasi harga', formatCurrency(order.estimatedPrice)),
            _OrderLine('Uang kesungguhan',
                '${formatCurrency(order.commitmentAmount)} • ${order.commitmentStatus}'),
            if (order.purchasePrice != null)
              _OrderLine(
                  'Harga perolehan', formatCurrency(order.purchasePrice!)),
            if (order.isCancelled) ...[
              _OrderLine('Kerugian riil', formatCurrency(order.actualLoss)),
              _OrderLine('Dikembalikan', formatCurrency(order.refundAmount)),
            ],
            if (!order.isCancelled) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: _actionButton(),
              ),
              const SizedBox(height: 8),
              Center(
                  child: TextButton(
                      onPressed: onCancel,
                      child: const Text('Batalkan pemesanan'))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _actionButton() {
    if (order.canReceiveCommitment) {
      return OutlinedButton.icon(
          onPressed: onReceive,
          icon: const Icon(Icons.payments_outlined),
          label: const Text('Catat uang kesungguhan diterima'));
    }
    if (order.canPurchase) {
      return FilledButton.icon(
          onPressed: onPurchase,
          icon: const Icon(Icons.shopping_cart_checkout_outlined),
          label: const Text('Catat barang dibeli'));
    }
    if (order.canConfirmOwnership) {
      return FilledButton.icon(
          onPressed: onConfirmOwnership,
          icon: const Icon(Icons.verified_outlined),
          label: const Text('Konfirmasi barang milik penjual'));
    }
    if (order.isReadyForContract) {
      return FilledButton.icon(
          onPressed: onCreateContract,
          icon: const Icon(Icons.description_outlined),
          label: const Text('Buat akad / pembiayaan'));
    }
    return const SizedBox.shrink();
  }
}

class _OrderLine extends StatelessWidget {
  const _OrderLine(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(children: [
          Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600))
        ]),
      );
}

class _OrderFormSheet extends StatefulWidget {
  const _OrderFormSheet({required this.customers});
  final List<CustomerChoice> customers;
  @override
  State<_OrderFormSheet> createState() => _OrderFormSheetState();
}

class _OrderFormSheetState extends State<_OrderFormSheet> {
  final _formKey = GlobalKey<FormState>();
  CustomerChoice? _customer;
  final _customerDisplay = TextEditingController();
  final _item = TextEditingController();
  final _estimated = TextEditingController();
  final _commitment = TextEditingController();
  final _supplier = TextEditingController();
  @override
  void dispose() {
    _customerDisplay.dispose();
    _item.dispose();
    _estimated.dispose();
    _commitment.dispose();
    _supplier.dispose();
    super.dispose();
  }

  int _amount(TextEditingController c) =>
      int.tryParse(c.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: Form(
            key: _formKey,
            child: SingleChildScrollView(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Buat Pemesanan',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  const Text(
                      'Uang kesungguhan belum menjadi DP sampai akad disepakati.'),
                  const SizedBox(height: 18),
                  TextFormField(
                      controller: _customerDisplay,
                      readOnly: true,
                      onTap: () async {
                        final selected =
                            await showModalBottomSheet<CustomerChoice>(
                          context: context,
                          isScrollControlled: true,
                          showDragHandle: true,
                          builder: (_) => _OrderCustomerPickerSheet(
                            customers: widget.customers,
                          ),
                        );
                        if (!mounted || selected == null) return;
                        setState(() {
                          _customer = selected;
                          _customerDisplay.text =
                              '${selected.name} • ${selected.phone}';
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Nasabah',
                        hintText: 'Pilih nasabah',
                        prefixIcon: Icon(Icons.person_outline),
                        suffixIcon: Icon(Icons.search),
                      ),
                      validator: (_) =>
                          _customer == null ? 'Pilih nasabah' : null),
                  const SizedBox(height: 12),
                  _field(
                      _item, 'Barang yang dipesan', Icons.inventory_2_outlined,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Barang wajib diisi'
                          : null),
                  const SizedBox(height: 12),
                  _field(
                      _estimated, 'Estimasi harga barang', Icons.sell_outlined,
                      money: true,
                      validator: (_) =>
                          _amount(_estimated) <= 0 ? 'Masukkan harga' : null),
                  const SizedBox(height: 12),
                  _field(
                      _commitment, 'Uang kesungguhan', Icons.payments_outlined,
                      money: true,
                      validator: (_) => _amount(_commitment) <= 0
                          ? 'Masukkan nominal'
                          : null),
                  const SizedBox(height: 12),
                  _field(_supplier, 'Supplier / toko (opsional)',
                      Icons.storefront_outlined),
                  const SizedBox(height: 20),
                  SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                          onPressed: () {
                            if (!_formKey.currentState!.validate()) return;
                            Navigator.pop(
                                context,
                                OrderDraft(
                                    customerId: _customer!.id,
                                    customerName: _customer!.name,
                                    itemName: _item.text.trim(),
                                    estimatedPrice: _amount(_estimated),
                                    commitmentAmount: _amount(_commitment),
                                    supplierName: _supplier.text.trim()));
                          },
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Simpan pemesanan'))),
                ]))),
      );
  Widget _field(TextEditingController c, String label, IconData icon,
          {bool money = false, String? Function(String?)? validator}) =>
      TextFormField(
          controller: c,
          keyboardType: money ? TextInputType.number : TextInputType.text,
          inputFormatters: money ? const [_MoneyFormatter()] : null,
          decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
          validator: validator);
}

class _OrderCustomerPickerSheet extends StatefulWidget {
  const _OrderCustomerPickerSheet({required this.customers});
  final List<CustomerChoice> customers;

  @override
  State<_OrderCustomerPickerSheet> createState() =>
      _OrderCustomerPickerSheetState();
}

class _OrderCustomerPickerSheetState extends State<_OrderCustomerPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final customers = widget.customers
        .where((item) => '${item.name} ${item.phone}'
            .toLowerCase()
            .contains(_query.toLowerCase()))
        .toList();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pilih Nasabah',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Cari berdasarkan nama atau nomor HP',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: const Color(0xFF68736E))),
              const SizedBox(height: 16),
              TextField(
                autofocus: true,
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Cari nasabah',
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: customers.isEmpty
                    ? const Center(child: Text('Nasabah tidak ditemukan'))
                    : ListView.separated(
                        itemCount: customers.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, index) {
                          final customer = customers[index];
                          return ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 6),
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFD9F5E9),
                              child: Text(
                                customer.name.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFF087F5B),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            title: Text(customer.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            subtitle: Text(customer.phone),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.pop(context, customer),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoneyFormatter extends TextInputFormatter {
  const _MoneyFormatter();
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final text = digits.replaceAllMapped(
        RegExp(r'(?<=\d)(?=(\d{3})+(?!\d))'), (_) => '.');
    return TextEditingValue(
        text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
