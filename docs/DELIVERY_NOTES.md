# Ghi chú bàn giao

## Phạm vi đã hoàn thành

Source Flutter/Dart đã được dựng cho toàn bộ luồng FinTrack: Authentication, Dashboard, Giao dịch, Danh mục, Ví, Báo cáo, Ngân sách, Giao dịch định kỳ, Hồ sơ và Light/Dark Mode.

## Kiểm tra đã thực hiện trong môi trường tạo source

- Kiểm tra toàn bộ import tương đối đều trỏ đến file tồn tại.
- Kiểm tra cân bằng ngoặc `()`, `[]`, `{}` trên toàn bộ file Dart.
- Kiểm tra cú pháp YAML của `pubspec.yaml` và `analysis_options.yaml`.
- Đối chiếu đường dẫn API và payload với backend hiện tại trong repo CT220H-Group-3.

## Kiểm tra cần chạy trên máy có Flutter SDK

Môi trường tạo ZIP không có Flutter SDK/Android SDK nên chưa thể chạy trực tiếp:

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

Hãy chạy `setup_fintrack.bat`, thêm `google-services.json`, sau đó chạy ba lệnh trên. Nếu phiên bản Flutter của máy thay đổi API/dependency, ưu tiên giữ code và cập nhật phiên bản package trong `pubspec.yaml` theo báo lỗi của `flutter pub get`.
