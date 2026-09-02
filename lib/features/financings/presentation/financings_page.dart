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
  final _searchController = TextEditingController();

  bool _loading = true;
  String _filter = 'all';
  String _query = '';
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
        const SnackBar(content: Text('Tambahkan nasabah terlebih dahulu')),
      );
      return;
    }
    final result = await showModalBottomSheet<Financing>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FinancingFormSheet(
        number: 'MRB-' +
            DateTime.now().year.toString() +
            '-' +
            _sequence.toString().padLeft(6, '0'),
        customers: customers,
        order: order,
      ),
    );
    if (!mounted || result == null) return;
    try {
      await _repository.save(result);
      await _loadFinancings();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pembiayaan berhasil disimpan')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan pembiayaan')),
        );
      }
    }
  }

  void _showDetails(Financing financing) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FinancingDetailSheet(financing: financing),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = _query.trim().toLowerCase();
    final visible = _financings.where((item) {
      final searchable =
          [item.number, item.customerName, item.itemName].join(' ');
      final matchesQuery = searchable.toLowerCase().contains(normalizedQuery);
      final matchesStatus = switch (_filter) {
        'active' => !item.isPaid,
        'paid' => item.isPaid,
        _ => true,
      };
      return matchesQuery && matchesStatus;
    }).toList();
    final outstanding =
        _financings.fold<int>(0, (sum, item) => sum + item.outstanding);
    final activeCount = _financings.where((item) => !item.isPaid).length;

    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadFinancings,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Text(
                    'Pembiayaan',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pantau akad, angsuran, dan sisa tagihan',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF68736E),
                        ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _MiniStat(
                          label: 'Pembiayaan aktif',
                          value: activeCount.toString(),
                          icon: Icons.receipt_long_outlined,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MiniStat(
                          label: 'Sisa tagihan',
                          value: formatCurrency(outstanding),
                          icon: Icons.account_balance_wallet_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Cari nomor, nasabah, atau barang',
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Hapus pencarian',
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: 'all', label: Text('Semua')),
                        ButtonSegment(value: 'active', label: Text('Aktif')),
                        ButtonSegment(value: 'paid', label: Text('Lunas')),
                      ],
                      selected: {_filter},
                      onSelectionChanged: (value) =>
                          setState(() => _filter = value.first),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Daftar pembiayaan',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ),
                      Text(
                        visible.length.toString() + ' data',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF68736E),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (visible.isEmpty)
                    _FinancingEmptyState(
                      hasFinancings: _financings.isNotEmpty,
                    )
                  else
                    ...visible.map(
                      (item) => _FinancingCard(
                        financing: item,
                        onTap: () => _showDetails(item),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _FinancingCard extends StatelessWidget {
  const _FinancingCard({required this.financing, required this.onTap});

  final Financing financing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final total = financing.calculation.salePrice;
    final remaining = financing.outstanding.clamp(0, total).toInt();
    final progress =
        total <= 0 ? 0.0 : ((total - remaining) / total).clamp(0.0, 1.0);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF5F0),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: Color(0xFF087F5B),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          financing.customerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          financing.number,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF68736E),
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(isPaid: financing.isPaid),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    size: 18,
                    color: Color(0xFF68736E),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      financing.itemName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _CardMetric(
                      label: 'Angsuran / bulan',
                      value: formatCurrency(
                        financing.calculation.installment,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CardMetric(
                      label: 'Tenor',
                      value: financing.tenor.toString() + ' bulan',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    financing.isPaid ? 'Pelunasan' : 'Progres pembayaran',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF68736E),
                        ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      financing.isPaid
                          ? 'Lunas'
                          : 'Sisa ' + formatCurrency(remaining),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF27322E),
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: financing.isPaid ? 1 : progress,
                  minHeight: 7,
                  backgroundColor: const Color(0xFFE4ECE8),
                  color: const Color(0xFF087F5B),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Lihat detail',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF087F5B),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: Color(0xFF087F5B),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardMetric extends StatelessWidget {
  const _CardMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF68736E),
                ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isPaid});

  final bool isPaid;

  @override
  Widget build(BuildContext context) {
    final background =
        isPaid ? const Color(0xFFE5F7ED) : const Color(0xFFFFF4D9);
    final foreground =
        isPaid ? const Color(0xFF087F5B) : const Color(0xFF8A5A00);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isPaid ? 'Lunas' : 'Aktif',
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _FinancingEmptyState extends StatelessWidget {
  const _FinancingEmptyState({required this.hasFinancings});

  final bool hasFinancings;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF5F0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 32,
                  color: Color(0xFF087F5B),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                hasFinancings
                    ? 'Pembiayaan tidak ditemukan'
                    : 'Belum ada pembiayaan',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                hasFinancings
                    ? 'Coba ubah kata pencarian atau filter status.'
                    : 'Pembiayaan baru dibuat dari pesanan yang sudah berstatus Siap akad.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF68736E),
                    ),
              ),
            ],
          ),
        ),
      );
}

class _FinancingDetailSheet extends StatelessWidget {
  const _FinancingDetailSheet({required this.financing});

  final Financing financing;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .82,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detail Pembiayaan',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          financing.number,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF68736E),
                                  ),
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(isPaid: financing.isPaid),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F6F3),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      financing.customerName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      financing.itemName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF68736E),
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _DetailRow(
                label: 'Harga barang',
                value: formatCurrency(financing.itemPrice),
              ),
              _DetailRow(
                label: 'Uang muka / DP',
                value: formatCurrency(financing.downPayment),
              ),
              _DetailRow(
                label: 'Margin',
                value: formatCurrency(financing.margin),
              ),
              _DetailRow(
                label: 'Harga jual',
                value: formatCurrency(financing.calculation.salePrice),
              ),
              _DetailRow(
                label: 'Angsuran per bulan',
                value: formatCurrency(financing.calculation.installment),
              ),
              _DetailRow(
                label: 'Tenor',
                value: financing.tenor.toString() + ' bulan',
              ),
              _DetailRow(
                label: 'Sisa tagihan',
                value: formatCurrency(financing.outstanding),
                emphasize: true,
              ),
              _DetailRow(
                label: 'Tanggal akad',
                value: formatDate(financing.startDate),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Tutup'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF68736E),
                    ),
              ),
            ),
            const SizedBox(width: 16),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: emphasize ? const Color(0xFF087F5B) : null,
                ),
              ),
            ),
          ],
        ),
      );
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
      _customerDisplay.text = _selectedCustomer == null
          ? order.customerName
          : _selectedCustomer!.name + ' • ' + _selectedCustomer!.phone;
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
  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFFF0F6F3),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDF1E8),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  size: 19,
                  color: const Color(0xFF087F5B),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF68736E),
                    ),
              ),
            ],
          ),
        ),
      );
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
