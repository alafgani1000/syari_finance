import 'dart:math' as math;

class GeneratedInstallment {
  const GeneratedInstallment({
    required this.number,
    required this.dueDate,
    required this.amount,
  });

  final int number;
  final DateTime dueDate;
  final int amount;
}

DateTime addMonthsClamped(DateTime date, int months) {
  final monthIndex = date.month - 1 + months;
  final year = date.year + monthIndex ~/ 12;
  final month = monthIndex % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, math.min(date.day, lastDay));
}

class InstallmentGenerator {
  List<GeneratedInstallment> generate({
    required DateTime startDate,
    required int tenor,
    required int totalAmount,
  }) {
    if (tenor <= 0 || totalAmount <= 0 || totalAmount < tenor) {
      throw ArgumentError('Jadwal angsuran tidak valid');
    }

    final regularAmount = (totalAmount / tenor).ceil();
    return List.generate(tenor, (index) {
      final isLast = index == tenor - 1;
      final amount =
          isLast ? totalAmount - (regularAmount * (tenor - 1)) : regularAmount;
      return GeneratedInstallment(
        number: index + 1,
        dueDate: addMonthsClamped(startDate, index + 1),
        amount: amount,
      );
    });
  }
}
