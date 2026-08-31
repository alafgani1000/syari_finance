import 'package:flutter_test/flutter_test.dart';
import 'package:syari_finance/features/financings/domain/murabahah_calculator.dart';

void main() {
  test('menghitung murabahah sesuai contoh bisnis', () {
    final result = MurabahahCalculator().calculate(
        itemPrice: 10000000, downPayment: 2000000, margin: 2000000, tenor: 10);
    expect(result.principal, 8000000);
    expect(result.salePrice, 10000000);
    expect(result.installment, 1000000);
  });
  test('menolak tenor tidak valid dan DP melebihi harga', () {
    expect(
        () => MurabahahCalculator()
            .calculate(itemPrice: 1, downPayment: 0, margin: 0, tenor: 0),
        throwsArgumentError);
    expect(
        () => MurabahahCalculator()
            .calculate(itemPrice: 1, downPayment: 2, margin: 0, tenor: 1),
        throwsArgumentError);
  });
}
