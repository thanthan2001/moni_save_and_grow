import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/configs/app_colors.dart';
import '../../../../core/routing/app_back_scope.dart';
import '../../../../global/widgets/widgets.dart';
import '../../domain/entities/category_entity.dart';
import '../bloc/category_bloc.dart';
import '../bloc/category_event.dart';
import '../bloc/category_state.dart';

/// Màn hình danh sách categories
class CategoryListPage extends StatefulWidget {
  const CategoryListPage({super.key});

  @override
  State<CategoryListPage> createState() => _CategoryListPageState();
}

class _CategoryListPageState extends State<CategoryListPage> {
  @override
  void initState() {
    super.initState();
    context.read<CategoryBloc>().add(const LoadCategories());
  }

  @override
  Widget build(BuildContext context) {
    return AppBackScope(
      child: Scaffold(
        appBar: AppBar(
          title: AppText.heading4('Quản lý nhóm'),
        elevation: 0,
      ),
      body: BlocConsumer<CategoryBloc, CategoryState>(
        listener: (context, state) {
          if (state is CategoryActionSuccess) {
            AppSnackBar.showSuccess(context, state.message);
          } else if (state is CategoryError) {
            AppSnackBar.showError(context, state.message);
          }
        },
        builder: (context, state) {
          if (state is CategoryLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is CategoryError && state is! CategoryLoaded) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 64, color: AppColors.red),
                  const SizedBox(height: 16),
                  AppText.body(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      context.read<CategoryBloc>().add(const LoadCategories());
                    },
                    icon: const Icon(Icons.refresh),
                    label: AppText.label('Thử lại'),
                  ),
                ],
              ),
            );
          }

          if (state is CategoryLoaded) {
            return _buildCategoryGrid(context, state.categories);
          }

          return  Center(child: AppText.body('Kéo xuống để tải dữ liệu'));
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await context.push('/categories/add');
          if (result == true && mounted) {
            context.read<CategoryBloc>().add(const RefreshCategories());
          }
        },
        icon: const Icon(Icons.add),
        label: AppText.label('Thêm nhóm'),
      ),
    ));
  }

  Widget _buildCategoryGrid(
      BuildContext context, List<CategoryEntity> categories) {
    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            AppText.heading4('Chưa có nhóm nào', color: Colors.grey[600]),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<CategoryBloc>().add(const RefreshCategories());
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.85,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return _buildCategoryCard(context, category);
        },
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, CategoryEntity category) {
    return InkWell(
      onTap: () async {
        final result = await context.push('/categories/edit', extra: category);
        if (result == true && mounted) {
          context.read<CategoryBloc>().add(const RefreshCategories());
        }
      },
      onLongPress: () => _showDeleteDialog(context, category),
      borderRadius: BorderRadius.circular(16),
      child: AppCard(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: category.color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                category.icon,
                color: category.color,
                size: 30,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: AppText.bodySmall(
                category.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: category.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: AppText.overline(
                category.type == TransactionCategoryType.income
                    ? 'Thu'
                    : category.type == TransactionCategoryType.expense
                        ? 'Chi'
                        : 'Cả hai',
                color: category.color,
              ),
            ),
          ],
        ),
      ),
    );

  }

  Future<void> _showDeleteDialog(
      BuildContext context, CategoryEntity category) async {
    final confirmed = await AppDialog.showConfirm(
      context: context,
      title: 'Xác nhận xóa',
      message: 'Bạn có chắc muốn xóa nhóm "${category.name}"?',
      confirmText: 'Xóa',
      cancelText: 'Hủy',
      isDanger: true,
    );

    if (confirmed == true && mounted) {
      context.read<CategoryBloc>().add(DeleteCategory(id: category.id));
    }
  }
}
