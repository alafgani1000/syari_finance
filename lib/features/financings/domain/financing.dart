import 'package:syari_finance/features/financings/domain/murabahah_calculator.dart';

class Financing {
  Financing({
    required this.number,
    this.orderId,
    required this.customerId,
    required this.customerName,
    required this.itemName,
    required this.calculation,
    required this.itemPrice,
    required this.downPayment,
    required this.margin,
    required this.tenor,
    required this.startDate,
    this.status = 'Aktif',
    this.remainingAmount,
  });

  final String number;
  final String? orderId;
  final String customerId;
  final String customerName;
  final String itemName;
  final FinancingCalculation calculation;
  final int itemPrice;
  final int downPayment;
  final int margin;
  final int tenor;
  final DateTime startDate;
  final String status;
  final int? remainingAmount;

  int get outstanding => remainingAmount ?? calculation.salePrice;
  bool get isPaid => status.toLowerCase() == 'lunas' || outstanding <= 0;
}
