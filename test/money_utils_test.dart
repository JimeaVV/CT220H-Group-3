import 'package:flutter_test/flutter_test.dart';
import 'package:fintrack/core/utils/money_utils.dart';

void main() {
  group('parseMoneyInput', () {
    test('đọc số nguyên', () {
      expect(parseMoneyInput('1500000'), 1500000);
    });

    test('đọc số thập phân dùng dấu phẩy', () {
      expect(parseMoneyInput('1250,50'), 1250.5);
    });

    test('đọc định dạng Việt Nam có phân cách hàng nghìn', () {
      expect(parseMoneyInput('1.250.000'), 1250000);
    });

    test('trả null với chuỗi rỗng', () {
      expect(parseMoneyInput(''), isNull);
    });
  });
}
