# MiniBank Mobile

Ứng dụng ngân hàng số dành cho khách hàng, xây dựng bằng Flutter. Ứng dụng
kết nối tới MiniBank Backend để xác thực, quản lý tài khoản, giao dịch,
tiết kiệm, khoản vay, KYC và trò chuyện hỗ trợ theo thời gian thực.

## Tính năng chính

- Đăng ký, đăng nhập, đăng xuất, làm mới phiên và xác thực OTP.
- Quản lý hồ sơ, xác minh danh tính KYC và tải tài liệu.
- Xem tài khoản, số dư, lịch sử giao dịch và thực hiện chuyển tiền.
- Đăng ký khoản vay, quản lý hợp đồng và lịch trả nợ.
- Mở, theo dõi và tất toán khoản tiết kiệm.
- Quét/tạo mã QR và tải ảnh/tài liệu.
- Nhận thông báo và trò chuyện hỗ trợ qua WebSocket/STOMP.
- Nhận khuyến nghị tài chính từ AI service thông qua backend.

## Công nghệ

- Flutter với Dart `^3.9.2`.
- `http`, `flutter_secure_storage`, `shared_preferences`.
- `mobile_scanner`, `flutter_zxing`, `qr_flutter`.
- `image_picker`, `file_picker`, Cloudinary.
- `stomp_dart_client` cho tính năng thời gian thực.

## Yêu cầu

- Flutter SDK tương thích với Dart 3.9.2.
- Android Studio/Android SDK hoặc Xcode (khi chạy iOS).
- Một instance MiniBank Backend đang chạy.

Kiểm tra môi trường:

```bash
flutter doctor
flutter --version
```

## Cài đặt và chạy

```bash
flutter pub get
flutter run
```

### Cấu hình môi trường

Tạo file `.env` tại thư mục gốc của ứng dụng:

```env
API_BASE_URL=http://localhost:8081
CLOUDINARY_CLOUD_NAME=<cloudinary-cloud-name>
CLOUDINARY_UPLOAD_PRESET=<unsigned-upload-preset>
```

`API_BASE_URL` phải trỏ tới backend. Khi chạy Android emulator, địa chỉ
backend trên máy phát triển thường là `http://10.0.2.2:8081`; iOS simulator
thường dùng `http://localhost:8081`. Với thiết bị thật, dùng địa chỉ IP LAN
của máy phát triển và bảo đảm thiết bị truy cập được cổng backend.

Không commit `.env`, token, khóa bí mật hoặc thông tin tài khoản thật.

## Kiểm tra chất lượng

```bash
flutter analyze
flutter test
dart format --output=none --set-exit-if-changed lib test
```

## Build

```bash
flutter build apk --release
flutter build appbundle --release
flutter build ios --release
```

Lệnh build iOS cần macOS và Xcode. Với Android, cấu hình signing release
phải được cung cấp ở môi trường triển khai; không đưa keystore vào repository.

## Cấu trúc thư mục

```text
lib/
├── api/       # Client gọi API backend
├── auth/      # Trạng thái và luồng xác thực
├── config/    # Cấu hình ứng dụng
├── models/    # Model dữ liệu
├── profile/   # Hồ sơ và KYC
├── screens/   # Các màn hình và luồng người dùng
├── security/  # Bảo vệ dữ liệu cục bộ
├── utils/     # Hàm tiện ích
└── widgets/   # Widget dùng chung
test/          # Widget và unit test
```

## Kết nối với hệ thống

Mobile không truy cập trực tiếp cơ sở dữ liệu. Luồng triển khai khuyến nghị:

```text
MiniBank Mobile -> MiniBank Backend -> PostgreSQL
                               └----> AI Service
```

Các URL API cụ thể được định nghĩa trong `lib/api/` và dùng chung
`API_BASE_URL`. WebSocket sử dụng endpoint `/ws` của backend.

## Góp phần

1. Tạo branch từ `main`.
2. Chạy `flutter analyze` và `flutter test`.
3. Mô tả rõ thay đổi, cách kiểm thử và ảnh chụp màn hình nếu có thay đổi UI.
4. Không đưa secret hoặc file `.env` vào commit.
