import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/utils/formatters.dart';
import '../data/payment_repository.dart';

class PaymentReceiptPdfService {
  Future<void> printReceipt(PaymentRecord payment) => Printing.layoutPdf(
        name:
            'kuitansi-${payment.financingNumber}-${payment.id.substring(0, 8)}.pdf',
        onLayout: (_) => _build(payment),
      );

  Future<Uint8List> _build(PaymentRecord payment) async {
    final document = pw.Document();
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('ARAFAH FINANCE',
                style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green800)),
            pw.SizedBox(height: 18),
            pw.Text('KUITANSI PEMBAYARAN',
                style:
                    pw.TextStyle(fontSize: 19, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('No. ${payment.id.substring(0, 8).toUpperCase()}'),
            pw.Divider(color: PdfColors.green300),
            pw.SizedBox(height: 12),
            _line('Nasabah', payment.customerName),
            _line('Pembiayaan', payment.financingNumber),
            _line('Angsuran', '#${payment.installmentNumber}'),
            _line('Tanggal', formatDateTime(payment.paymentDate)),
            _line('Metode', payment.paymentMethod),
            if ((payment.notes ?? '').isNotEmpty)
              _line('Catatan', payment.notes!),
            pw.SizedBox(height: 18),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                  color: PdfColors.green50,
                  border: pw.Border.all(color: PdfColors.green200)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Nominal diterima',
                      style: const pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(height: 4),
                  pw.Text(formatCurrency(payment.amount),
                      style: pw.TextStyle(
                          fontSize: 21, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
            pw.Spacer(),
            pw.Text(
                'Dokumen dibuat oleh aplikasi. Simpan sebagai bukti transaksi.',
                style:
                    const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          ],
        ),
      ),
    );
    return document.save();
  }

  pw.Widget _line(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 7),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
                width: 92,
                child: pw.Text(label,
                    style: const pw.TextStyle(color: PdfColors.grey700))),
            pw.Expanded(child: pw.Text(value)),
          ],
        ),
      );
}
