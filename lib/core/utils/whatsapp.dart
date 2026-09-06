import 'formatters.dart';

String? normalizeWhatsAppNumber(String phone) {
  final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  if (digits.startsWith('62')) return digits;
  if (digits.startsWith('0')) return '62${digits.substring(1)}';
  if (digits.startsWith('8')) return '62$digits';
  return null;
}

String paymentReminderMessage({
  required String customerName,
  required String financingNumber,
  required String itemName,
  required int installmentNumber,
  required int remainingInstallments,
  required int remainingAmount,
  required DateTime dueDate,
}) =>
    '''Assalamu'alaikum Bapak/Ibu $customerName,

Kami mengingatkan pembayaran angsuran pembiayaan $financingNumber.

Barang: $itemName

Angsuran ke-$installmentNumber: ${formatCurrency(remainingAmount)}
Jatuh tempo: ${formatDate(dueDate)}
${remainingInstallments == 0 ? 'Angsuran ini adalah angsuran terakhir.' : 'Sisa angsuran setelah pembayaran ini: $remainingInstallments kali.'}

Mohon melakukan pembayaran sesuai nominal tersebut. Terima kasih.''';
