import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/app_back_scope.dart';
import '../../../../global/widgets/widgets.dart';
import '../../domain/entities/category_entity.dart';
import '../bloc/category_bloc.dart';
import '../bloc/category_event.dart';
import '../bloc/category_state.dart';
import '../widgets/color_picker_dialog.dart';
import '../widgets/icon_picker_dialog.dart';

/// Màn hình thêm/sửa category
class AddEditCategoryPage extends StatefulWidget {
  final CategoryEntity? category;

  const AddEditCategoryPage({super.key, this.category});

  @override
  State<AddEditCategoryPage> createState() => _AddEditCategoryPageState();
}

class _AddEditCategoryPageState extends State<AddEditCategoryPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  IconData? _selectedIcon;
  Color _selectedColor = Colors.blue;
  TransactionCategoryType _selectedType = TransactionCategoryType.expense;

  bool get isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _nameController.text = widget.category!.name;
      _selectedIcon = widget.category!.icon;
      _selectedColor = widget.category!.color;
      _selectedType = widget.category!.type;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBackScope(
      child: Scaffold(
      appBar: AppBar(
        title: AppText.heading4(isEditing ? 'Sửa nhóm' : 'Thêm nhóm'),
        elevation: 0,
      ),
      body: BlocConsumer<CategoryBloc, CategoryState>(
        listener: (context, state) {
          if (state is CategoryActionSuccess) {
            context.pop(true);
          } else if (state is CategoryError) {
            AppSnackBar.showError(context, state.message);
          }
        },
        builder: (context, state) {
          final isLoading = state is CategoryActionInProgress;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Preview card
                  _buildPreviewCard(),
                  const SizedBox(height: 24),

                  // Name input
                  AppInput(
                    controller: _nameController,
                    labelText: 'Tên nhóm',
                    prefixIcon: Icons.label,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng nhập tên nhóm';
                      }
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),

                  // Type selector
                  _buildTypeSelector(),
                  const SizedBox(height: 16),

                  // Icon selector
                  _buildIconSelector(),
                  const SizedBox(height: 16),

                  // Color selector
                  _buildColorSelector(),
                  const SizedBox(height: 32),

                  // Save button
                  AppButton.primary(
                    text: isEditing ? 'Cập nhật' : 'Lưu',
                    isLoading: isLoading,
                    onPressed: isLoading ? null : _handleSave,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ));
  }

  Widget _buildPreviewCard() {
    return AppCard.padded(
      elevation: 2,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          AppText.caption('Xem trước'),
          const SizedBox(height: 16),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _selectedColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _selectedIcon ?? Icons.help_outline,
              color: _selectedColor,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          AppText.heading4(
            _nameController.text.isEmpty ? 'Tên nhóm' : _nameController.text,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _selectedColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: AppText.caption(
              _selectedType == TransactionCategoryType.income
                  ? 'Thu nhập'
                  : _selectedType == TransactionCategoryType.expense
                      ? 'Chi tiêu'
                      : 'Cả hai',
              color: _selectedColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector() {
    return AppCard.padded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText.label('Loại nhóm'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: RadioListTile<TransactionCategoryType>(
                  value: TransactionCategoryType.income,
                  groupValue: _selectedType,
                  onChanged: (value) {
                    setState(() {
                      _selectedType = value!;
                    });
                  },
                  title: AppText.body('Thu'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              Expanded(
                child: RadioListTile<TransactionCategoryType>(
                  value: TransactionCategoryType.expense,
                  groupValue: _selectedType,
                  onChanged: (value) {
                    setState(() {
                      _selectedType = value!;
                    });
                  },
                  title: AppText.body('Chi'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              Expanded(
                child: RadioListTile<TransactionCategoryType>(
                  value: TransactionCategoryType.both,
                  groupValue: _selectedType,
                  onChanged: (value) {
                    setState(() {
                      _selectedType = value!;
                    });
                  },
                  title: AppText.body('Cả 2'),
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

  Widget _buildIconSelector() {
    return InkWell(
      onTap: () async {
        final icon = await showDialog<IconData>(
          context: context,
          builder: (context) => IconPickerDialog(selectedIcon: _selectedIcon),
        );
        if (icon != null) {
          setState(() {
            _selectedIcon = icon;
          });
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Icon',
          prefixIcon: const Icon(Icons.emoji_emotions),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          children: [
            if (_selectedIcon != null) ...[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _selectedColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_selectedIcon, color: _selectedColor),
              ),
              const SizedBox(width: 12),
            ],
            AppText.body(
              _selectedIcon == null ? 'Chọn icon' : 'Đã chọn icon',
              color: _selectedIcon == null ? Colors.grey : Colors.black,
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildColorSelector() {
    return InkWell(
      onTap: () async {
        final color = await showDialog<Color>(
          context: context,
          builder: (context) =>
              ColorPickerDialog(selectedColor: _selectedColor),
        );
        if (color != null) {
          setState(() {
            _selectedColor = color;
          });
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Màu sắc',
          prefixIcon: const Icon(Icons.palette),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _selectedColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: _selectedColor.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AppText.body('Đã chọn màu'),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }

  void _handleSave() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedIcon == null) {
      AppSnackBar.showWarning(context, 'Vui lòng chọn icon');
      return;
    }

    final category = CategoryEntity(
      id: isEditing
          ? widget.category!.id
          : DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      icon: _selectedIcon!,
      color: _selectedColor,
      type: _selectedType,
    );

    if (isEditing) {
      context.read<CategoryBloc>().add(UpdateCategory(category: category));
    } else {
      context.read<CategoryBloc>().add(AddCategory(category: category));
    }
  }
}
