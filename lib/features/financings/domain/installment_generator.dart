class GeneratedInstallment {
  const GeneratedInstallment(
      {required this.number, required this.dueDate, required this.amount});
  final int number;
  final DateTime dueDate;
  final int amount;
}

class InstallmentGenerator {
  List<GeneratedInstallment> generate(
      {required DateTime firstDueDate,
      required int tenor,
      required int totalAmount}) {
    if (tenor <= 0 || totalAmount < 0)
      throw ArgumentError('Jadwal angsuran tidak valid');
    final base = totalAmount ~/ tenor;
    final remainder = totalAmount % tenor;
    return List.generate(
        tenor,
        (index) => GeneratedInstallment(
              number: index + 1,
              dueDate: DateTime(firstDueDate.year, firstDueDate.month + index,
                  firstDueDate.day),
              amount: base + (index == tenor - 1 ? remainder : 0),
            ));
  }
}
