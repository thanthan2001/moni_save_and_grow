import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/configs/app_colors.dart';
import '../../../../core/utils/currency_input_formatter.dart';
import '../../../../global/widgets/widgets.dart';
import '../../../category/domain/entities/category_entity.dart';
import '../../domain/entities/transaction_entity.dart';
import '../bloc/transaction_bloc.dart';
import '../bloc/transaction_event.dart';
import '../bloc/transaction_state.dart';

/// Màn hình thêm/sửa giao dịch
class AddEditTransactionPage extends StatefulWidget {
  final TransactionEntity? transaction; // null = add, not null = edit

  const AddEditTransactionPage({
    super.key,
    this.transaction,
  });

  @override
  State<AddEditTransactionPage> createState() => _AddEditTransactionPageState();
}

class _AddEditTransactionPageState extends State<AddEditTransactionPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  CategoryEntity? _selectedCategory;
  TransactionType _selectedType = TransactionType.expense;

  bool get isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();

    // Load transactions và categories nếu chưa có
    context.read<TransactionBloc>().add(const LoadTransactions());

    // Nếu đang edit, load data hiện tại
    if (isEditing) {
      // Format amount với dấu chấm phân cách
      final formatter = NumberFormat('#,###', 'vi_VN');
      _amountController.text =
          formatter.format(widget.transaction!.amount.toInt());
      _descriptionController.text = widget.transaction!.description;
      _selectedDate = widget.transaction!.date;
      _selectedType = widget.transaction!.type;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/dashboard');
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: AppText.heading4(isEditing ? 'Sửa giao dịch' : 'Thêm giao dịch'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/transactions');
            }
          },
        ),
      ),
      body: BlocConsumer<TransactionBloc, TransactionState>(
        listener: (context, state) {
          if (state is TransactionActionSuccess) {
            if (isEditing) {
              // Nếu đang edit, quay lại trang trước
              context.pop(true);
            } else {
              // Nếu thêm mới, pop về màn hình trước (không replace stack)
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/dashboard');
              }
            }
          } else if (state is TransactionError) {
            AppSnackBar.showError(context, state.message);
          }
        },
        builder: (context, state) {
          // Hiển thị loading khi đang load transactions/categories
          if (state is TransactionLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // Load categories từ state
          List<CategoryEntity> categories = [];
          if (state is TransactionLoaded) {
            categories = state.categories;

            // Set selected category nếu đang edit
            if (isEditing &&
                _selectedCategory == null &&
                categories.isNotEmpty) {
              _selectedCategory = categories.firstWhere(
                (c) => c.id == widget.transaction!.categoryId,
                orElse: () => categories.first,
              );
            }
          }

          // Nếu không có categories, hiển thị thông báo
          if (categories.isEmpty && state is! TransactionLoading) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.category_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    AppText.heading4('Chưa có nhóm nào',
                        color: Colors.grey[600]),
                    const SizedBox(height: 8),
                    AppText.bodySmall(
                      'Vui lòng tạo nhóm trước khi thêm giao dịch',
                      color: Colors.grey[500],
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    AppButton.primary(
                      text: 'Tạo nhóm mới',
                      icon: Icons.add,
                      onPressed: () {
                        context.pop();
                        context.push('/categories/add');
                      },
                    ),
                  ],
                ),
              ),
            );
          }

          // Biến loading state để xây dựng form
          final isLoading = state is TransactionActionInProgress;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Type selector (Thu/Chi)
                  _buildTypeSelector(),
                  const SizedBox(height: 24),

                  // Amount input
                  _buildAmountInput(),
                  const SizedBox(height: 16),

                  // Description input
                  _buildDescriptionInput(),
                  const SizedBox(height: 16),

                  // Date picker
                  _buildDatePicker(),
                  const SizedBox(height: 16),

                  // Category selector
                  _buildCategorySelector(categories),
                  const SizedBox(height: 32),

                  // Save button
                  _buildSaveButton(isLoading),
                ],
              ),
            ),
          );
        },
      ),
    ));
  }

  /// Build type selector (Thu/Chi)
  Widget _buildTypeSelector() {
    return AppCard.padded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText.label('Loại giao dịch'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: RadioListTile<TransactionType>(
                  value: TransactionType.income,
                  groupValue: _selectedType,
                  onChanged: (value) {
                    setState(() {
                      _selectedType = value!;
                      _selectedCategory = null; // Reset category
                    });
                  },
                  title: Row(
                    children: [
                      const Icon(Icons.arrow_downward,
                          color: AppColors.green, size: 20),
                      const SizedBox(width: 8),
                      AppText.body('Thu'),
                    ],
                  ),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              Expanded(
                child: RadioListTile<TransactionType>(
                  value: TransactionType.expense,
                  groupValue: _selectedType,
                  onChanged: (value) {
                    setState(() {
                      _selectedType = value!;
                      _selectedCategory = null; // Reset category
                    });
                  },
                  title: Row(
                    children: [
                      const Icon(Icons.arrow_upward,
                          color: AppColors.red, size: 20),
                      const SizedBox(width: 8),
                      AppText.body('Chi'),
                    ],
                  ),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build amount input
  Widget _buildAmountInput() {
    return AppInput(
      controller: _amountController,
      labelText: 'Số tiền',
      prefixIcon: Icons.attach_money,
      suffixText: 'đ',
      hintText: 'Ví dụ: 2.000.000',
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        CurrencyInputFormatter(), // Format số tiền với dấu chấm
      ],
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Vui lòng nhập số tiền';
        }
        // Lấy giá trị số từ formatted text
        final amount = CurrencyInputFormatter.getNumericValue(value);
        if (amount == null || amount <= 0) {
          return 'Số tiền phải lớn hơn 0';
        }
        return null;
      },
    );
  }

  /// Build description input
  Widget _buildDescriptionInput() {
    return AppInput(
      controller: _descriptionController,
      labelText: 'Mô tả',
      prefixIcon: Icons.description,
      maxLines: 2,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Vui lòng nhập mô tả';
        }
        return null;
      },
    );
  }

  /// Build date picker
  Widget _buildDatePicker() {
    final formattedDate = DateFormat('dd/MM/yyyy').format(_selectedDate);

    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) {
          setState(() {
            _selectedDate = picked;
          });
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Ngày giao dịch',
          prefixIcon: const Icon(Icons.calendar_today),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: AppText.body(formattedDate),
      ),
    );
  }

  /// Build category selector
  Widget _buildCategorySelector(List<CategoryEntity> categories) {
    // Filter categories theo type
    final filteredCategories = categories.where((cat) {
      if (_selectedType == TransactionType.income) {
        return cat.type == TransactionCategoryType.income ||
            cat.type == TransactionCategoryType.both;
      } else {
        return cat.type == TransactionCategoryType.expense ||
            cat.type == TransactionCategoryType.both;
      }
    }).toList();

    if (filteredCategories.isEmpty) {
      return  AppCard.padded(
        child: AppText.body('Chưa có nhóm nào'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText.label('Chọn nhóm'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: filteredCategories.map((category) {
            final isSelected = _selectedCategory?.id == category.id;
            return FilterChip(
              selected: isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    category.icon,
                    size: 18,
                    color: isSelected ? Colors.white : category.color,
                  ),
                  const SizedBox(width: 4),
                  AppText.bodySmall(category.name),
                ],
              ),
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = category;
                });
              },
              selectedColor: category.color,
              backgroundColor: category.color.withOpacity(0.1),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              checkmarkColor: Colors.white,
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Build save button
  Widget _buildSaveButton(bool isLoading) {
    return AppButton.primary(
      text: isEditing ? 'Cập nhật' : 'Lưu',
      onPressed: isLoading ? null : _handleSave,
      isLoading: isLoading,
      width: double.infinity,
    );
  }

  /// Handle save
  void _handleSave() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategory == null) {
      AppSnackBar.showWarning(context, 'Vui lòng chọn nhóm');
      return;
    }

    // Parse amount từ formatted text (2.000.000 -> 2000000)
    final amount =
        CurrencyInputFormatter.getNumericValue(_amountController.text) ?? 0;
    final description = _descriptionController.text;

    final transaction = TransactionEntity(
      id: isEditing
          ? widget.transaction!.id
          : DateTime.now().millisecondsSinceEpoch.toString(),
      amount: amount,
      description: description,
      date: _selectedDate,
      categoryId: _selectedCategory!.id,
      type: _selectedType,
    );

    if (isEditing) {
      context
          .read<TransactionBloc>()
          .add(UpdateTransaction(transaction: transaction));
    } else {
      context
          .read<TransactionBloc>()
          .add(AddTransaction(transaction: transaction));
    }
  }
}
