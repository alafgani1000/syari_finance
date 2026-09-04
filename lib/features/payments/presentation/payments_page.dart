import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/utils/formatters.dart';
import '../../installments/data/installment_repository.dart';
import '../../installments/domain/installment.dart';
import '../data/payment_repository.dart';

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});
  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  final _installments = InstallmentRepository();
  final _payments = PaymentRepository();
  List<Installment> _open = [];
  List<PaymentRecord> _history = [];
  bool _loading = true;
  final _searchController = TextEditingController();
  String _query = '';
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final open = await _installments.getOpenInstallments();
      final history = await _payments.getHistory();
      if (!mounted) return;
      setState(() {
        _open = open;
        _history = history;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _recordPayment(Installment installment) async {
    final result = await showModalBottomSheet<_PaymentDraft>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _PaymentSheet(installment: installment));
    if (!mounted || result == null) return;
    try {
      await _payments.record(
          installment: installment,
          amount: result.amount,
          method: result.method,
          notes: result.notes);
      if (!mounted) return;
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pembayaran berhasil dicatat')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(e.toString().replaceFirst('Invalid argument(s): ', ''))));
    }
  }

  Future<void> _reversePayment(PaymentRecord payment) async {
    final result = await showModalBottomSheet<_ReversalDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ReversePaymentSheet(payment: payment),
    );
    if (!mounted || result == null) return;
    try {
      await _payments.reverse(
        payment: payment,
        reason: result.reason,
        officer: result.officer,
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pembayaran dibatalkan dengan transaksi pembalik'),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst('Invalid argument(s): ', ''),
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final filtered = _open.where((item) {
      final matchesQuery = '${item.customerName} ${item.financingNumber}'
          .toLowerCase()
          .contains(_query.toLowerCase());
      final isToday = item.dueDate.year == today.year &&
          item.dueDate.month == today.month &&
          item.dueDate.day == today.day;
      final matchesFilter = switch (_filter) {
        'today' => isToday,
        'overdue' => item.isOverdue,
        'partial' => item.paidAmount > 0,
        _ => true
      };
      return matchesQuery && matchesFilter;
    }).toList()
      ..sort((a, b) {
        final priorityA = a.isOverdue
            ? 0
            : a.paidAmount > 0
                ? 1
                : 2;
        final priorityB = b.isOverdue
            ? 0
            : b.paidAmount > 0
                ? 1
                : 2;
        return priorityA != priorityB
            ? priorityA.compareTo(priorityB)
            : a.dueDate.compareTo(b.dueDate);
      });
    final groups = <String, List<Installment>>{};
    for (final item in filtered) {
      groups
          .putIfAbsent('${item.customerName}|${item.financingNumber}', () => [])
          .add(item);
    }
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                  Text('Pembayaran',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('Catat dan pantau pembayaran angsuran',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: const Color(0xFF68736E))),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(
                        child: _Stat(
                            label: 'Tagihan terbuka',
                            value: '${_open.length}',
                            icon: Icons.receipt_long_outlined)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _Stat(
                            label: 'Sisa tagihan',
                            value: formatCurrency(_open.fold(
                                0, (sum, item) => sum + item.remaining)),
                            icon: Icons.payments_outlined))
                  ]),
                  const SizedBox(height: 20),
                  TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: 'Cari nasabah atau nomor pembiayaan',
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                  icon: const Icon(Icons.close)))),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'all', label: Text('Semua')),
                            ButtonSegment(
                                value: 'today', label: Text('Hari ini')),
                            ButtonSegment(
                                value: 'overdue', label: Text('Terlambat')),
                            ButtonSegment(
                                value: 'partial', label: Text('Sebagian'))
                          ],
                          selected: {
                            _filter
                          },
                          onSelectionChanged: (value) =>
                              setState(() => _filter = value.first))),
                  const SizedBox(height: 22),
                  Row(children: [
                    Text('Tagihan prioritas',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const Spacer(),
                    Text('${filtered.length} angsuran',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: const Color(0xFF087F5B)))
                  ]),
                  const SizedBox(height: 12),
                  if (groups.isEmpty)
                    const _Empty()
                  else
                    ...groups.entries.map((entry) => _FinancingPaymentGroup(
                        items: entry.value, onPay: _recordPayment)),
                  const SizedBox(height: 28),
                  Row(children: [
                    Text('Riwayat pembayaran',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const Spacer(),
                    Text(_history.length.toString() + ' transaksi',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: const Color(0xFF087F5B)))
                  ]),
                  const SizedBox(height: 12),
                  if (_history.isEmpty)
                    const _HistoryEmpty()
                  else
                    ..._history.map((payment) => _PaymentHistoryCard(
                        payment: payment, onReverse: _reversePayment)),
                ]),
    );
  }
}

class _FinancingPaymentGroup extends StatelessWidget {
  const _FinancingPaymentGroup({required this.items, required this.onPay});
  final List<Installment> items;
  final ValueChanged<Installment> onPay;

  @override
  Widget build(BuildContext context) {
    final first = items.first;
    final total = items.fold(0, (sum, item) => sum + item.remaining);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFD9F5E9),
          child: Text(
            first.customerName.substring(0, 1).toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF087F5B),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        title: Text(first.customerName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
          '${first.financingNumber} • ${items.length} angsuran terbuka',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: SizedBox(
          width: 98,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatCurrency(total),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              const Text('Sisa tagihan', style: TextStyle(fontSize: 11)),
            ],
          ),
        ),
        children: items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAF9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('Angsuran #${item.number}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                            ),
                            _StatusChip(status: item.status),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('Jatuh tempo ${formatDate(item.dueDate)}',
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Expanded(child: Text('Sisa tagihan')),
                            Text(formatCurrency(item.remaining),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => onPay(item),
                            icon: const Icon(Icons.payments_outlined),
                            label: const Text('Catat pembayaran'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet({required this.installment});
  final Installment installment;
  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  String _method = 'Tunai';
  @override
  void initState() {
    super.initState();
    _amount.text =
        formatCurrency(widget.installment.remaining).replaceFirst('Rp', '');
  }

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  int get _value =>
      int.tryParse(_amount.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
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
                Text('Catat Pembayaran',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                    '${widget.installment.customerName} • ${widget.installment.financingNumber}'),
                const SizedBox(height: 16),
                Card(
                    color: const Color(0xFFF0F6F3),
                    child: ListTile(
                        title: const Text('Sisa angsuran'),
                        trailing: Text(
                            formatCurrency(widget.installment.remaining),
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)))),
                const SizedBox(height: 14),
                TextFormField(
                    controller: _amount,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [_MoneyFormatter()],
                    decoration: const InputDecoration(
                        labelText: 'Nominal Pembayaran',
                        prefixText: 'Rp',
                        prefixIcon: Icon(Icons.payments_outlined)),
                    validator: (_) {
                      if (_value <= 0) return 'Nominal wajib diisi';
                      if (_value > widget.installment.remaining)
                        return 'Nominal melebihi sisa angsuran';
                      return null;
                    }),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                    value: _method,
                    decoration: const InputDecoration(
                        labelText: 'Metode Pembayaran',
                        prefixIcon: Icon(Icons.account_balance_outlined)),
                    items: const [
                      DropdownMenuItem(value: 'Tunai', child: Text('Tunai')),
                      DropdownMenuItem(
                          value: 'Transfer Bank', child: Text('Transfer Bank')),
                      DropdownMenuItem(value: 'QRIS', child: Text('QRIS')),
                      DropdownMenuItem(value: 'Lainnya', child: Text('Lainnya'))
                    ],
                    onChanged: (value) => setState(() => _method = value!)),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _notes,
                    maxLines: 2,
                    decoration: const InputDecoration(
                        labelText: 'Catatan (opsional)',
                        prefixIcon: Icon(Icons.note_outlined))),
                const SizedBox(height: 20),
                SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                        onPressed: () {
                          if (_formKey.currentState!.validate())
                            Navigator.pop(
                                context,
                                _PaymentDraft(
                                    _value, _method, _notes.text.trim()));
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Simpan Pembayaran')))
              ]))));
}

class _PaymentDraft {
  const _PaymentDraft(this.amount, this.method, this.notes);
  final int amount;
  final String method;
  final String notes;
}

class _ReversalDraft {
  const _ReversalDraft({required this.reason, required this.officer});

  final String reason;
  final String officer;
}

class _ReversePaymentSheet extends StatefulWidget {
  const _ReversePaymentSheet({required this.payment});

  final PaymentRecord payment;

  @override
  State<_ReversePaymentSheet> createState() => _ReversePaymentSheetState();
}

class _ReversePaymentSheetState extends State<_ReversePaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();
  final _officer = TextEditingController(text: 'Admin');

  @override
  void dispose() {
    _reason.dispose();
    _officer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Batalkan Pembayaran',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.payment.customerName +
                      ' • ' +
                      widget.payment.financingNumber,
                ),
                const SizedBox(height: 16),
                Card(
                  color: const Color(0xFFFFF4E5),
                  child: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'Pembayaran awal tidak dihapus. Aplikasi akan membuat transaksi pembalik dan mengembalikan sisa tagihan.',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _AuditLine(
                  label: 'Nominal dibatalkan',
                  value: formatCurrency(widget.payment.amount),
                ),
                _AuditLine(
                  label: 'Angsuran',
                  value: '#' + widget.payment.installmentNumber.toString(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _reason,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Alasan pembatalan',
                    hintText: 'Contoh: nominal salah input',
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Alasan pembatalan wajib diisi'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _officer,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nama petugas',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Nama petugas wajib diisi'
                      : null,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFB42318),
                    ),
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        Navigator.pop(
                          context,
                          _ReversalDraft(
                            reason: _reason.text.trim(),
                            officer: _officer.text.trim(),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.undo),
                    label: const Text('Konfirmasi pembatalan'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _AuditLine extends StatelessWidget {
  const _AuditLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

class _PaymentHistoryCard extends StatelessWidget {
  const _PaymentHistoryCard({required this.payment, required this.onReverse});

  final PaymentRecord payment;
  final ValueChanged<PaymentRecord> onReverse;

  @override
  Widget build(BuildContext context) {
    final amountText =
        (payment.amount < 0 ? '-' : '') + formatCurrency(payment.amount.abs());
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    payment.customerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 8),
                _PaymentRecordStatus(status: payment.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              payment.financingNumber +
                  ' • Angsuran #' +
                  payment.installmentNumber.toString(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    formatDateTime(payment.paymentDate) +
                        ' • ' +
                        payment.paymentMethod,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Text(
                  amountText,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: payment.amount < 0
                        ? const Color(0xFFB42318)
                        : const Color(0xFF087F5B),
                  ),
                ),
              ],
            ),
            if (payment.isVoided) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1EF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Alasan: ' +
                      (payment.voidReason ?? '-') +
                      '\nPetugas: ' +
                      (payment.voidedBy ?? '-') +
                      '\nDibatalkan: ' +
                      (payment.voidedAt == null
                          ? '-'
                          : formatDateTime(payment.voidedAt!)),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
            if (payment.canReverse) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => onReverse(payment),
                  icon: const Icon(Icons.undo),
                  label: const Text('Batalkan pembayaran'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PaymentRecordStatus extends StatelessWidget {
  const _PaymentRecordStatus({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final background = switch (status) {
      'Dibatalkan' => const Color(0xFFFFE6E1),
      'Pembalik' => const Color(0xFFFFF4D9),
      _ => const Color(0xFFEAF5F0),
    };
    final foreground = switch (status) {
      'Dibatalkan' => const Color(0xFFB42318),
      'Pembalik' => const Color(0xFF8A5A00),
      _ => const Color(0xFF087F5B),
    };
    final label = switch (status) {
      'Dibatalkan' => 'Dibatalkan',
      'Pembalik' => 'Pembalik',
      _ => 'Tercatat',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _HistoryEmpty extends StatelessWidget {
  const _HistoryEmpty();

  @override
  Widget build(BuildContext context) => const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Belum ada pembayaran yang tercatat.',
            textAlign: TextAlign.center,
          ),
        ),
      );
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

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.icon});
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
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(value,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(label, style: Theme.of(context).textTheme.bodySmall)
                ]))
          ])));
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) => Chip(
      label: Text(status),
      backgroundColor: status == 'Terlambat'
          ? const Color(0xFFFFE6E1)
          : const Color(0xFFEAF5F0),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact);
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => const Card(
      child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(children: [
            Icon(Icons.task_alt_outlined, size: 42, color: Color(0xFF087F5B)),
            SizedBox(height: 12),
            Text('Tidak ada tagihan terbuka',
                style: TextStyle(fontWeight: FontWeight.w800)),
            SizedBox(height: 4),
            Text('Semua angsuran telah lunas atau belum ada pembiayaan.',
                textAlign: TextAlign.center)
          ])));
}
