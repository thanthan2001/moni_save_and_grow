# MONI - Save & Grow

Ứng dụng Flutter quản lý tài chính cá nhân theo hướng Clean Architecture, tập trung vào các nghiệp vụ thu/chi, danh mục, thống kê, ngân sách, giới hạn chi tiêu, giao dịch định kỳ và sao lưu dữ liệu.

## 1. Tổng quan

Dự án được tổ chức theo feature-first và tách lớp rõ ràng theo mô hình:
- Presentation
- Domain
- Data

Các module chính:
- Auth
- Dashboard
- Transaction
- Category
- Statistics
- Budget
- Spending Limit
- Recurring Transaction
- Backup
- Settings
- Splash
- Home

## 2. Công nghệ sử dụng

- Flutter
- flutter_bloc (State Management)
- get_it (Dependency Injection)
- go_router (Routing)
- Hive (Local Storage)
- Dio (HTTP Client)
- Google Sign-In + Google Drive API (Cloud Backup)

## 3. Kiến trúc

### 3.1 Clean Architecture

Mỗi feature trong lib/features được tách thành:
- data: datasource, model, repository implementation
- domain: entity, repository abstraction, usecase
- presentation: page/screen, bloc, widget UI

### 3.2 Data Flow tiêu biểu

1. UI phát event vào BLoC
2. BLoC gọi UseCase
3. UseCase gọi Repository
4. Repository làm việc với DataSource (local/remote/cloud)
5. Kết quả trả ngược về BLoC và phát State cho UI

Ví dụ login:
- LoginPage -> LoginEvent
- AuthBloc -> LoginUsecase
- AuthRepositoryImpl -> AuthRemoteDataSource (Dio POST /login)
- Trả về UserModel -> AuthAuthenticated/AuthError

## 4. Cấu trúc thư mục

```text
lib
|-- main.dart
|-- app
|   |-- app.dart
|   |-- app_binding.dart
|   |-- app_config.dart
|-- core
|   |-- configs
|   |-- di
|   |-- error
|   |-- extensions
|   |-- network
|   |-- routing
|   |-- storage
|   |-- theme
|   |-- usecases
|   |-- utils
|-- features
|   |-- auth
|   |-- backup
|   |-- budget
|   |-- category
|   |-- dashboard
|   |-- home
|   |-- recurring_transaction
|   |-- settings
|   |-- spending_limit
|   |-- splash
|   |-- statistics
|   |-- transaction
|-- global
|   |-- bloc
|   |-- widgets
```

## 5. App Flow

### 5.1 Khởi động
- main.dart -> runApp(App)
- AppBinding.init() để init môi trường và DI
- MaterialApp.router dùng GoRouter
- Route mặc định: / -> SplashPage

### 5.2 Điều hướng chính
- SplashPage -> /dashboard (sau khoảng 2 giây)
- LoginPage -> /home khi đăng nhập thành công
- Dashboard qua bottom nav đến:
  - /transactions
  - /statistics
  - /transactions/add
  - /features
  - /settings

### 5.3 Luồng theo tính năng
- Transaction: list, thêm, sửa, xóa
- Category: list, thêm, sửa, xóa
- Budget: quản lý ngân sách, thêm/sửa qua màn hình riêng
- Spending Limit: thiết lập và bật/tắt giới hạn chi tiêu
- Recurring Transaction: tạo và xử lý giao dịch định kỳ
- Backup: sao lưu/khôi phục local và cloud

## 6. Routing

Router trung tâm tại:
- lib/core/routing/app_router.dart

Các route chính:
- /
- /login
- /home
- /dashboard
- /transactions
- /transactions/add
- /transactions/edit
- /categories
- /categories/add
- /categories/edit
- /statistics
- /settings
- /features
- /budgets
- /spending-limit
- /recurring-transactions
- /backup

Lưu ý: một số màn hình add/edit hiện vẫn dùng Navigator.push(MaterialPageRoute) thay vì GoRouter.

## 7. State Management (BLoC)

Các BLoC chính trong dự án:
- AuthBloc
- DashboardBloc
- TransactionBloc
- CategoryBloc
- StatisticsBloc
- SettingsBloc
- BudgetBloc
- SpendingLimitBloc
- RecurringTransactionBloc

Mẫu xử lý điển hình:
- Load event -> Loading state -> Loaded/Error
- Action event (add/update/delete) -> InProgress -> Success + reload dữ liệu

## 8. Data Layer

### 8.1 Repository
- AuthRepositoryImpl (remote)
- TransactionRepositoryImpl (local)
- CategoryManagementRepositoryImpl (local)
- DashboardRepositoryImpl (tổng hợp)
- StatisticsRepositoryImpl (tổng hợp)
- BudgetRepositoryImpl (local Hive)
- SpendingLimitRepositoryImpl (local Hive)
- RecurringTransactionRepositoryImpl (local Hive)
- BackupRepositoryImpl (local backup)
- GoogleDriveBackupRepositoryImpl (cloud backup)

### 8.2 DataSource
- Local: Hive box cho transaction/category/budget/spending_limit/recurring
- Remote: Auth API qua Dio
- Cloud: Google Drive

## 9. Hướng dẫn cài đặt và chạy

### 9.1 Yêu cầu
- Flutter SDK (khuyến nghị bản stable mới)
- Dart SDK (theo Flutter SDK)
- Android Studio hoặc VS Code + Flutter extension

### 9.2 Cài dependencies

```bash
flutter pub get
```

### 9.3 Chạy ứng dụng

```bash
flutter run
```

### 9.4 Build

```bash
flutter build apk
flutter build ios
flutter build web
```

## 10. Điểm cần cải thiện (theo code hiện tại)

- Splash hiện chưa kiểm tra trạng thái đăng nhập, đang điều hướng thẳng đến dashboard.
- Chưa thống nhất hoàn toàn navigation giữa GoRouter và Navigator.
- Statistics filter theo category đang để dữ liệu categories rỗng ở một số chỗ.
- Có ghi chú về RecurringTransactionService ở main nhưng chưa thấy luồng gọi rõ ràng.

## 11. Định hướng phát triển

- Bổ sung auth guard cho route.
- Chuẩn hóa điều hướng về GoRouter.
- Hoàn thiện category filter cho Statistics.
- Rà soát và chuẩn hóa init flow cho Pref/Service chạy nền.
- Tăng độ phủ test cho usecase và bloc theo từng feature.

## 12. Tài liệu liên quan

- ARCHITECTURE.md: mô tả kiến trúc và luồng xử lý chi tiết.

---

Nếu bạn muốn, có thể mở rộng README này thêm các phần:
- Quy ước coding trong dự án
- Chiến lược test (unit/widget/integration)
- CI/CD mẫu cho Flutter
