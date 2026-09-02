import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../domain/financing.dart';
import '../domain/murabahah_calculator.dart';
import '../../../core/utils/formatters.dart';
import '../data/financing_repository.dart';
import '../../customers/data/customer_repository.dart';
import '../../orders/data/order_repository.dart';
import '../../orders/domain/order.dart';

class FinancingsPage extends StatefulWidget {
  const FinancingsPage({this.orderId, super.key});
  final String? orderId;
  @override
  State<FinancingsPage> createState() => _FinancingsPageState();
}

class _FinancingsPageState extends State<FinancingsPage> {
  final _financings = <Financing>[];
  final _repository = FinancingRepository();
  final _customerRepository = CustomerRepository();
  final _orderRepository = OrderRepository();
  bool _loading = true;
  String _filter = 'all';
  String _query = '';
  final _searchController = TextEditingController();
  int _sequence = 1;

  @override
  void initState() {
    super.initState();
    _loadFinancings();
    if (widget.orderId != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _openOrder(widget.orderId!));
    }
  }

  Future<void> _loadFinancings() async {
    try {
      final items = await _repository.getAll();
      if (!mounted) return;
      setState(() {
        _financings
          ..clear()
          ..addAll(items);
        _loading = false;
        _sequence = items.length + 1;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openOrder(String orderId) async {
    final order = await _orderRepository.getById(orderId);
    if (!mounted || order == null) return;
    if (!order.isReadyForContract) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pesanan belum siap untuk akad')),
      );
      return;
    }
    await _showFinancingForm(order);
  }

  Future<void> _showFinancingForm([Order? order]) async {
    final customers = await _customerRepository.getChoices();
    if (!mounted) return;
    if (customers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tambahkan nasabah terlebih dahulu')));
      return;
    }
    final result = await showModalBottomSheet<Financing>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _FinancingFormSheet(
            number:
                'MRB-${DateTime.now().year}-${_sequence.toString().padLeft(6, '0')}',
            customers: customers,
            order: order));
    if (!mounted || result == null) return;
    try {
      await _repository.save(result);
      if (!mounted) return;
      setState(() {
        _financings.insert(0, result);
        _sequence++;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pembiayaan berhasil disimpan')));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal menyimpan pembiayaan')));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _financings
        .where((item) =>
            ('${item.number} ${item.customerName} ${item.itemName}')
                .toLowerCase()
                .contains(_query.toLowerCase()))
        .toList();
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text('Pembiayaan',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Kelola pembiayaan murabahah dengan mudah',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: const Color(0xFF68736E))),
                const SizedBox(height: 20),
                TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: 'Cari nomor, nasabah, atau barang',
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                                icon: const Icon(Icons.close)))),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'all', label: Text('Semua')),
                      ButtonSegment(value: 'active', label: Text('Aktif')),
                      ButtonSegment(value: 'paid', label: Text('Lunas'))
                    ],
                    selected: {
                      _filter
                    },
                    onSelectionChanged: (value) =>
                        setState(() => _filter = value.first)),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                      child: _MiniStat(
                          label: 'Total',
                          value: '${_financings.length}',
                          icon: Icons.receipt_long_outlined)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _MiniStat(
                          label: 'Outstanding',
                          value: formatCurrency(_financings.fold(0,
                              (sum, item) => sum + item.calculation.salePrice)),
                          icon: Icons.account_balance_wallet_outlined))
                ]),
                const SizedBox(height: 28),
                if (visible.isEmpty)
                  const _FinancingEmptyState()
                else
                  ...visible.map((item) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                          leading: CircleAvatar(
                              backgroundColor: Color(0xFFEAF5F0),
                              child: Icon(Icons.account_balance_wallet_outlined,
                                  color: Color(0xFF087F5B))),
                          title: Text(item.customerName,
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(
                              '${item.number} • `${item.itemName}\n`${formatCurrency(item.calculation.installment)} / bulan'),
                          isThreeLine: true,
                          trailing: const Chip(label: Text('Aktif'))))),
              ],
            ),
    );
  }
}

class _FinancingEmptyState extends StatelessWidget {
  const _FinancingEmptyState();
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(children: [
            Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                    color: const Color(0xFFEAF5F0),
                    borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.account_balance_wallet_outlined,
                    size: 32, color: Color(0xFF087F5B))),
            const SizedBox(height: 16),
            const Text('Belum ada pembiayaan',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 6),
            const Text(
                'Pembiayaan baru hanya dapat dibuat dari pesanan yang sudah berstatus Siap akad.',
                textAlign: TextAlign.center)
          ])));
}

class _FinancingFormSheet extends StatefulWidget {
  const _FinancingFormSheet(
      {required this.number, required this.customers, this.order});
  final String number;
  final List<CustomerChoice> customers;
  final Order? order;
  @override
  State<_FinancingFormSheet> createState() => _FinancingFormSheetState();
}

class _FinancingFormSheetState extends State<_FinancingFormSheet> {
  final _formKey = GlobalKey<FormState>();
  CustomerChoice? _selectedCustomer;
  final _customerDisplay = TextEditingController();
  final _item = TextEditingController();
  final _price = TextEditingController();
  final _dp = TextEditingController(text: '0');
  final _margin = TextEditingController(text: '0');
  final _tenor = TextEditingController(text: '12');
  final _calculator = MurabahahCalculator();
  FinancingCalculation? _calculation;

  @override
  void initState() {
    super.initState();
    for (final c in [_price, _dp, _margin, _tenor]) c.addListener(_calculate);
    final order = widget.order;
    if (order != null) {
      for (final customer in widget.customers) {
        if (customer.id == order.customerId) {
          _selectedCustomer = customer;
          break;
        }
      }
      _customerDisplay.text = '';
      _item.text = order.itemName;
      _price.text = (order.purchasePrice ?? order.estimatedPrice).toString();
      _dp.text = order.commitmentAmount.toString();
      _calculate();
    }
  }

  @override
  void dispose() {
    for (final c in [_customerDisplay, _item, _price, _dp, _margin, _tenor])
      c.dispose();
    super.dispose();
  }

  int _number(TextEditingController c) =>
      int.tryParse(c.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
  void _calculate() {
    final price = _number(_price);
    final dp = _number(_dp);
    final margin = _number(_margin);
    final tenor = _number(_tenor);
    if (price > 0 && tenor > 0 && dp <= price) {
      final value = _calculator.calculate(
          itemPrice: price, downPayment: dp, margin: margin, tenor: tenor);
      if (mounted) setState(() => _calculation = value);
    } else if (mounted) setState(() => _calculation = null);
  }

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
                Text('Buat Pembiayaan Murabahah',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(widget.number,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 18),
                TextFormField(
                    controller: _customerDisplay,
                    readOnly: true,
                    onTap: () async {
                      if (widget.order != null) return;
                      final selected =
                          await showModalBottomSheet<CustomerChoice>(
                              context: context,
                              isScrollControlled: true,
                              showDragHandle: true,
                              builder: (_) => _CustomerPickerSheet(
                                  customers: widget.customers));
                      if (!mounted || selected == null) return;
                      setState(() {
                        _selectedCustomer = selected;
                        _customerDisplay.text =
                            '${selected.name} • ${selected.phone}';
                      });
                    },
                    decoration: const InputDecoration(
                        labelText: 'Nasabah',
                        hintText: 'Pilih nasabah',
                        prefixIcon: Icon(Icons.person_outline),
                        suffixIcon: Icon(Icons.search)),
                    validator: (_) =>
                        _selectedCustomer == null ? 'Pilih nasabah' : null),
                const SizedBox(height: 12),
                _field(_item, 'Nama Barang', Icons.inventory_2_outlined,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Nama barang wajib diisi'
                        : null),
                const SizedBox(height: 12),
                _field(_price, 'Harga Barang', Icons.sell_outlined,
                    money: true,
                    hint: 'Contoh: 25.000.000',
                    validator: (_) => _number(_price) <= 0
                        ? 'Harga barang wajib diisi'
                        : null),
                const SizedBox(height: 12),
                _field(_dp, 'Uang Muka / DP', Icons.payments_outlined,
                    money: true),
                const SizedBox(height: 12),
                _field(_margin, 'Margin', Icons.trending_up_outlined,
                    money: true),
                const SizedBox(height: 12),
                _field(_tenor, 'Tenor (bulan)', Icons.calendar_month_outlined,
                    validator: (_) => _number(_tenor) <= 0
                        ? 'Tenor harus lebih dari 0'
                        : null),
                const SizedBox(height: 18),
                if (_calculation != null)
                  Card(
                      color: const Color(0xFFF0F6F3),
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Ringkasan pembiayaan',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w800)),
                                const SizedBox(height: 12),
                                _SummaryRow(
                                    label: 'Pokok pembiayaan',
                                    value: formatCurrency(
                                        _calculation!.principal)),
                                _SummaryRow(
                                    label: 'Harga jual',
                                    value: formatCurrency(
                                        _calculation!.salePrice)),
                                _SummaryRow(
                                    label: 'Angsuran / bulan',
                                    value: formatCurrency(
                                        _calculation!.installment))
                              ]))),
                const SizedBox(height: 18),
                SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                        onPressed: () {
                          if (_formKey.currentState!.validate() &&
                              _calculation != null)
                            Navigator.pop(
                                context,
                                Financing(
                                    number: widget.number,
                                    orderId: widget.order?.id,
                                    customerId: _selectedCustomer!.id,
                                    customerName: _selectedCustomer!.name,
                                    itemName: _item.text.trim(),
                                    calculation: _calculation!,
                                    itemPrice: _number(_price),
                                    downPayment: _number(_dp),
                                    margin: _number(_margin),
                                    tenor: _number(_tenor),
                                    startDate: DateTime.now()));
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Simpan Pembiayaan'))),
              ]))));

  Widget _field(TextEditingController controller, String label, IconData icon,
          {bool money = false,
          String? hint,
          String? Function(String?)? validator}) =>
      TextFormField(
          controller: controller,
          keyboardType: money ? TextInputType.number : TextInputType.text,
          inputFormatters: money ? const [_MoneyFormatter()] : null,
          decoration: InputDecoration(
              labelText: label, hintText: hint, prefixIcon: Icon(icon)),
          validator: validator);
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700))
      ]));
}

class _MoneyFormatter extends TextInputFormatter {
  const _MoneyFormatter();
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final grouped = digits.replaceAllMapped(
        RegExp(r'(?<=\d)(?=(\d{3})+(?!\d))'), (_) => '.');
    return TextEditingValue(
        text: grouped,
        selection: TextSelection.collapsed(offset: grouped.length));
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(
      {required this.label, required this.value, required this.icon});
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
      color: const Color(0xFFF0F6F3),
      child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Icon(icon, size: 20, color: const Color(0xFF087F5B)),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(label, style: Theme.of(context).textTheme.bodySmall)
            ])
          ])));
}

class _CustomerPickerSheet extends StatefulWidget {
  const _CustomerPickerSheet({required this.customers});
  final List<CustomerChoice> customers;
  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final items = widget.customers
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
                              hintText: 'Cari nasabah')),
                      const SizedBox(height: 12),
                      Expanded(
                          child: items.isEmpty
                              ? const Center(
                                  child: Text('Nasabah tidak ditemukan'))
                              : ListView.separated(
                                  itemCount: items.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (_, index) {
                                    final customer = items[index];
                                    return ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                vertical: 6),
                                        leading: CircleAvatar(
                                            backgroundColor:
                                                const Color(0xFFD9F5E9),
                                            child: Text(
                                                customer.name
                                                    .substring(0, 1)
                                                    .toUpperCase(),
                                                style: const TextStyle(
                                                    color: Color(0xFF087F5B),
                                                    fontWeight:
                                                        FontWeight.w800))),
                                        title: Text(customer.name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700)),
                                        subtitle: Text(customer.phone),
                                        trailing:
                                            const Icon(Icons.chevron_right),
                                        onTap: () =>
                                            Navigator.pop(context, customer));
                                  }))
                    ]))));
  }
}
