import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/utils/formatters.dart';
import '../../installments/domain/installment.dart';
import '../domain/financing.dart';

class FinancingPdfService {
  Future<void> printFinancing({
    required Financing financing,
    required List<Installment> installments,
  }) =>
      Printing.layoutPdf(
        name: 'rincian-${financing.number}.pdf',
        onLayout: (_) => _buildPdf(financing, installments),
      );

  Future<void> printContract(Financing financing) => Printing.layoutPdf(
        name: 'draf-akad-${financing.number}.pdf',
        onLayout: (_) => _buildContract(financing),
      );

  Future<Uint8List> _buildContract(Financing financing) async {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (_) => [
          pw.Center(
            child: pw.Text(
              'DRAF AKAD PEMBIAYAAN MURABAHAH',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Center(child: pw.Text(financing.number)),
          pw.SizedBox(height: 22),
          pw.Text(
            'Pada tanggal ${formatDate(financing.startDate)}, Arafah Finance dan nasabah berikut menyepakati pembiayaan Murabahah atas barang yang tercantum di bawah ini.',
            textAlign: pw.TextAlign.justify,
          ),
          pw.SizedBox(height: 16),
          _infoTable([
            ['Nasabah', financing.customerName],
            ['Barang', financing.itemName],
            ['Harga perolehan barang', formatCurrency(financing.itemPrice)],
            ['Uang muka / DP', formatCurrency(financing.downPayment)],
            [
              'Pokok pembiayaan',
              formatCurrency(financing.calculation.principal)
            ],
            ['Margin keuntungan', formatCurrency(financing.margin)],
            [
              'Harga jual / nilai akad',
              formatCurrency(financing.calculation.salePrice)
            ],
            ['Tenor', '${financing.tenor} bulan'],
            [
              'Angsuran reguler',
              formatCurrency(financing.calculation.installment)
            ],
            if (financing.calculation.hasFinalAdjustment)
              [
                'Angsuran bulan terakhir',
                formatCurrency(financing.calculation.finalInstallment)
              ],
          ]),
          pw.SizedBox(height: 18),
          pw.Text('Ketentuan ringkas',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text(
              '1. Harga jual telah mencakup margin yang disepakati dan tidak berubah selama akad berjalan.'),
          pw.SizedBox(height: 4),
          pw.Text(
              '2. Nasabah membayar angsuran sesuai jadwal yang tercantum pada kartu angsuran.'),
          pw.SizedBox(height: 4),
          pw.Text(
              '3. Dokumen ini adalah draf operasional. Lengkapi identitas, saksi, klausul, dan pengesahan sesuai kebijakan lembaga serta tinjauan pihak berwenang sebelum ditandatangani.'),
          pw.SizedBox(height: 44),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _signature('Pihak Arafah Finance'),
              _signature('Nasabah'),
            ],
          ),
        ],
      ),
    );
    return document.save();
  }

  pw.Widget _signature(String label) => pw.Column(
        children: [
          pw.SizedBox(width: 170, child: pw.Divider()),
          pw.SizedBox(height: 4),
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
        ],
      );
  Future<Uint8List> _buildPdf(
    Financing financing,
    List<Installment> installments,
  ) async {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'ARAFAH FINANCE',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green800,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Divider(color: PdfColors.green200),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Halaman ${context.pageNumber} dari ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 12),
          pw.Text(
            'Rincian Pembiayaan Murabahah',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            financing.number,
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 20),
          _sectionTitle('Informasi Pembiayaan'),
          _infoTable([
            ['Nasabah', financing.customerName],
            ['Barang', financing.itemName],
            ['Tanggal akad', formatDate(financing.startDate)],
            ['Status', financing.isPaid ? 'Lunas' : 'Aktif'],
          ]),
          pw.SizedBox(height: 16),
          _sectionTitle('Ringkasan Akad'),
          _infoTable([
            ['Harga barang', formatCurrency(financing.itemPrice)],
            ['Uang muka / DP', formatCurrency(financing.downPayment)],
            [
              'Pokok pembiayaan',
              formatCurrency(financing.calculation.principal)
            ],
            ['Margin keuntungan', formatCurrency(financing.margin)],
            [
              'Nilai akad pembiayaan',
              formatCurrency(financing.calculation.salePrice)
            ],
            [
              'Total pembayaran pelanggan',
              formatCurrency(financing.totalCustomerPayment)
            ],
            ['Tenor', '${financing.tenor} bulan'],
            ['Sisa tagihan', formatCurrency(financing.outstanding)],
          ]),
          pw.SizedBox(height: 20),
          _sectionTitle('Jadwal Angsuran'),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellPadding:
                const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
            headers: const [
              'Ke-',
              'Jatuh tempo',
              'Tagihan',
              'Terbayar',
              'Sisa',
              'Status'
            ],
            data: installments
                .map(
                  (item) => [
                    item.number.toString(),
                    formatDate(item.dueDate),
                    formatCurrency(item.amount),
                    formatCurrency(item.paidAmount),
                    formatCurrency(item.remaining),
                    item.status,
                  ],
                )
                .toList(),
          ),
          pw.SizedBox(height: 14),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Total sisa tagihan: ${formatCurrency(financing.outstanding)}',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    return document.save();
  }

  pw.Widget _sectionTitle(String title) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: const pw.BoxDecoration(color: PdfColors.green50),
        child: pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.green900,
          ),
        ),
      );

  pw.Widget _infoTable(List<List<String>> rows) => pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: .5),
        columnWidths: const {
          0: pw.FlexColumnWidth(2),
          1: pw.FlexColumnWidth(3)
        },
        children: rows
            .map(
              (row) => pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child:
                        pw.Text(row[0], style: const pw.TextStyle(fontSize: 9)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      row[1],
                      style: pw.TextStyle(
                          fontSize: 9, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      );
}
