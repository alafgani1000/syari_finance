import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syari_finance/main.dart';

void main() {
  testWidgets('aplikasi dapat dibangun', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SyariFinanceApp()));
    expect(find.byType(SyariFinanceApp), findsOneWidget);
  });
}
