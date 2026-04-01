import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/routing/app_back_scope.dart';
import '../../../../global/widgets/widgets.dart';
import '../../../dashboard/data/datasources/dashboard_local_data_source.dart';
import '../../../category/domain/entities/category_entity.dart';
import '../../domain/entities/budget_status.dart';
import '../bloc/budget_bloc.dart';
import '../bloc/budget_event.dart';
import '../bloc/budget_state.dart';
import '../widgets/budget_progress_widget.dart';
import '../widgets/budget_alert_dialog.dart';
import 'add_edit_budget_page.dart';

/// Màn hình quản lý ngân sách
class BudgetManagementPage extends StatelessWidget {
  const BudgetManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => sl<BudgetBloc>()..add(const LoadBudgetStatuses()),
      child: const _BudgetManagementView(),
    );
  }
}

class _BudgetManagementView extends StatefulWidget {
  const _BudgetManagementView();

  @override
  State<_BudgetManagementView> createState() => _BudgetManagementViewState();
}

class _BudgetManagementViewState extends State<_BudgetManagementView> {
  List<CategoryEntity> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final dashboardDataSource = sl<DashboardLocalDataSource>();
      final categories = await dashboardDataSource.getAllCategories();
      setState(() {
        _categories = categories.map((m) => m.toEntity()).toList();
      });
    } catch (e) {
      // Handle error silently
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackScope(
      child: Scaffold(
      appBar: AppBar(
        title: AppText.heading4('Quản Lý Ngân Sách'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<BudgetBloc>().add(const LoadBudgetStatuses());
            },
          ),
        ],
      ),
      body: BlocConsumer<BudgetBloc, BudgetState>(
        listener: (context, state) {
          if (state is BudgetActionSuccess) {
            AppSnackBar.showSuccess(context, state.message);
            // Reload sau khi action success
            context.read<BudgetBloc>().add(const LoadBudgetStatuses());
          } else if (state is BudgetError) {
            AppSnackBar.showError(context, state.message);
          }
        },
        builder: (context, state) {
          if (state is BudgetLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is BudgetError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  AppText.body(state.message),
                  const SizedBox(height: 16),
                  AppButton.primary(
                    text: 'Thử lại',
                    onPressed: () {
                      context.read<BudgetBloc>().add(const LoadBudgetStatuses());
                    },
                  ),
                ],
              ),
            );
          }

          if (state is BudgetStatusesLoaded) {
            final statuses = state.statuses;

            if (statuses.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined,
                        size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    AppText.body('Chưa có ngân sách nào', color: Colors.grey),
                    const SizedBox(height: 8),
                    AppText.bodySmall('Nhấn nút + để thêm ngân sách mới',
                        color: Colors.grey),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                context.read<BudgetBloc>().add(const LoadBudgetStatuses());
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: statuses.length,
                itemBuilder: (context, index) {
                  final status = statuses[index];
                  final category = _categories.firstWhere(
                    (c) => c.id == status.categoryId,
                    orElse: () => const CategoryEntity(
                      id: '',
                      name: 'Unknown',
                      icon: Icons.help_outline,
                      color: Colors.grey,
                      type: TransactionCategoryType.expense,
                    ),
                  );

                  return Dismissible(
                    key: Key(status.budgetId),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      color: Colors.red,
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (direction) async {
                      return await AppDialog.showConfirm(
                        context: context,
                        title: 'Xác nhận xóa',
                        message:
                            'Bạn có chắc muốn xóa ngân sách cho "${category.name}"?',
                        confirmText: 'Xóa',
                        cancelText: 'Hủy',
                        isDanger: true,
                      );
                    },
                    onDismissed: (direction) {
                      context.read<BudgetBloc>().add(
                            DeleteBudget(budgetId: status.budgetId),
                          );
                    },
                    child: AppCard(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: InkWell(
                        onTap: () {
                          // Show alert dialog nếu có cảnh báo
                          if (status.alertLevel != BudgetAlertLevel.normal) {
                            showDialog(
                              context: context,
                              builder: (context) => BudgetAlertDialog(
                                status: status,
                                category: category,
                              ),
                            );
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: BudgetProgressWidget(
                            status: status,
                            category: category,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          }

          return  Center(child: AppText.body('Không có dữ liệu'));
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const AddEditBudgetPage(),
            ),
          );

          if (result == true && context.mounted) {
            context.read<BudgetBloc>().add(const LoadBudgetStatuses());
          }
        },
        child: const Icon(Icons.add),
      ),
    ));
  }
}
