import 'package:flutter_test/flutter_test.dart';
import 'package:syari_finance/core/utils/whatsapp.dart';

void main() {
  group('normalizeWhatsAppNumber', () {
    test('converts Indonesian local numbers to country-code format', () {
      expect(normalizeWhatsAppNumber('0812-3456-7890'), '6281234567890');
    });

    test('keeps country-code format', () {
      expect(normalizeWhatsAppNumber('+62 812 3456 7890'), '6281234567890');
    });

    test('rejects unsupported number formats', () {
      expect(normalizeWhatsAppNumber('12345'), isNull);
    });
  });

  test('includes the financed item in the payment reminder', () {
    final message = paymentReminderMessage(
      customerName: 'Ahmad',
      financingNumber: 'MRB-2026-000001',
      itemName: 'Sepeda motor',
      installmentNumber: 2,
      remainingInstallments: 10,
      remainingAmount: 25000,
      dueDate: DateTime(2026, 9, 10),
    );

    expect(message, contains('Barang: Sepeda motor'));
    expect(
      message,
      contains('Sisa angsuran setelah pembayaran ini: 10 kali.'),
    );
  });
}
