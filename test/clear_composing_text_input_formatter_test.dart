import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syari_finance/core/input/clear_composing_text_input_formatter.dart';

void main() {
  test('menghapus composing range keyboard Android tanpa mengubah teks', () {
    const formatter = ClearComposingTextInputFormatter();
    const oldValue = TextEditingValue(
      text: 'alafha',
      selection: TextSelection.collapsed(offset: 6),
      composing: TextRange(start: 0, end: 6),
    );
    const newValue = TextEditingValue(
      text: 'alaf',
      selection: TextSelection.collapsed(offset: 4),
      composing: TextRange(start: 0, end: 4),
    );

    final result = formatter.formatEditUpdate(oldValue, newValue);

    expect(result.text, 'alaf');
    expect(result.selection, const TextSelection.collapsed(offset: 4));
    expect(result.composing, TextRange.empty);
  });
}
