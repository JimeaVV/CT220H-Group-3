class Validators {
  Validators._();

  static String? requiredText(String? value, {String field = 'Trường này'}) {
    if (value == null || value.trim().isEmpty) return '$field không được để trống';
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email không được để trống';
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(value.trim())) return 'Email không hợp lệ';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Mật khẩu không được để trống';
    if (value.length < 6) return 'Mật khẩu phải có ít nhất 6 ký tự';
    return null;
  }
}
