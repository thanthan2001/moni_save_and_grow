import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/routing/app_back_scope.dart';
import '../../../../core/utils/currency_input_formatter.dart';
import '../../../../global/widgets/widgets.dart';
import '../../domain/entities/spending_limit_entity.dart';
import '../../domain/entities/spending_limit_status.dart';
import '../bloc/spending_limit_bloc.dart';
import '../bloc/spending_limit_event.dart';
import '../bloc/spending_limit_state.dart';
import '../widgets/spending_limit_progress_widget.dart';
import '../widgets/spending_limit_alert_dialog.dart';

/// Màn hình cài đặt giới hạn chi tiêu
class SpendingLimitSettingsPage extends StatelessWidget {
  const SpendingLimitSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => sl<SpendingLimitBloc>()
        ..add(const LoadAllSpendingLimits()),
      child: const _SpendingLimitSettingsView(),
    );
  }
}

class _SpendingLimitSettingsView extends StatefulWidget {
  const _SpendingLimitSettingsView();

  @override
  State<_SpendingLimitSettingsView> createState() =>
      _SpendingLimitSettingsViewState();
}

class _SpendingLimitSettingsViewState
    extends State<_SpendingLimitSettingsView> {
  
  final Map<SpendingLimitPeriod, SpendingLimitEntity?> _limits = {};
  final Map<SpendingLimitPeriod, SpendingLimitStatus?> _statuses = {};
  
  @override
  void initState() {
    super.initState();
    _loadLimits();
  }
  
  void _loadLimits() async {
    final bloc = context.read<SpendingLimitBloc>();
    
    // Load weekly limit
    bloc.add(const LoadSpendingLimit(period: SpendingLimitPeriod.weekly));
    
    // Delay nhỏ để tránh race condition
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Load monthly limit
    bloc.add(const LoadSpendingLimit(period: SpendingLimitPeriod.monthly));
  }
  
  @override
  Widget build(BuildContext context) {
    return AppBackScope(
      child: Scaffold(
      appBar: AppBar(
        title: AppText.heading4('Giới Hạn Chi Tiêu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<SpendingLimitBloc>().add(
                    const LoadAllSpendingLimits(),
                  );
            },
          ),
        ],
      ),
      body: BlocConsumer<SpendingLimitBloc, SpendingLimitState>(
        listener: (context, state) {
          if (state is SpendingLimitActionSuccess) {
            AppSnackBar.showSuccess(context, state.message);
            // Reload sau khi action success
            _loadLimits();
          } else if (state is SpendingLimitError) {
            AppSnackBar.showError(context, state.message);
          }
          
          // Update local cache khi có state mới
          if (state is SpendingLimitLoaded && state.limit != null) {
            setState(() {
              _limits[state.limit!.period] = state.limit;
              _statuses[state.limit!.period] = state.status;
            });
          }
        },
        builder: (context, state) {
          if (state is SpendingLimitLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is SpendingLimitError) {
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
                      context.read<SpendingLimitBloc>().add(
                            const LoadAllSpendingLimits(),
                          );
                    },
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Weekly Limit Section
                _buildLimitSection(
                  context,
                  period: SpendingLimitPeriod.weekly,
                  title: 'Giới Hạn Chi Tiêu Tuần',
                  icon: Icons.calendar_view_week,
                ),
                const SizedBox(height: 24),

                // Monthly Limit Section
                _buildLimitSection(
                  context,
                  period: SpendingLimitPeriod.monthly,
                  title: 'Giới Hạn Chi Tiêu Tháng',
                  icon: Icons.calendar_month,
                ),
              ],
            ),
          );
        },
      ),
    ));
  }

  Widget _buildLimitSection(
    BuildContext context, {
    required SpendingLimitPeriod period,
    required String title,
    required IconData icon,
  }) {
    // Lấy data từ cache thay vì dispatch event
    final limit = _limits[period];
    final status = _statuses[period];
    final isActive = limit?.isActive ?? false;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppText.heading5(title),
                    ),
                    Switch(
                      value: isActive,
                      onChanged: (value) {
                        if (limit != null) {
                          context.read<SpendingLimitBloc>().add(
                                ToggleSpendingLimitActive(
                                  period: period,
                                  isActive: value,
                                ),
                              );
                        } else {
                          // Nếu chưa có limit, mở dialog để tạo
                          _showSetLimitDialog(context, period);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (limit != null && isActive) ...[
                  // Show progress
                  if (status != null)
                    SpendingLimitProgressWidget(status: status),

                  const SizedBox(height: 16),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: AppButton.secondary(
                          text: 'Chỉnh sửa',
                          onPressed: () => _showSetLimitDialog(
                            context,
                            period,
                            currentLimit: limit,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppButton.secondary(
                          text: 'Xóa',
                          onPressed: () => _showDeleteConfirmDialog(
                            context,
                            period,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Center(
                    child: Column(
                      children: [
                        AppText.bodySmall(
                          'Chưa thiết lập giới hạn',
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 12),
                        AppButton.primary(
                          text: 'Thiết lập giới hạn',
                          onPressed: () => _showSetLimitDialog(context, period),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
  }

  void _showSetLimitDialog(
    BuildContext context,
    SpendingLimitPeriod period, {
    SpendingLimitEntity? currentLimit,
  }) {
    final formatter = NumberFormat('#,###', 'vi_VN');
    final amountController = TextEditingController(
      text: currentLimit != null 
          ? formatter.format(currentLimit.amount.toInt())
          : '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: AppText.heading5(
          currentLimit == null ? 'Thiết lập giới hạn' : 'Chỉnh sửa giới hạn',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppText.bodySmall(
              'Chu kỳ: ${period.label}',
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Số tiền giới hạn',
                suffixText: 'đ',
                border: OutlineInputBorder(),
                hintText: 'Ví dụ: 1.000.000',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: AppText.body('Hủy'),
          ),
          TextButton(
            onPressed: () {
              final amount = CurrencyInputFormatter.getNumericValue(
                amountController.text,
              );
              if (amount == null || amount <= 0) {
                AppSnackBar.showError(
                  context,
                  'Vui lòng nhập số tiền hợp lệ',
                );
                return;
              }

              final limit = SpendingLimitEntity(
                id: currentLimit?.id ?? const Uuid().v4(),
                amount: amount,
                period: period,
                startDate: currentLimit?.startDate ?? DateTime.now(),
                isActive: true,
              );

              context.read<SpendingLimitBloc>().add(
                    SetSpendingLimit(limit: limit),
                  );

              Navigator.of(dialogContext).pop();
            },
            child: AppText.body('Lưu'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(
    BuildContext context,
    SpendingLimitPeriod period,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => SpendingLimitAlertDialog(
        title: 'Xác nhận xóa',
        message: 'Bạn có chắc chắn muốn xóa giới hạn chi tiêu này?',
        onConfirm: () {
          context.read<SpendingLimitBloc>().add(
                DeleteSpendingLimit(period: period),
              );
          Navigator.of(dialogContext).pop();
        },
      ),
    );
  }
}
