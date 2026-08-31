class Installment {
  const Installment(
      {required this.id,
      required this.financingNumber,
      required this.customerName,
      required this.number,
      required this.dueDate,
      required this.amount,
      required this.paidAmount});
  final String id;
  final String financingNumber;
  final String customerName;
  final int number;
  final DateTime dueDate;
  final int amount;
  final int paidAmount;

  int get remaining => amount - paidAmount;
  bool get isPaid => remaining <= 0;
  bool get isOverdue =>
      !isPaid &&
      dueDate.isBefore(DateTime(
          DateTime.now().year, DateTime.now().month, DateTime.now().day));
  String get status => isPaid
      ? 'Lunas'
      : paidAmount > 0
          ? 'Sebagian'
          : isOverdue
              ? 'Terlambat'
              : 'Belum Bayar';
}
