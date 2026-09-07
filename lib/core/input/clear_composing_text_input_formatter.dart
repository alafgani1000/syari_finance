import 'package:flutter/services.dart';

/// Mengakhiri composing range dari IME Android agar teks yang sudah dihapus
/// tidak dikirim kembali bersama karakter berikutnya.
class ClearComposingTextInputFormatter extends TextInputFormatter {
  const ClearComposingTextInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) =>
      newValue.copyWith(composing: TextRange.empty);
}
