class FinancingCalculation {
  const FinancingCalculation(
      {required this.principal,
      required this.salePrice,
      required this.installment});
  final int principal;
  final int salePrice;
  final int installment;
}

class MurabahahCalculator {
  FinancingCalculation calculate(
      {required int itemPrice,
      required int downPayment,
      required int margin,
      required int tenor}) {
    if (itemPrice <= 0 ||
        downPayment < 0 ||
        margin < 0 ||
        tenor <= 0 ||
        downPayment > itemPrice ||
        itemPrice - downPayment + margin <= 0) {
      throw ArgumentError('Nilai pembiayaan tidak valid');
    }
    final principal = itemPrice - downPayment;
    final salePrice = principal + margin;
    return FinancingCalculation(
        principal: principal,
        salePrice: salePrice,
        installment: (salePrice / tenor).ceil());
  }
}
