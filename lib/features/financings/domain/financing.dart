import 'package:syari_finance/features/financings/domain/murabahah_calculator.dart';

class Financing {
  Financing(
      {required this.number,
      required this.customerId,
      required this.customerName,
      required this.itemName,
      required this.calculation,
      required this.itemPrice,
      required this.downPayment,
      required this.margin,
      required this.tenor,
      required this.startDate});
  final String number;
  final String customerId;
  final String customerName;
  final String itemName;
  final FinancingCalculation calculation;
  final int itemPrice;
  final int downPayment;
  final int margin;
  final int tenor;
  final DateTime startDate;
}
