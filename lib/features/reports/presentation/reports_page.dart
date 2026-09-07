import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backup/backup_file_channel.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/data/auth_controller.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../services/report_document_service.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  final _repository = DashboardRepository();
  final _documents = ReportDocumentService();
  late Future<DashboardData> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _repository.load();
  }

  Future<void> _exportCsv(DashboardData report) async {
    File? temporaryFile;
    setState(() => _busy = true);
    try {
      temporaryFile = await _documents.createCsv(report);
      final target = await BackupFileChannel.saveFile(
        temporaryFile,
        fileName:
            'laporan-bisnis-${DateTime.now().toIso8601String().substring(0, 10)}.csv',
      );
      if (target != null) _message('Laporan CSV berhasil disimpan.');
    } catch (error) {
      _message('Ekspor CSV gagal: $error', error: true);
    } finally {
      if (temporaryFile != null && await temporaryFile.exists()) {
        await temporaryFile.delete();
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _print(DashboardData report) async {
    setState(() => _busy = true);
    try {
      await _documents.printBusinessReport(report);
    } catch (error) {
      _message('PDF belum dapat dibuat: $error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    final future = _repository.load();
    setState(() => _future = future);
    try {
      await future;
    } catch (_) {
      // FutureBuilder menampilkan pesan dan tombol coba lagi.
    }
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(text),
          backgroundColor: error ? Theme.of(context).colorScheme.error : null),
    );
  }

  @override
  Widget build(BuildContext context) => !ref
          .watch(authControllerProvider)
          .isAdmin
      ? const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Laporan hanya dapat dibuka oleh Admin.'),
          ),
        )
      : FutureBuilder<DashboardData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: FilledButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Coba lagi'),
                ),
              );
            }
            final report = snapshot.data!;
            return Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    children: [
                      Text('Laporan & Dokumen',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 6),
                      const Text(
                          'Ringkasan angka bisnis dan dokumen pembiayaan yang siap dibagikan.'),
                      const SizedBox(height: 22),
                      _MetricCard(
                          label: 'Pencairan pembiayaan',
                          value: formatCurrency(report.totalDisbursed),
                          icon: Icons.account_balance_outlined),
                      const SizedBox(height: 10),
                      _MetricCard(
                          label: 'Potensi margin akad',
                          value: formatCurrency(report.plannedMargin),
                          icon: Icons.trending_up_outlined),
                      const SizedBox(height: 10),
                      _MetricCard(
                          label: 'Nilai tunggakan',
                          value: formatCurrency(report.overdueAmount),
                          icon: Icons.warning_amber_outlined,
                          danger: true),
                      const SizedBox(height: 10),
                      _MetricCard(
                          label: 'Penerimaan bulan ini',
                          value: formatCurrency(report.collectedThisMonth),
                          icon: Icons.savings_outlined),
                      const SizedBox(height: 24),
                      Text('Ekspor ringkasan',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      Card(
                        child: Column(
                          children: [
                            ListTile(
                              leading:
                                  const Icon(Icons.picture_as_pdf_outlined),
                              title: const Text('Laporan PDF'),
                              subtitle:
                                  const Text('Siap dicetak atau dibagikan'),
                              onTap: _busy ? null : () => _print(report),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.table_view_outlined),
                              title: const Text('Laporan CSV untuk Excel'),
                              subtitle: const Text(
                                  'Pilih lokasi simpan dari Android'),
                              onTap: _busy ? null : () => _exportCsv(report),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text('Dokumen per pembiayaan',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                              'Kartu angsuran dan rincian PDF tersedia dari Detail Pembiayaan. Draf akad tersedia pada detail pembiayaan, sedangkan kuitansi tersedia pada Riwayat Pembayaran.'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text('Penerimaan enam bulan terakhir',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      if (report.monthlyCollections.isEmpty)
                        const Card(
                            child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                    'Belum ada pembayaran pada enam bulan terakhir.')))
                      else
                        ...report.monthlyCollections.map(
                          (item) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(formatMonth(item.month)),
                              trailing: Text(formatCurrency(item.amount),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_busy)
                  const ColoredBox(
                      color: Color(0x22000000),
                      child: Center(child: CircularProgressIndicator())),
              ],
            );
          },
        );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(
      {required this.label,
      required this.value,
      required this.icon,
      this.danger = false});

  final String label;
  final String value;
  final IconData icon;
  final bool danger;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Icon(icon,
              color:
                  danger ? const Color(0xFFB42318) : const Color(0xFF087F5B)),
          title: Text(label),
          trailing: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: danger ? const Color(0xFFB42318) : null,
              ),
            ),
          ),
        ),
      );
}
