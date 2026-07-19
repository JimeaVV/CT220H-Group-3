# Ghi chú tích hợp FastAPI

## URL mặc định

- Android Emulator: `http://10.0.2.2:8000`
- Swagger trên máy tính: `http://127.0.0.1:8000/docs`

## Chạy backend

Từ thư mục gốc repo backend:

```powershell
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## API được frontend sử dụng

### Người dùng

- `POST /users/{uid}`

### Danh mục

- `GET /categories/{user_id}`
- `POST /categories/`
- `POST /categories/init-defaults/`

Backend chưa có API sửa/xóa danh mục cá nhân, vì vậy UI hiện hỗ trợ xem, tạo và khởi tạo mặc định.

### Ví

- `GET /wallets/user/{user_id}`
- `POST /wallets/`
- `PUT /wallets/{wallet_id}`
- `DELETE /wallets/{wallet_id}`
- `POST /wallets/transfer/`

### Giao dịch

- `GET /transactions/user/{user_id}`
- `POST /transactions/`
- `PUT /transactions/{transaction_id}`
- `DELETE /transactions/{transaction_id}`

### Báo cáo

- `GET /reports/summary/{user_id}`
- `GET /reports/chart/{user_id}?period=week|month`

### Ngân sách

- `GET /budgets/user/{user_id}/status?month=&year=`
- `POST /budgets/`
- `PUT /budgets/{budget_id}`
- `DELETE /budgets/{budget_id}`

### Giao dịch định kỳ

- `GET /recurring_transactions/user/{user_id}`
- `POST /recurring_transactions/`
- `PUT /recurring_transactions/{id}`
- `DELETE /recurring_transactions/{id}`
- `POST /recurring_transactions/run-now/`

## Bảo mật cần bổ sung trước khi phát hành thật

Backend hiện nhận `userId` từ client. Đối với đồ án demo local, luồng này chạy được. Trước khi đưa lên production, nên:

1. Flutter gửi Firebase ID token trong header `Authorization: Bearer ...`.
2. FastAPI xác minh token bằng Firebase Admin.
3. Backend lấy UID từ token, không tin `userId` do client tự gửi.
4. Chỉ cho người dùng sửa/xóa document thuộc UID của họ.
5. Bật HTTPS và tắt cleartext HTTP trong bản release.

## Dữ liệu thập phân của recurring

`recurring.py` đang dùng `int` cho `amount`; frontend gửi `double`. Áp dụng patch:

```powershell
git apply path\to\FinTrack\backend_patch\recurring_decimal.patch
```

Hoặc đổi thủ công `amount: int` thành `amount: float` và `Optional[int]` thành `Optional[float]` trong schema recurring.
