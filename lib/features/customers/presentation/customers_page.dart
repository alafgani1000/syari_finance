import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/utils/formatters.dart';
import '../data/customer_repository.dart';

class Customer {
  Customer(
      {required this.name,
      required this.phone,
      this.nik = '',
      this.income = 0});
  final String name;
  final String phone;
  final String nik;
  final int income;
}

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});
  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final _searchController = TextEditingController();
  final _customers = <Customer>[];
  final _repository = CustomerRepository();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    final items = await _repository.getAll();
    if (mounted)
      setState(() {
        _customers
          ..clear()
          ..addAll(items);
      });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showCustomerForm() async {
    final customer = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _CustomerFormSheet(),
    );
    if (!mounted || customer == null) return;
    try {
      await _repository.save(customer);
      if (!mounted) return;
      await _loadCustomers();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nasabah berhasil disimpan')));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal menyimpan nasabah')));
    }
  }

  Future<void> _showCustomerDetail(Customer customer) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF8FAF9),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFFD9F5E9),
                      child: Text(customer.name.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                              fontSize: 20,
                              color: Color(0xFF087F5B),
                              fontWeight: FontWeight.w800))),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(customer.name,
                            style: Theme.of(sheetContext)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text('Profil nasabah',
                            style: Theme.of(sheetContext)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: const Color(0xFF68736E)))
                      ])),
                  IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close)),
                ]),
                const SizedBox(height: 22),
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(children: [
                          _DetailRow(
                              icon: Icons.phone_outlined,
                              label: 'Nomor HP',
                              value: customer.phone),
                          if (customer.nik.isNotEmpty)
                            _DetailRow(
                                icon: Icons.badge_outlined,
                                label: 'NIK',
                                value: customer.nik),
                          _DetailRow(
                              icon: Icons.payments_outlined,
                              label: 'Penghasilan bulanan',
                              value: customer.income == 0
                                  ? 'Belum diisi'
                                  : formatCurrency(customer.income)),
                        ]))),
                const SizedBox(height: 14),
                SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close),
                        label: const Text('Tutup'))),
              ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _customers
        .where((customer) =>
            '${customer.name} ${customer.phone} ${customer.nik}'
                .toLowerCase()
                .contains(_query.toLowerCase()))
        .toList();
    return Scaffold(
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Nasabah',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Kelola data nasabah pembiayaan',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: const Color(0xFF68736E))),
        const SizedBox(height: 20),
        TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Cari nama, NIK, atau nomor HP')),
        const SizedBox(height: 24),
        if (visible.isEmpty)
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(children: [
                    Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                            color: const Color(0xFFEAF5F0),
                            borderRadius: BorderRadius.circular(20)),
                        child: const Icon(Icons.people_outline,
                            size: 32, color: Color(0xFF087F5B))),
                    const SizedBox(height: 16),
                    const Text('Belum ada nasabah',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 6),
                    const Text(
                        'Tambahkan nasabah pertama untuk mulai mengelola pembiayaan.',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                        onPressed: _showCustomerForm,
                        icon: const Icon(Icons.add),
                        label: const Text('Tambah Nasabah'))
                  ])))
        else
          ...visible.map((customer) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                  leading: CircleAvatar(
                      backgroundColor: const Color(0xFFD9F5E9),
                      child: Text(customer.name.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                              color: Color(0xFF087F5B),
                              fontWeight: FontWeight.bold))),
                  title: Text(customer.name,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(customer.phone),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showCustomerDetail(customer)))),
      ]),
      floatingActionButton: _customers.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showCustomerForm,
              icon: const Icon(Icons.add),
              label: const Text('Tambah'))
          : null,
    );
  }
}

class _CustomerFormSheet extends StatefulWidget {
  const _CustomerFormSheet();
  @override
  State<_CustomerFormSheet> createState() => _CustomerFormSheetState();
}

class _CustomerFormSheetState extends State<_CustomerFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _nik = TextEditingController();
  final _income = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _nik.dispose();
    _income.dispose();
    super.dispose();
  }

  int _parseIncome() =>
      int.tryParse(_income.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;

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
                  Text('Tambah Nasabah',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 18),
                  TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(
                          labelText: 'Nama Lengkap',
                          prefixIcon: Icon(Icons.person_outline)),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Nama wajib diisi'
                              : null),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                          labelText: 'Nomor HP',
                          prefixIcon: Icon(Icons.phone_outlined)),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Nomor HP wajib diisi'
                              : null),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: _nik,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'NIK (opsional)',
                          prefixIcon: Icon(Icons.badge_outlined))),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: _income,
                      keyboardType: TextInputType.number,
                      inputFormatters: const [_ThousandsSeparatorFormatter()],
                      decoration: const InputDecoration(
                          labelText: 'Penghasilan Bulanan',
                          hintText: 'Contoh: 5.000.000',
                          prefixIcon: Icon(Icons.payments_outlined)),
                      validator: (value) => value != null &&
                              value.trim().isNotEmpty &&
                              int.tryParse(value
                                      .replaceAll('.', '')
                                      .replaceAll(',', '')) ==
                                  null
                          ? 'Masukkan angka yang valid'
                          : null),
                  const SizedBox(height: 20),
                  SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                          onPressed: () {
                            if (_formKey.currentState!.validate())
                              Navigator.pop(
                                  context,
                                  Customer(
                                      name: _name.text.trim(),
                                      phone: _phone.text.trim(),
                                      nik: _nik.text.trim(),
                                      income: _parseIncome()));
                          },
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Simpan Nasabah'))),
                ]))),
      );
}

class _ThousandsSeparatorFormatter extends TextInputFormatter {
  const _ThousandsSeparatorFormatter();
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

class _DetailRow extends StatelessWidget {
  const _DetailRow(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: const Color(0xFF087F5B)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: const Color(0xFF68736E))),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600))
        ]))
      ]));
}
