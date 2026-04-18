import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/configs/app_colors.dart';
import '../../../../core/routing/app_back_scope.dart';
import '../../../../global/widgets/widgets.dart';
import '../../../category/domain/entities/category_entity.dart';
import '../../domain/entities/transaction_entity.dart';
import '../bloc/transaction_bloc.dart';
import '../bloc/transaction_event.dart';
import '../bloc/transaction_state.dart';

/// Màn hình danh sách giao dịch
class TransactionListPage extends StatefulWidget {
  const TransactionListPage({super.key});

  @override
  State<TransactionListPage> createState() => _TransactionListPageState();
}

class _TransactionListPageState extends State<TransactionListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  DateTime? _selectedDate;
  String? _typeFilter; // 'income', 'expense', null = all

  @override
  void initState() {
    super.initState();
    // Load transactions khi mới vào
    context.read<TransactionBloc>().add(const LoadTransactions());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBackScope(
      child: Scaffold(
        appBar: AppBar(
          title: AppText.heading4('Giao dịch'),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              AppBackScope.handleBack(context);
            },
          ),
        ),
        body: BlocConsumer<TransactionBloc, TransactionState>(
          listener: (context, state) {
            // Hiển thị thông báo khi có action success/error
            if (state is TransactionActionSuccess) {
              AppSnackBar.showSuccess(context, state.message);
            } else if (state is TransactionError) {
              AppSnackBar.showError(context, state.message);
            }
          },
          builder: (context, state) {
            if (state is TransactionLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is TransactionError && state is! TransactionLoaded) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 64, color: AppColors.red),
                    const SizedBox(height: 16),
                    AppText.body(state.message),
                    const SizedBox(height: 16),
                    AppButton.primary(
                      text: 'Thử lại',
                      icon: Icons.refresh,
                      onPressed: () {
                        context
                            .read<TransactionBloc>()
                            .add(const LoadTransactions());
                      },
                    ),
                  ],
                ),
              );
            }

            if (state is TransactionLoaded) {
              return _buildTransactionList(context, state);
            }

            return Center(child: AppText.body('Kéo xuống để tải dữ liệu'));
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            // Navigate to add transaction screen
            final result = await context.push('/transactions/add');
            // Nếu có kết quả (đã thêm thành công), reload
            if (result == true && mounted) {
              context.read<TransactionBloc>().add(const RefreshTransactions());
            }
          },
          icon: const Icon(Icons.add),
          label: AppText.label('Thêm giao dịch'),
        ),
      ),
    );
  }

  /// Build danh sách transactions
  Widget _buildTransactionList(BuildContext context, TransactionLoaded state) {
    final transactions = state.transactions;
    final categories = state.categories;

    // Filter theo ngày
    var filteredTransactions = _filterByDate(transactions);

    // Filter theo loại (Thu/Chi)
    if (_typeFilter != null) {
      filteredTransactions = filteredTransactions.where((transaction) {
        if (_typeFilter == 'income') {
          return transaction.type == TransactionType.income;
        } else if (_typeFilter == 'expense') {
          return transaction.type == TransactionType.expense;
        }
        return true;
      }).toList();
    }

    // Filter theo search query
    if (_searchQuery.isNotEmpty) {
      filteredTransactions = filteredTransactions.where((transaction) {
        final description = transaction.description.toLowerCase();
        return description.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Tạo map để lookup category dễ hơn
    final categoryMap = {for (var cat in categories) cat.id: cat};

    return Column(
      children: [
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: AppSearchInput(
            controller: _searchController,
            hintText: 'Tìm kiếm theo tên giao dịch...',
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
            onClear: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
          ),
        ),
        const SizedBox(height: 8),
        // Filter row: Thu - Chi - Lịch
        _buildFilterRow(),
        const SizedBox(height: 8),

        const Divider(height: 1),

        // List transactions
        Expanded(
          child: filteredTransactions.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: () async {
                    context
                        .read<TransactionBloc>()
                        .add(const RefreshTransactions());
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredTransactions.length,
                    itemBuilder: (context, index) {
                      final transaction = filteredTransactions[index];
                      final category = categoryMap[transaction.categoryId];
                      return _buildTransactionItem(
                        context,
                        transaction,
                        category,
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  /// Build filter row với Thu, Chi, và Lịch
  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Thu button
          Expanded(
            child: _buildTypeFilterButton(
              label: 'Thu',
              icon: Icons.arrow_downward,
              color: AppColors.green,
              type: 'income',
            ),
          ),
          const SizedBox(width: 8),
          // Chi button
          Expanded(
            child: _buildTypeFilterButton(
              label: 'Chi',
              icon: Icons.arrow_upward,
              color: AppColors.red,
              type: 'expense',
            ),
          ),
          const SizedBox(width: 8),
          // Calendar button
          Expanded(
            flex: 2,
            child: _buildCalendarButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeFilterButton({
    required String label,
    required IconData icon,
    required Color color,
    required String type,
  }) {
    final isSelected = _typeFilter == type;

    return InkWell(
      onTap: () {
        setState(() {
          _typeFilter = isSelected ? null : type;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : null,
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 4),
            AppText.bodySmall(
              label,
              color: color,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarButton() {
    return InkWell(
      onTap: _showDatePicker,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today,
              size: 18,
              color: _selectedDate != null
                  ? Theme.of(context).primaryColor
                  : Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Flexible(
              child: AppText.bodySmall(
                _selectedDate != null
                    ? DateFormat('dd/MM/yy').format(_selectedDate!)
                    : 'Lịch',
                color: _selectedDate != null
                    ? Theme.of(context).primaryColor
                    : Colors.grey[600],
                fontWeight:
                    _selectedDate != null ? FontWeight.bold : FontWeight.normal,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_selectedDate != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = null;
                  });
                },
                child: Icon(
                  Icons.clear,
                  size: 16,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build calendar filter
  // Widget _buildCalendarFilter() {
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(horizontal: 16),
  //     child: InkWell(
  //       onTap: _showDatePicker,
  //       borderRadius: BorderRadius.circular(12),
  //       child: Container(
  //         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  //         decoration: BoxDecoration(
  //           border: Border.all(color: Colors.grey[300]!),
  //           borderRadius: BorderRadius.circular(12),
  //         ),
  //         child: Row(
  //           children: [
  //             const Icon(Icons.calendar_today, size: 20),
  //             const SizedBox(width: 12),
  //             Expanded(
  //               child: AppText.body(
  //                 _selectedDate != null
  //                   ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
  //                   : 'Xem tất cả giao dịch',
  //               ),
  //             ),
  //             if (_selectedDate != null)
  //               GestureDetector(
  //                 onTap: () {
  //                   setState(() {
  //                     _selectedDate = null;
  //                   });
  //                 },
  //                 child: const Padding(
  //                   padding: EdgeInsets.all(4.0),
  //                   child: Icon(Icons.clear, size: 20),
  //                 ),
  //               )
  //             else
  //               const Icon(Icons.arrow_drop_down),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }

  /// Show date picker
  Future<void> _showDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  /// Filter transactions by selected date
  List<TransactionEntity> _filterByDate(List<TransactionEntity> transactions) {
    if (_selectedDate == null) {
      return transactions;
    }

    final startDate =
        DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
    final endDate = DateTime(_selectedDate!.year, _selectedDate!.month,
        _selectedDate!.day, 23, 59, 59);

    return transactions.where((transaction) {
      return transaction.date
              .isAfter(startDate.subtract(const Duration(seconds: 1))) &&
          transaction.date.isBefore(endDate.add(const Duration(seconds: 1)));
    }).toList();
  }

  /// Build transaction item
  Widget _buildTransactionItem(
    BuildContext context,
    TransactionEntity transaction,
    CategoryEntity? category,
  ) {
    final isIncome = transaction.type == TransactionType.income;
    final amountColor = isIncome ? AppColors.green : AppColors.red;
    final amountPrefix = isIncome ? '+' : '-';

    final formattedAmount = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    ).format(transaction.amount);

    final formattedDate = DateFormat('dd/MM/yyyy').format(transaction.date);

    return Dismissible(
      key: Key(transaction.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await AppDialog.showConfirm(
          context: context,
          title: 'Xác nhận xóa',
          message: 'Bạn có chắc muốn xóa giao dịch này?',
          confirmText: 'Xóa',
          cancelText: 'Hủy',
          isDanger: true,
        );
      },
      onDismissed: (direction) {
        context.read<TransactionBloc>().add(
              DeleteTransaction(id: transaction.id),
            );
      },
      child: AppCard(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () async {
            // Navigate to edit transaction screen
            final result = await context.push(
              '/transactions/edit',
              extra: transaction,
            );
            if (result == true && mounted) {
              context.read<TransactionBloc>().add(const RefreshTransactions());
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon category
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: category?.color.withOpacity(0.2) ?? Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    category?.icon ?? Icons.attach_money,
                    color: category?.color ?? Colors.grey,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText.bodySmall(category?.name ?? 'Khác',
                          color: Colors.grey),
                      const SizedBox(height: 4),
                      AppText.body(
                        transaction.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      AppText.caption(formattedDate),
                    ],
                  ),
                ),

                // Amount
                AppText.body(
                  '$amountPrefix$formattedAmount',
                  color: amountColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build empty state
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          AppText.heading4('Chưa có giao dịch nào', color: Colors.grey[600]),
          const SizedBox(height: 8),
          AppText.bodySmall('Nhấn nút + để thêm giao dịch mới',
              color: Colors.grey[500]),
        ],
      ),
    );
  }
}
