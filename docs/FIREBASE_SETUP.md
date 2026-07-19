# Cấu hình Firebase cho FinTrack

## 1. Thêm Android app

Trong Firebase Console của project đang dùng Firestore:

1. Project settings → Your apps → Add app → Android.
2. Android package name: `com.ct220h.fintrack`.
3. App nickname: `FinTrack Android`.
4. Thêm SHA-1 và SHA-256.
5. Tải `google-services.json`.
6. Đặt file tại `android/app/google-services.json`.

Không commit `google-services.json`, `serviceAccountKey.json` hoặc khóa bí mật lên GitHub công khai.

## 2. Lấy SHA debug trên Windows

Sau khi script đã tạo thư mục Android:

```powershell
cd android
.\gradlew signingReport
cd ..
```

Sao chép SHA-1 và SHA-256 của variant `debug` vào Firebase Project settings.

## 3. Bật Authentication

Authentication → Sign-in method:

- Enable Email/Password.
- Enable Google và chọn support email.

## 4. Firestore

Backend FastAPI dùng Firebase Admin SDK và ghi các collection:

- `users`
- `wallets`
- `categories`
- `transactions`
- `budgets`
- `recurring_transactions`

Frontend không kết nối Firestore trực tiếp; mọi dữ liệu tài chính đi qua FastAPI. Firebase phía Flutter chỉ phụ trách Authentication và cung cấp UID.

## 5. Kiểm tra

1. Chạy backend.
2. Chạy Flutter app.
3. Đăng ký tài khoản.
4. Kiểm tra Firebase Authentication có user mới.
5. Kiểm tra collection `users` có document UID tương ứng.
6. Khởi tạo danh mục mặc định trong màn hình Danh mục.
7. Tạo ví rồi tạo giao dịch.

## Lỗi Google Sign-In thường gặp

- `missing-google-id-token`: chưa thêm SHA-1/SHA-256 hoặc chưa bật Google provider.
- `ApiException: 10`: package/SHA không khớp cấu hình Firebase.
- Firebase không khởi tạo: `google-services.json` sai vị trí hoặc sai package.
