import 'package:intl/intl.dart';

final DateFormat _dateFormat = DateFormat('dd/MM/yyyy', 'vi_VN');
final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy • HH:mm', 'vi_VN');
final DateFormat _shortDateFormat = DateFormat('dd/MM', 'vi_VN');

String formatDate(DateTime value) => _dateFormat.format(value.toLocal());
String formatDateTime(DateTime value) =>
    _dateTimeFormat.format(value.toLocal());
String formatShortDate(DateTime value) =>
    _shortDateFormat.format(value.toLocal());
