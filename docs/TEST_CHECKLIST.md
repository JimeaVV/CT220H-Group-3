# Checklist kiểm thử FinTrack

## Authentication

- [ ] Đăng ký email/password thành công.
- [ ] Email xác minh được gửi.
- [ ] Đăng nhập email/password thành công.
- [ ] Sai mật khẩu hiển thị thông báo.
- [ ] Quên mật khẩu gửi email.
- [ ] Google Sign-In hoạt động sau khi thêm SHA.
- [ ] Đóng/mở app vẫn duy trì đăng nhập.
- [ ] Đăng xuất thành công.

## Danh mục và ví

- [ ] Khởi tạo danh mục mặc định không tạo trùng.
- [ ] Tạo danh mục Thu/Chi cá nhân.
- [ ] Tạo ví với số dư ban đầu.
- [ ] Sửa ví.
- [ ] Chuyển tiền giữa hai ví.
- [ ] Không cho chuyển quá số dư.
- [ ] Xóa ví hiển thị xác nhận.

## Giao dịch

- [ ] Thêm khoản Chi làm giảm số dư ví.
- [ ] Thêm khoản Thu làm tăng số dư ví.
- [ ] Nhập được số thập phân.
- [ ] Sửa số tiền/loại/ví đồng bộ số dư.
- [ ] Tìm kiếm theo ghi chú/danh mục/ví.
- [ ] Lọc Thu/Chi.
- [ ] Xóa có hộp thoại xác nhận và hoàn số dư.

## Báo cáo và ngân sách

- [ ] Summary đúng với dữ liệu tháng hiện tại.
- [ ] Biểu đồ tuần tải được.
- [ ] Biểu đồ tháng tải được.
- [ ] Tạo ngân sách theo danh mục.
- [ ] Hiển thị cảnh báo từ 80%.
- [ ] Hiển thị vượt mức trên 100%.
- [ ] Sửa/xóa ngân sách.

## Định kỳ

- [ ] Tạo lịch daily/weekly/monthly/yearly.
- [ ] Bật/tắt lịch.
- [ ] Sửa lịch.
- [ ] Chạy `run-now` tạo giao dịch đến hạn.
- [ ] Ví và dashboard tự cập nhật sau khi chạy.
- [ ] Xóa lịch có xác nhận.

## UI/QoL

- [ ] Light mode.
- [ ] Dark mode.
- [ ] Theme theo hệ thống.
- [ ] Không overflow trên màn hình nhỏ.
- [ ] Pull-to-refresh hoạt động.
- [ ] Backend offline hiển thị lỗi và nút tải lại.
