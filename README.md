# FinTrack Mobile

Ứng dụng Flutter quản lý chi tiêu cá nhân, giao diện đen–trắng tối giản, hỗ trợ Light/Dark Mode, Firebase Authentication và FastAPI/Firestore.

## Chức năng đã có

- Đăng ký, đăng nhập Email/Password, đăng nhập Google, quên mật khẩu.
- Gửi email xác minh và hiển thị trạng thái tài khoản.
- Trang tổng quan số dư, tổng thu, tổng chi và giao dịch gần đây.
- CRUD giao dịch thu/chi, chọn ví, danh mục, ngày giờ và ghi chú.
- Danh mục mặc định và danh mục cá nhân.
- Quản lý nhiều ví, cập nhật số dư và chuyển tiền giữa ví.
- Báo cáo tuần/tháng bằng biểu đồ cột và biểu đồ cơ cấu thu/chi.
- Ngân sách theo danh mục/tháng, cảnh báo 80% và vượt hạn mức.
- Giao dịch định kỳ, bật/tắt, chỉnh sửa, xóa và chạy xử lý thủ công.
- Chế độ sáng, tối hoặc theo hệ thống; ghi nhớ lựa chọn.
- Hộp thoại xác nhận trước khi xóa giao dịch.
- Hỗ trợ số tiền thập phân ở giao dịch, ví, chuyển tiền và ngân sách.

## Chuẩn bị

1. Cài Flutter SDK và Android Studio.
2. Chạy backend từ thư mục gốc repo CT220H-Group-3:

```powershell
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

3. Xác nhận Swagger mở được tại `http://127.0.0.1:8000/docs`.
4. Trong Firebase Console, thêm Android app với package:

```text
com.ct220h.fintrack
```

5. Tải `google-services.json` và đặt vào:

```text
android/app/google-services.json
```

6. Bật Authentication providers: Email/Password và Google. Thêm SHA-1/SHA-256 của debug keystore để Google Sign-In hoạt động.

## Tạo phần Android và chạy

ZIP này ưu tiên source sạch, không kèm Gradle cache. Trên Windows, mở PowerShell tại thư mục FinTrack rồi chạy:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\bootstrap.ps1
```

Hoặc chạy:

```bat
setup_fintrack.bat
```

Script sẽ:

- Tạo thư mục Android bằng `flutter create`.
- Đặt package `com.ct220h.fintrack`.
- Bật Google Services plugin.
- Cho phép HTTP local để emulator gọi FastAPI.
- Chạy `flutter pub get` và tạo launcher icon.

Sau đó:

```powershell
flutter run
```

## Kết nối backend

Mặc định ứng dụng dùng:

```text
http://10.0.2.2:8000
```

Đây là địa chỉ Android Emulator dùng để truy cập `localhost` của máy tính. Có thể đổi khi chạy:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Khi chạy trên điện thoại thật, thay bằng IP LAN của máy tính, ví dụ:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000
```

Và đảm bảo FastAPI chạy với `--host 0.0.0.0`, Windows Firewall cho phép cổng 8000.

## Firebase và dữ liệu hiện có

Ứng dụng lọc dữ liệu bằng Firebase UID. Các document cũ có `userId` dạng `1`, `user_test_123` hoặc giá trị test khác sẽ không xuất hiện khi đăng nhập bằng tài khoản Firebase mới. Hãy tạo dữ liệu qua app hoặc đổi `userId` sang UID thực tế.

Xem thêm:

- `docs/FIREBASE_SETUP.md`
- `docs/BACKEND_NOTES.md`
- `docs/PROJECT_STRUCTURE.md`
- `docs/TEST_CHECKLIST.md`

## Lưu ý backend giao dịch định kỳ

Backend hiện khai báo `amount` là `int`, trong khi yêu cầu ứng dụng cho phép tiền thập phân. File `backend_patch/recurring_decimal.patch` chứa thay đổi tối thiểu sang `float`. Giao dịch thường, ví và ngân sách đã nhận `float`.

## Cấu trúc chính

```text
lib/
├── core/          # config, theme, network, utils, widgets
├── features/      # auth, home, transactions, reports, profile...
├── models/        # model dữ liệu
├── providers/     # Riverpod providers
└── repositories/  # Firebase Auth và FastAPI
```

## Lệnh kiểm tra

```powershell
flutter analyze
flutter test
flutter build apk --debug
```
