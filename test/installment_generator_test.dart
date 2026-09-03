import 'package:flutter_test/flutter_test.dart';
import 'package:syari_finance/features/financings/domain/installment_generator.dart';

void main() {
  group('InstallmentGenerator', () {
    test('menjaga jatuh tempo akhir bulan', () {
      final schedules = InstallmentGenerator().generate(
        startDate: DateTime(2026, 1, 31),
        tenor: 3,
        totalAmount: 120000,
      );

      expect(schedules.map((item) => item.dueDate), [
        DateTime(2026, 2, 28),
        DateTime(2026, 3, 31),
        DateTime(2026, 4, 30),
      ]);
    });

    test('meletakkan selisih pembulatan di angsuran terakhir', () {
      final schedules = InstallmentGenerator().generate(
        startDate: DateTime(2026, 1, 1),
        tenor: 3,
        totalAmount: 100000,
      );

      expect(schedules.map((item) => item.amount), [33000, 33000, 34000]);
      expect(
        schedules.fold<int>(0, (total, item) => total + item.amount),
        100000,
      );
    });

    test('mengikuti tahun kabisat', () {
      expect(addMonthsClamped(DateTime(2024, 1, 31), 1), DateTime(2024, 2, 29));
    });
  });
}
