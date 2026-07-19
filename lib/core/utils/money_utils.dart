import 'package:intl/intl.dart';

final NumberFormat _wholeMoney = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
);
final NumberFormat _decimalMoney = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 2,
);

String formatMoney(num value) {
  final hasDecimal = (value - value.round()).abs() > 0.000001;
  return (hasDecimal ? _decimalMoney : _wholeMoney).format(value);
}

double? parseMoneyInput(String input) {
  var value = input.trim().replaceAll(' ', '');
  if (value.isEmpty) return null;

  if (value.contains(',') && value.contains('.')) {
    value = value.replaceAll('.', '').replaceAll(',', '.');
  } else if (value.contains(',')) {
    value = value.replaceAll(',', '.');
  } else {
    final dotCount = '.'.allMatches(value).length;
    if (dotCount > 1) value = value.replaceAll('.', '');
  }

  return double.tryParse(value);
}
