import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/home/presentation/pages/features_page.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import '../../features/transaction/presentation/pages/transaction_list_page.dart';
import '../../features/transaction/presentation/pages/add_edit_transaction_page.dart';
import '../../features/transaction/domain/entities/transaction_entity.dart';
import '../../features/category/presentation/pages/category_list_page.dart';
import '../../features/category/presentation/pages/add_edit_category_page.dart';
import '../../features/category/domain/entities/category_entity.dart';
import '../../features/statistics/presentation/pages/statistics_screen.dart';
import '../../features/settings/presentation/pages/settings_screen.dart';
import '../../features/budget/presentation/pages/budget_management_page.dart';
import '../../features/spending_limit/presentation/pages/spending_limit_settings_page.dart';
import '../../features/recurring_transaction/presentation/pages/recurring_transaction_list_page.dart';
import '../../features/backup/presentation/pages/backup_screen.dart';
import '../../features/ai_assistant/presentation/pages/ai_assistant_page.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/features',
        builder: (context, state) => const FeaturesPage(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardPage(),
      ),
      GoRoute(
        path: '/transactions',
        builder: (context, state) => const TransactionListPage(),
      ),
      GoRoute(
        path: '/transactions/add',
        builder: (context, state) => const AddEditTransactionPage(),
      ),
      GoRoute(
        path: '/transactions/edit',
        builder: (context, state) {
          final transaction = state.extra as TransactionEntity?;
          return AddEditTransactionPage(transaction: transaction);
        },
      ),
      GoRoute(
        path: '/categories',
        builder: (context, state) => const CategoryListPage(),
      ),
      GoRoute(
        path: '/categories/add',
        builder: (context, state) => const AddEditCategoryPage(),
      ),
      GoRoute(
        path: '/categories/edit',
        builder: (context, state) {
          final category = state.extra as CategoryEntity?;
          return AddEditCategoryPage(category: category);
        },
      ),
      GoRoute(
        path: '/statistics',
        builder: (context, state) => const StatisticsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/budgets',
        builder: (context, state) => const BudgetManagementPage(),
      ),
      GoRoute(
        path: '/spending-limit',
        builder: (context, state) => const SpendingLimitSettingsPage(),
      ),
      GoRoute(
        path: '/recurring-transactions',
        builder: (context, state) => const RecurringTransactionListPage(),
      ),
      GoRoute(
        path: '/backup',
        builder: (context, state) => const BackupScreen(),
      ),
      GoRoute(
        path: '/ai-assistant',
        builder: (context, state) => const AiAssistantPage(),
      ),
    ],
  );
}
