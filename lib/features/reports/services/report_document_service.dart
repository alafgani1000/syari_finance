import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/utils/formatters.dart';
import '../../dashboard/data/dashboard_repository.dart';

class ReportDocumentService {
  Future<void> printBusinessReport(DashboardData report) => Printing.layoutPdf(
        name:
            'laporan-bisnis-${DateTime.now().toIso8601String().substring(0, 10)}.pdf',
        onLayout: (_) => _buildPdf(report),
      );

  Future<File> createCsv(DashboardData report) async {
    final lines = <String>[
      'Laporan Bisnis Arafah Finance',
      'Dibuat;${DateTime.now().toIso8601String()}',
      '',
      'Metrik;Nilai',
      'Total nasabah;${report.customerCount}',
      'Pembiayaan aktif;${report.activeFinancingCount}',
      'Total piutang;${report.outstanding}',
      'Pencairan pembiayaan;${report.totalDisbursed}',
      'Potensi margin akad;${report.plannedMargin}',
      'Nilai tunggakan;${report.overdueAmount}',
      'Penerimaan bulan ini;${report.collectedThisMonth}',
      '',
      'Bulan;Pembayaran diterima',
      ...report.monthlyCollections.map(
        (item) =>
            '${item.month.year}-${item.month.month.toString().padLeft(2, '0')};${item.amount}',
      ),
    ];
    final directory = await getTemporaryDirectory();
    final file = File(
      p.join(directory.path,
          'laporan-bisnis-${DateTime.now().millisecondsSinceEpoch}.csv'),
    );
    await file.writeAsString('\uFEFF${lines.join('\r\n')}', flush: true);
    return file;
  }

  Future<Uint8List> _buildPdf(DashboardData report) async {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (_) => [
          pw.Text('ARAFAH FINANCE',
              style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green800)),
          pw.SizedBox(height: 4),
          pw.Text('Laporan ringkasan bisnis',
              style:
                  pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.Text('Dibuat ${formatDateTime(DateTime.now())}',
              style: const pw.TextStyle(color: PdfColors.grey700)),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
            headerStyle: pw.TextStyle(
                color: PdfColors.white, fontWeight: pw.FontWeight.bold),
            headers: const ['Metrik', 'Nilai'],
            data: [
              ['Total nasabah', report.customerCount.toString()],
              ['Pembiayaan aktif', report.activeFinancingCount.toString()],
              ['Total piutang', formatCurrency(report.outstanding)],
              ['Pencairan pembiayaan', formatCurrency(report.totalDisbursed)],
              ['Potensi margin akad', formatCurrency(report.plannedMargin)],
              ['Nilai tunggakan', formatCurrency(report.overdueAmount)],
              [
                'Penerimaan bulan ini',
                formatCurrency(report.collectedThisMonth)
              ],
            ],
          ),
          pw.SizedBox(height: 22),
          pw.Text('Pembayaran enam bulan terakhir',
              style:
                  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: const ['Bulan', 'Diterima'],
            data: report.monthlyCollections
                .map((item) =>
                    [formatMonth(item.month), formatCurrency(item.amount)])
                .toList(),
          ),
          pw.SizedBox(height: 22),
          pw.Text(
              'Catatan: margin adalah potensi keuntungan sesuai akad, bukan laba kas yang telah direalisasikan.',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        ],
      ),
    );
    return document.save();
  }
}
