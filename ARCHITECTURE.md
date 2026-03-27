## 1. Tổng quan hệ thống
- Mục tiêu app suy ra từ source: quản lý tài chính cá nhân (giao dịch thu/chi, danh mục, thống kê, ngân sách, giới hạn chi tiêu, giao dịch định kỳ, sao lưu/khôi phục). Dựa trên tên app "MONI - Save & Grow", các màn hình và feature trong `lib/features`.
- Module/feature chính: `auth`, `dashboard`, `transaction`, `category`, `statistics`, `budget`, `spending_limit`, `recurring_transaction`, `backup`, `settings`, `splash`, `home`.
- Màn hình chính tìm thấy:
  - `SplashPage`, `LoginPage`, `HomePage`, `DashboardPage`, `TransactionListPage`, `AddEditTransactionPage`, `CategoryListPage`, `AddEditCategoryPage`, `StatisticsScreen`, `SettingsScreen`, `FeaturesPage`, `BudgetManagementPage`, `AddEditBudgetPage`, `SpendingLimitSettingsPage`, `RecurringTransactionListPage`, `AddEditRecurringPage`, `BackupScreen`.

## 2. Kiến trúc tổng thể
- Clean Architecture: Có. Các feature đều tách `data` / `domain` / `presentation` trong `lib/features/*`.
- State management: Có dùng BLoC (`flutter_bloc`) và `BlocProvider`/`MultiBlocProvider`.
- Các layer và mapping:
  - Presentation: `lib/features/*/presentation`, `lib/global/widgets`, `lib/app`.
  - Domain: `lib/features/*/domain` (entities, repositories, usecases).
  - Data: `lib/features/*/data` (datasources, models, repositories).
  - Core: `lib/core` (routing, DI, storage, network, error, utils).
- Luồng dữ liệu thực tế (ví dụ tiêu biểu, dựa trên code):
  - Auth: `LoginPage` dispatch `LoginEvent` -> `AuthBloc` -> `LoginUsecase` -> `AuthRepositoryImpl` -> `AuthRemoteDataSource` (Dio POST `/login`) -> `UserModel` -> `AuthAuthenticated` -> `LoginPage` điều hướng `/home`.
  - Dashboard: `DashboardPage` dispatch `LoadDashboard` -> `DashboardBloc` -> `GetDashboardSummaryUseCase` -> `DashboardRepositoryImpl` -> `TransactionRepository` -> `TransactionLocalDataSourceImpl` (Hive) -> tổng hợp `DashboardSummary` -> UI.
  - Transactions: `TransactionListPage` dispatch `LoadTransactions` -> `TransactionBloc` -> `GetAllTransactionsUseCase` + `GetAllCategoriesUseCase` -> `TransactionRepositoryImpl` + `CategoryManagementRepositoryImpl` -> Hive -> `TransactionLoaded` -> UI.
  - Statistics: `StatisticsScreen` dispatch `LoadStatistics` -> `StatisticsBloc` -> `GetStatisticsSummaryUseCase` -> `StatisticsRepositoryImpl` -> `TransactionLocalDataSource` + `CategoryLocalDataSource` -> `StatisticsSummary` -> UI.
  - Budget/Spending Limit/Recurring: BLoC -> UseCase -> Repository -> Hive (box riêng hoặc dùng `DashboardLocalDataSource`) -> State -> UI.

## 3. Cấu trúc thư mục
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
- `lib/app`: bootstrap app, DI/init (`AppBinding`), cấu hình MaterialApp/router (`AppConfig`).
- `lib/core`: hệ tầng dùng chung (DI, routing, network, storage, error, theme, utils).
- `lib/features`: mỗi feature tách `data/domain/presentation` theo Clean Architecture.
- `lib/global`: widget/common UI và bloc observer dùng toàn app.

## 4. Luồng xử lý chính (App Flow)
### Splash / Init flow
1. `main.dart` gọi `runApp(const App())`.
2. `App` chạy `AppBinding.init()` trong `FutureBuilder` (init locale, load `.env`, DI `di.init()`).
3. `MaterialApp.router` dùng `AppRouter.router`, `initialLocation: '/'`.
4. `/` -> `SplashPage`. `SplashPage` delay 2s rồi `context.go('/dashboard')`.
5. Không thấy kiểm tra đăng nhập trong `SplashPage` (luôn vào Dashboard).

### Auth flow
1. `/login` -> `LoginPage`.
2. Nhấn Login -> `AuthBloc` nhận `LoginEvent`.
3. `AuthBloc` gọi `LoginUsecase` -> remote login -> emit `AuthAuthenticated` hoặc `AuthError`.
4. `LoginPage` lắng nghe `AuthAuthenticated` -> `context.go('/home')`.
5. `HomePage` có nút logout -> `context.go('/login')`.
6. Không tìm thấy flow tự động từ Splash sang Login hoặc guard route dựa trên trạng thái đăng nhập.

### Main flow
1. `/dashboard` -> `DashboardPage` load dữ liệu (`LoadDashboard`, load categories từ repository).
2. Bottom nav (`CustomBottomNavBar`) điều hướng:
   - `/transactions`, `/statistics`, `/transactions/add`, `/features`, `/settings`.
3. `FeaturesPage` dẫn đến: `/budgets`, `/spending-limit`, `/categories`, `/backup`.
4. Transaction flow:
   - `/transactions` -> list, FAB add `/transactions/add`, item -> `/transactions/edit` (extra: `TransactionEntity`).
5. Category flow:
   - `/categories` -> list, FAB `/categories/add`, item -> `/categories/edit` (extra: `CategoryEntity`).
6. Budget flow:
   - `/budgets` -> `BudgetManagementPage`, add/edit qua `Navigator.push(MaterialPageRoute)` tới `AddEditBudgetPage`.
7. Recurring flow:
   - `/recurring-transactions` -> list, add/edit qua `Navigator.push(MaterialPageRoute)` tới `AddEditRecurringPage`.

## 5. Routing & Navigation (GoRouter / Navigator)
- Routing library: `go_router` (`lib/core/routing/app_router.dart`).
- File định nghĩa routes: `C:\app_lhg\execute_flutter_app\lib\core\routing\app_router.dart`.
- Danh sách routes (GoRouter):
  - `/` -> `SplashPage`
  - `/login` -> `LoginPage`
  - `/home` -> `HomePage`
  - `/features` -> `FeaturesPage`
  - `/dashboard` -> `DashboardPage`
  - `/transactions` -> `TransactionListPage`
  - `/transactions/add` -> `AddEditTransactionPage`
  - `/transactions/edit` -> `AddEditTransactionPage(transaction: state.extra as TransactionEntity?)`
  - `/categories` -> `CategoryListPage`
  - `/categories/add` -> `AddEditCategoryPage`
  - `/categories/edit` -> `AddEditCategoryPage(category: state.extra as CategoryEntity?)`
  - `/statistics` -> `StatisticsScreen`
  - `/settings` -> `SettingsScreen`
  - `/budgets` -> `BudgetManagementPage`
  - `/spending-limit` -> `SpendingLimitSettingsPage`
  - `/recurring-transactions` -> `RecurringTransactionListPage`
  - `/backup` -> `BackupScreen`
- Điều hướng ngoài GoRouter:
  - `BudgetManagementPage` -> `AddEditBudgetPage` (MaterialPageRoute).
  - `RecurringTransactionListPage` -> `AddEditRecurringPage` (MaterialPageRoute).

### Chi tiết navigation theo màn hình
#### SplashPage
- → `/dashboard` sau `Future.delayed(2s)`.

#### LoginPage
- → `/home` khi `AuthBloc` emit `AuthAuthenticated`.

#### HomePage
- → `/login` khi nhấn icon logout.

#### DashboardPage
- → `/transactions/add` khi nhấn icon add trên AppBar; sau khi quay lại sẽ `RefreshDashboard`.
- → `/transactions`, `/statistics`, `/features`, `/settings`, `/transactions/add` qua `CustomBottomNavBar`.

#### FeaturesPage
- → `/budgets` khi chọn "Ngân sách".
- → `/spending-limit` khi chọn "Giới hạn chi tiêu".
- → `/categories` khi chọn "Nhóm".
- → `/backup` khi chọn "Sao lưu".
- Route `/statistics` bị comment trong UI (không điều hướng từ màn hình này).

#### TransactionListPage
- → `/transactions/add` khi nhấn FAB.
- → `/transactions/edit` khi nhấn item, truyền `extra: TransactionEntity`.
- Back: `context.pop()`.

#### AddEditTransactionPage
- → `context.pop(true)` khi cập nhật thành công.
- → `/transactions` khi thêm mới thành công.
- → `/categories/add` nếu chưa có category (nút "Tạo nhóm mới").
- Back: `context.pop()` nếu có thể, fallback `context.go('/transactions')`.

#### CategoryListPage
- → `/categories/add` khi nhấn FAB.
- → `/categories/edit` khi nhấn item, truyền `extra: CategoryEntity`.
- Back: `context.pop()`.

#### AddEditCategoryPage
- → `context.pop(true)` khi action thành công.

#### StatisticsScreen
- Back: `context.pop()`.

#### SettingsScreen
- → `/backup` (AppListTile "Sao lưu & Khôi phục").
- → `/spending-limit` (AppListTile "Giới hạn chi tiêu").
- Back: `context.pop()`.

#### BudgetManagementPage
- → `AddEditBudgetPage` (MaterialPageRoute) khi nhấn FAB.
- Xóa budget bằng Dismissible (không điều hướng).

#### AddEditBudgetPage
- → `Navigator.pop(true)` sau khi lưu.

#### SpendingLimitSettingsPage
- Không điều hướng sang màn hình khác (chỉ dialog).

#### RecurringTransactionListPage
- → `AddEditRecurringPage` (MaterialPageRoute) khi nhấn FAB hoặc tap item.
- Back: `context.pop()`.

#### AddEditRecurringPage
- → `Navigator.pop(true)` sau khi lưu.

#### BackupScreen
- Không điều hướng sang màn hình khác (chỉ tab + dialog/file picker).

## 6. BLoC / State Management
- Danh sách BLoC:
  - `AuthBloc` (LoginPage, HomePage đọc state).
  - `DashboardBloc` (DashboardPage).
  - `TransactionBloc` (TransactionListPage, AddEditTransactionPage).
  - `CategoryBloc` (CategoryListPage, AddEditCategoryPage).
  - `StatisticsBloc` (StatisticsScreen).
  - `SettingsBloc` (SettingsScreen).
  - `BudgetBloc` (BudgetManagementPage; AddEditBudgetPage dispatch SetBudget).
  - `SpendingLimitBloc` (SpendingLimitSettingsPage).
  - `RecurringTransactionBloc` (RecurringTransactionListPage; AddEditRecurringPage dispatch create/update).
- Event → State flow (tóm tắt từ code):
  - AuthBloc: `LoginEvent` → `AuthLoading` → `AuthAuthenticated` hoặc `AuthError`.
  - DashboardBloc: `LoadDashboard` → `DashboardLoading` → `DashboardLoaded` hoặc `DashboardError`. `ToggleTotalBalance` cập nhật `DashboardLoaded`.
  - TransactionBloc: `LoadTransactions` → `TransactionLoading` → `TransactionLoaded` hoặc `TransactionError`. `Add/Update/Delete` → `TransactionActionInProgress` → `TransactionActionSuccess` + reload.
  - CategoryBloc: `LoadCategories` → `CategoryLoading` → `CategoryLoaded` hoặc `CategoryError`. `Add/Update/Delete` → `CategoryActionInProgress` → `CategoryActionSuccess` + reload.
  - StatisticsBloc: `LoadStatistics` → `StatisticsLoading` → `StatisticsLoaded` hoặc `StatisticsError`. `ApplyFilter/Reset/Refresh` reload summary.
  - SettingsBloc: `ClearAllTransactionsEvent` → `ClearingTransactions` → `TransactionsCleared` hoặc `ClearTransactionsError`.
  - BudgetBloc: `LoadBudgets/LoadActiveBudgets/LoadBudgetStatuses` → `BudgetLoading` → `BudgetLoaded` hoặc `BudgetStatusesLoaded` hoặc `BudgetError`. `Set/Delete` → `BudgetActionInProgress` → `BudgetActionSuccess` + reload.
  - SpendingLimitBloc: `LoadSpendingLimit/LoadAllSpendingLimits` → `SpendingLimitLoading` → `SpendingLimitLoaded`/`AllSpendingLimitsLoaded` hoặc `SpendingLimitError`. `Set/Delete/Toggle` → `SpendingLimitActionInProgress` → `SpendingLimitActionSuccess` + reload.
  - RecurringTransactionBloc: `LoadRecurringTransactions` → `RecurringTransactionLoading` → `RecurringTransactionLoaded` hoặc `RecurringTransactionError`. `Create/Update/Activate/Deactivate/Delete` → `RecurringTransactionActionInProgress` → `RecurringTransactionActionSuccess` + reload. `ProcessPendingRecurring` → `RecurringTransactionProcessed` + reload.
- UI phản ứng với state:
  - Hầu hết màn hình dùng `BlocBuilder`/`BlocConsumer` để hiển thị loading, error, success snackbar và render dữ liệu từ state.

## 7. Data Layer
- Repository đang dùng:
  - Auth: `AuthRepositoryImpl` (remote via Dio).
  - Transaction: `TransactionRepositoryImpl` (local Hive + category repo).
  - Category: `CategoryManagementRepositoryImpl` (local Hive).
  - Dashboard: `DashboardRepositoryImpl` (tổng hợp từ TransactionRepository).
  - Statistics: `StatisticsRepositoryImpl` (TransactionLocalDataSource + CategoryLocalDataSource).
  - Budget: `BudgetRepositoryImpl` (Hive box `budgets` + `DashboardLocalDataSource` để lấy transactions theo thời gian).
  - SpendingLimit: `SpendingLimitRepositoryImpl` (Hive box `spending_limits` + `DashboardLocalDataSource`).
  - RecurringTransaction: `RecurringTransactionRepositoryImpl` (Hive box `recurring_transactions`).
  - Backup: `BackupRepositoryImpl` (Hive boxes transactions/categories/budgets/recurring). Cloud: `GoogleDriveBackupRepositoryImpl`.
- Data sources:
  - Local: `TransactionLocalDataSourceImpl`, `CategoryLocalDataSourceImpl`, `DashboardLocalDataSourceImpl` (Hive).
  - Remote: `AuthRemoteDataSourceImpl` (Dio POST `/login`).
  - Cloud: `GoogleDriveDataSource` (Google Sign-In + Drive API).
- API service: Dio được cấu hình trong `core/di/injection_container.dart` với `AppEnv.apiBaseUrl`.
- Model mapping: các model `*Model` map `toEntity()` / `fromEntity()` trong từng feature.

## 8. Đánh giá kiến trúc (ngắn gọn)
- Điểm tốt:
  - Feature tách lập rõ ràng theo Clean Architecture.
  - BLoC và UseCase tách biệt, DI bằng `get_it`.
  - Routing trung tâm bằng `GoRouter` với danh sách route rõ ràng.
- Điểm chưa rõ/thiếu/có thể cải thiện (dựa trên code):
  - `SplashPage` không kiểm tra đăng nhập và luôn đi `/dashboard`. Không thấy guard hoặc điều kiện auth trong routing.
  - `UserPref` dùng `PrefManager`, nhưng không tìm thấy chỉ gọi `PrefManager.init()` trong `AppBinding` hoặc DI.
  - `StatisticsScreen` mở filter bottom sheet nhưng truyền `categories: const []` (có comment TODO), nên filter theo category không có dữ liệu.
  - Điều hướng chưa thống nhất: một số màn hình dùng `GoRouter`, một số dùng `Navigator.push(MaterialPageRoute)`.
  - `RecurringTransactionService` comment nói gọi ở `main.dart`, nhưng không thấy gọi trong `main.dart`.
