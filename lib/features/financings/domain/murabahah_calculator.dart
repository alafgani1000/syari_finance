class FinancingCalculation {
  const FinancingCalculation({
    required this.principal,
    required this.salePrice,
    required this.installment,
    required this.finalInstallment,
  });

  final int principal;
  final int salePrice;
  final int installment;
  final int finalInstallment;

  bool get hasFinalAdjustment => finalInstallment != installment;
}

class MurabahahCalculator {
  FinancingCalculation calculate({
    required int itemPrice,
    required int downPayment,
    required int margin,
    required int tenor,
  }) {
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
    final installment = _roundDownToThousand(salePrice ~/ tenor);
    if (installment <= 0) {
      throw ArgumentError('Nilai angsuran terlalu kecil');
    }
    final finalInstallment = salePrice - (installment * (tenor - 1));
    return FinancingCalculation(
      principal: principal,
      salePrice: salePrice,
      installment: installment,
      finalInstallment: finalInstallment,
    );
  }

  int _roundDownToThousand(int value) => (value ~/ 1000) * 1000;
}
