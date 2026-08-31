import 'package:intl/intl.dart';

final _currency =
    NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
final _date = DateFormat('d MMMM y', 'id_ID');
String formatCurrency(int value) =>
    _currency.format(value).replaceAll('Rp ', 'Rp');
String formatDate(DateTime value) => _date.format(value);
