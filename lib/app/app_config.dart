import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_clean_app/core/routing/app_router.dart';
import 'package:my_clean_app/core/theme/app_theme.dart';
import 'package:my_clean_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:my_clean_app/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:my_clean_app/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:my_clean_app/features/category/presentation/bloc/category_bloc.dart';
import 'package:my_clean_app/features/statistics/presentation/bloc/statistics_bloc.dart';
import 'package:my_clean_app/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:my_clean_app/features/budget/presentation/bloc/budget_bloc.dart';
import 'package:my_clean_app/features/recurring_transaction/presentation/bloc/recurring_transaction_bloc.dart';
import 'package:my_clean_app/features/ai_assistant/presentation/bloc/ai_assistant_bloc.dart';
import 'package:my_clean_app/core/di/injection_container.dart' as di;

class AppConfig extends StatelessWidget {
  const AppConfig({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => di.sl<AuthBloc>(),
        ),
        BlocProvider<DashboardBloc>(
          create: (_) => di.sl<DashboardBloc>(),
        ),
        BlocProvider<TransactionBloc>(
          create: (_) => di.sl<TransactionBloc>(),
        ),
        BlocProvider<CategoryBloc>(
          create: (_) => di.sl<CategoryBloc>(),
        ),
        BlocProvider<StatisticsBloc>(
          create: (_) => di.sl<StatisticsBloc>(),
        ),
        BlocProvider<SettingsBloc>(
          create: (_) => di.sl<SettingsBloc>(),
        ),
        BlocProvider<BudgetBloc>(
          create: (_) => di.sl<BudgetBloc>(),
        ),
        BlocProvider<RecurringTransactionBloc>(
          create: (_) => di.sl<RecurringTransactionBloc>(),
        ),
        BlocProvider<AiAssistantBloc>(
          create: (_) => di.sl<AiAssistantBloc>(),
        ),
      ],
      child: MaterialApp.router(
        title: 'MONI - Save & Grow',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: AppRouter.router,
      ),
    );
  }
}
