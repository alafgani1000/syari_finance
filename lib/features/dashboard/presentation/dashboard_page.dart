import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/reminders/due_reminder_service.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/data/auth_controller.dart';
import '../data/dashboard_repository.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});
  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  final _repository = DashboardRepository();
  late Future<DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.load();
    unawaited(_syncReminders());
  }

  Future<void> _syncReminders() async {
    try {
      final reminders = DueReminderService();
      if (await reminders.isPermissionGranted()) {
        await reminders.scheduleUpcoming();
      }
    } catch (_) {
      // Pengingat tidak boleh menghalangi dashboard bila izin Android belum ada.
    }
  }

  Future<void> _refresh() async {
    final future = _repository.load();
    unawaited(_syncReminders());
    setState(() {
      _future = future;
    });
    try {
      await future;
    } catch (_) {
      // FutureBuilder menampilkan tombol coba lagi tanpa error global.
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<DashboardData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: FilledButton(
                    onPressed: _refresh, child: const Text('Coba lagi')));
          }
          final data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Row(children: [
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text('Selamat datang 👋',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text('Ringkasan pembiayaan hari ini',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: const Color(0xFF68736E)))
                        ])),
                    IconButton(
                        onPressed: _refresh, icon: const Icon(Icons.refresh))
                  ]),
                  const SizedBox(height: 22),
                  GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.28,
                      children: [
                        _Stat(
                            label: 'Total Nasabah',
                            value: '${data.customerCount}',
                            icon: Icons.people_outline,
                            tint: const Color(0xFFE3F5EE)),
                        _Stat(
                            label: 'Pembiayaan Aktif',
                            value: '${data.activeFinancingCount}',
                            icon: Icons.account_balance_wallet_outlined,
                            tint: const Color(0xFFE8F0FF)),
                        _Stat(
                            label: 'Total Piutang',
                            value: formatCurrency(data.outstanding),
                            icon: Icons.payments_outlined,
                            tint: const Color(0xFFFFF1D8)),
                        _Stat(
                            label: 'Terlambat',
                            value: '${data.overdueCount}',
                            icon: Icons.warning_amber_outlined,
                            tint: const Color(0xFFFFE6E1)),
                      ]),
                  if (ref.watch(authControllerProvider).isAdmin) ...[
                    const SizedBox(height: 24),
                    const _Title(
                      title: 'Ringkasan bisnis',
                      action: 'Lihat laporan',
                    ),
                    const SizedBox(height: 10),
                    _BusinessMetric(
                      label: 'Pencairan pembiayaan',
                      value: formatCurrency(data.totalDisbursed),
                      icon: Icons.account_balance_outlined,
                      description: 'Total pokok akad aktif dan lunas',
                    ),
                    const SizedBox(height: 10),
                    _BusinessMetric(
                      label: 'Potensi margin akad',
                      value: formatCurrency(data.plannedMargin),
                      icon: Icons.trending_up_outlined,
                      description: 'Keuntungan yang tercantum pada akad',
                    ),
                    const SizedBox(height: 10),
                    _BusinessMetric(
                      label: 'Penerimaan bulan ini',
                      value: formatCurrency(data.collectedThisMonth),
                      icon: Icons.savings_outlined,
                      description: 'Pembayaran tercatat pada bulan berjalan',
                    ),
                    const SizedBox(height: 10),
                    _BusinessMetric(
                      label: 'Nilai tunggakan',
                      value: formatCurrency(data.overdueAmount),
                      icon: Icons.warning_amber_outlined,
                      description:
                          '${data.overdueCount} angsuran melewati jatuh tempo',
                      warning: true,
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/reports'),
                      icon: const Icon(Icons.assessment_outlined),
                      label: const Text('Buka laporan & ekspor'),
                    ),
                    const SizedBox(height: 28),
                  ],
                  _Title(
                      title: 'Angsuran jatuh tempo hari ini',
                      action: '${data.dueTodayCount} tagihan'),
                  const SizedBox(height: 12),
                  if (data.dueToday.isEmpty)
                    const _Empty(
                        icon: Icons.event_available_outlined,
                        title: 'Belum ada angsuran jatuh tempo',
                        subtitle: 'Data akan tampil setelah pembiayaan dibuat')
                  else
                    ...data.dueToday.map((item) => Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                            leading: const CircleAvatar(
                                backgroundColor: Color(0xFFFFF1D8),
                                child: Icon(Icons.calendar_month_outlined,
                                    color: Color(0xFFB77908))),
                            title: Text(item.customerName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            subtitle: Text(
                                '${item.financingNumber} • Angsuran #${item.number}'),
                            trailing: Text(formatCurrency(item.amount),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800))))),
                  const SizedBox(height: 28),
                  const _Title(title: 'Pembayaran terbaru'),
                  const SizedBox(height: 12),
                  if (data.recentPayments.isEmpty)
                    const _Empty(
                        icon: Icons.receipt_long_outlined,
                        title: 'Belum ada pembayaran',
                        subtitle: 'Transaksi pembayaran akan muncul di sini')
                  else
                    ...data.recentPayments.map((item) => Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                            leading: const CircleAvatar(
                                backgroundColor: Color(0xFFD9F5E9),
                                child: Icon(Icons.payments_outlined,
                                    color: Color(0xFF087F5B))),
                            title: Text(item.customerName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            subtitle: Text(formatDate(item.date)),
                            trailing: Text(formatCurrency(item.amount),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800))))),
                ]),
          );
        },
      );
}

class _Stat extends StatelessWidget {
  const _Stat(
      {required this.label,
      required this.value,
      required this.icon,
      required this.tint});
  final String label, value;
  final IconData icon;
  final Color tint;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                        color: tint, borderRadius: BorderRadius.circular(10)),
                    child:
                        Icon(icon, size: 19, color: const Color(0xFF087F5B))),
                Text(value,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                Text(label,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: const Color(0xFF68736E)))
              ])));
}

class _Title extends StatelessWidget {
  const _Title({required this.title, this.action = ''});
  final String title, action;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800))),
        if (action.isNotEmpty)
          Text(action,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: const Color(0xFF087F5B)))
      ]);
}

class _Empty extends StatelessWidget {
  const _Empty(
      {required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Icon(icon, size: 42, color: const Color(0xFF087F5B)),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall)
          ])));
}

class _BusinessMetric extends StatelessWidget {
  const _BusinessMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.description,
    this.warning = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final String description;
  final bool warning;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          leading: CircleAvatar(
            backgroundColor:
                warning ? const Color(0xFFFFE6E1) : const Color(0xFFE3F5EE),
            child: Icon(
              icon,
              color:
                  warning ? const Color(0xFFB42318) : const Color(0xFF087F5B),
            ),
          ),
          title:
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(description),
          trailing: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 118),
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: warning ? const Color(0xFFB42318) : null,
              ),
            ),
          ),
        ),
      );
}
