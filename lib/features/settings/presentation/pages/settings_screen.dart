import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/app_back_scope.dart';
import '../../../../core/configs/app_colors.dart';
import '../../../../global/widgets/widgets.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';
import 'dart:async';

/// Màn hình Cài đặt
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBackScope(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => AppBackScope.handleBack(context),
          ),
          title: AppText.heading4('Cài đặt'),
          centerTitle: true,
        ),
        body: BlocListener<SettingsBloc, SettingsState>(
          listener: (context, state) {
            if (state is TransactionsCleared) {
              AppSnackBar.showSuccess(context, 'Đã xóa toàn bộ giao dịch');
              // Navigate back to previous screen
              Future.microtask(() {
                if (context.mounted) {
                  context.pop();
                }
              });
            } else if (state is ClearTransactionsError) {
              AppSnackBar.showError(context, 'Lỗi: ${state.message}');
            }
          },
          child: BlocBuilder<SettingsBloc, SettingsState>(
            builder: (context, state) {
              return ListView(
                children: [
                  // Thông tin ứng dụng
                  _buildAppInfoSection(context),

                  const Divider(height: 1),

                  // Quản lý dữ liệu
                  _buildDataManagementSection(context, state),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Section thông tin ứng dụng
  Widget _buildAppInfoSection(BuildContext context) {
    return ExpansionTile(
      leading: const Icon(Icons.info_outline, color: Colors.blue),
      title: AppText.label('Thông tin ứng dụng'),
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Logo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.account_balance_wallet,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),

              // Tên app
              AppText.heading1('MONI'),
              const SizedBox(height: 4),

              // Slogan
              AppText.bodySmall('Save & Grow', color: Colors.grey[600]),
              const SizedBox(height: 8),

              // Phiên bản
              AppText.bodySmall('Phiên bản 1.0.0', color: Colors.grey[600]),
              const SizedBox(height: 16),

              // Thông tin thêm
              _buildInfoRow('Tác giả', 'Thân Thân'),
              const SizedBox(height: 8),
              _buildInfoRow('Liên hệ', 'tranvanbethan2001@gmail.com'),
            ],
          ),
        ),
      ],
    );
  }

  /// Widget hiển thị thông tin dạng row
  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        AppText.bodySmall(label, color: Colors.grey),
        AppText.bodySmall(value, color: Colors.grey.shade800),
      ],
    );
  }

  /// Section quản lý dữ liệu
  Widget _buildDataManagementSection(
      BuildContext context, SettingsState state) {
    final isLoading = state is ClearingTransactions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: AppText.caption('Quản lý dữ liệu', color: Colors.grey[600]),
        ),
        // Backup & Restore - Navigate to dedicated page
        AppListTile.navigation(
          icon: Icons.backup_outlined,
          iconColor: Colors.blueGrey,
          title: 'Sao lưu & Khôi phục',
          subtitle: 'Quản lý backup và restore dữ liệu',
          onTap: () => context.push('/backup'),
        ),
        
        // Spending Limit - Navigate to spending limit settings
        AppListTile.navigation(
          icon: Icons.payments_outlined,
          iconColor: Colors.orange,
          title: 'Giới hạn chi tiêu',
          subtitle: 'Thiết lập và theo dõi giới hạn chi tiêu',
          onTap: () => context.push('/spending-limit'),
        ),
    
      
        // Nút xóa toàn bộ dữ liệu
        AppListTile(
          leading: Icon(
            Icons.delete_sweep,
            color: isLoading ? Colors.grey : AppColors.red,
          ),
          title: AppText.label(
            'Xóa toàn bộ dữ liệu giao dịch',
            color: isLoading ? Colors.grey : AppColors.red,
          ),
          subtitle: AppText.caption(
            'Xóa tất cả giao dịch đã lưu (không thể hoàn tác)',
          ),
          trailing: isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chevron_right),
          enabled: !isLoading,
          onTap: () => _showClearDataDialog(context),
        ),


      ],
    );
  }

  /// Hiển thị dialog xác nhận xóa dữ liệu
  void _showClearDataDialog(BuildContext context) {
    AppDialog.showConfirm(
      context: context,
      title: 'Xác nhận xóa',
      message:
          'Bạn có chắc chắn muốn xóa toàn bộ dữ liệu giao dịch không? Hành động này không thể hoàn tác.',
      confirmText: 'Xóa',
      cancelText: 'Hủy',
      isDanger: true,
    ).then((confirmed) {
      if (confirmed == true) {
        context.read<SettingsBloc>().add(const ClearAllTransactionsEvent());
      }
    });
  }
}
