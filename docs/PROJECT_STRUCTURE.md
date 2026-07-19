# Cấu trúc dự án

## Luồng dữ liệu

```text
Screen → Riverpod Provider → Repository → Dio/FastAPI → Firestore
                                └────────→ Firebase Authentication
```

## Thư mục

- `lib/core/config`: tên app, API base URL.
- `lib/core/network`: Dio client, timeout và chuẩn hóa lỗi.
- `lib/core/theme`: Material 3 đen–trắng, Light/Dark.
- `lib/core/utils`: định dạng VND, ngày giờ và validator.
- `lib/core/widgets`: component dùng lại.
- `lib/features/auth`: đăng nhập, đăng ký, reset, xác minh email.
- `lib/features/home`: dashboard.
- `lib/features/transactions`: danh sách, tìm kiếm, lọc và form CRUD.
- `lib/features/categories`: danh mục mặc định/cá nhân.
- `lib/features/wallets`: CRUD ví và chuyển tiền.
- `lib/features/reports`: biểu đồ tuần/tháng.
- `lib/features/budgets`: hạn mức theo danh mục.
- `lib/features/recurring`: giao dịch lặp.
- `lib/features/profile`: hồ sơ, theme và lối tắt quản lý.
- `lib/models`: các model mapping JSON.
- `lib/repositories`: lớp tích hợp Firebase/FastAPI.
- `lib/providers`: Riverpod providers và invalidate dữ liệu.

## Điều hướng

Bottom navigation:

1. Tổng quan
2. Giao dịch
3. Nút + thêm nhanh
4. Báo cáo
5. Cá nhân

Các màn hình Ví, Danh mục, Ngân sách và Định kỳ nằm trong khu vực Cá nhân và route riêng.
