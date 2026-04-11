import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/routing/app_back_scope.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/configs/app_colors.dart';
import '../../../../global/widgets/widgets.dart';
import '../../domain/entities/filter_options.dart';
import '../../domain/entities/statistics_summary.dart';
import '../bloc/statistics_bloc.dart';
import '../bloc/statistics_event.dart';
import '../bloc/statistics_state.dart';
import '../widgets/advanced_filter_bottom_sheet.dart';

/// Màn hình Statistics với 3 tabs: Tất cả, Tổng thu, Tổng chi
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Load statistics when screen opens
    context.read<StatisticsBloc>().add(const LoadStatistics());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBackScope(
      child: Scaffold(
        appBar: AppBar(
          title: AppText.heading4('Thống kê'),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => AppBackScope.handleBack(context),
          ),
          actions: [
            // Filter button
            IconButton(
              icon: const Icon(Icons.filter_alt_outlined),
              tooltip: 'Bộ lọc',
              onPressed: _showFilterBottomSheet,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Tất cả', icon: Icon(Icons.dashboard)),
              Tab(text: 'Tổng thu', icon: Icon(Icons.arrow_downward)),
              Tab(text: 'Tổng chi', icon: Icon(Icons.arrow_upward)),
            ],
          ),
        ),
        body: BlocBuilder<StatisticsBloc, StatisticsState>(
          builder: (context, state) {
            if (state is StatisticsLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is StatisticsError) {
              return _buildError(state.message);
            }

            if (state is StatisticsLoaded) {
              return TabBarView(
                controller: _tabController,
                children: [
                  _buildAllTab(state),
                  _buildIncomeTab(state),
                  _buildExpenseTab(state),
                ],
              );
            }

            return  Center(child: AppText.body('Kéo xuống để tải dữ liệu'));
          },
        ),
      ),
    );
  }

  /// Tab 1: Tất cả - Hiển thị tổng thu và tổng chi
  Widget _buildAllTab(StatisticsLoaded state) {
    final summary = state.summary;

    return RefreshIndicator(
      onRefresh: () async {
        context.read<StatisticsBloc>().add(const RefreshStatistics());
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter info
            _buildFilterInfo(state.activeFilter),
            const SizedBox(height: 16),

            // Summary cards
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Tổng Thu',
                    summary.totalIncome,
                    AppColors.green,
                    Icons.arrow_downward,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Tổng Chi',
                    summary.totalExpense,
                    AppColors.red,
                    Icons.arrow_upward,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Balance card
            _buildBalanceCard(summary.balance),
            const SizedBox(height: 20),

            // Combined chart (Thu vs Chi)
            if (summary.totalIncome > 0 || summary.totalExpense > 0) ...[
              AppText.heading4('Biểu đồ tổng quan'),
              const SizedBox(height: 16),
              _buildCombinedChart(summary),
            ] else
              _buildNoData(),
          ],
        ),
      ),
    );
  }

  /// Tab 2: Tổng thu - Chi tiết theo category
  Widget _buildIncomeTab(StatisticsLoaded state) {
    final summary = state.summary;

    return RefreshIndicator(
      onRefresh: () async {
        context.read<StatisticsBloc>().add(const RefreshStatistics());
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter info
            _buildFilterInfo(state.activeFilter),
            const SizedBox(height: 16),

            // Total income (big number in center)
            _buildTotalCard(
              'Tổng Thu Nhập',
              summary.totalIncome,
              AppColors.green,
              Icons.trending_up,
            ),
            const SizedBox(height: 20),

            // Category breakdown
            if (summary.incomeByCategory.isNotEmpty) ...[
              // Pie chart
              _buildCategoryPieChart(summary.incomeByCategory, AppColors.green),
              const SizedBox(height: 20),

              // Category list
              AppText.heading4('Chi tiết theo nhóm'),
              const SizedBox(height: 12),
              ...summary.incomeByCategory.map((cat) => _buildCategoryItem(cat)),
            ] else
              _buildNoData(),
          ],
        ),
      ),
    );
  }

  /// Tab 3: Tổng chi - Chi tiết theo category
  Widget _buildExpenseTab(StatisticsLoaded state) {
    final summary = state.summary;

    return RefreshIndicator(
      onRefresh: () async {
        context.read<StatisticsBloc>().add(const RefreshStatistics());
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter info
            _buildFilterInfo(state.activeFilter),
            const SizedBox(height: 16),

            // Total expense (big number in center)
            _buildTotalCard(
              'Tổng Chi Tiêu',
              summary.totalExpense,
              AppColors.red,
              Icons.trending_down,
            ),
            const SizedBox(height: 20),

            // Category breakdown
            if (summary.expenseByCategory.isNotEmpty) ...[
              // Pie chart
              _buildCategoryPieChart(summary.expenseByCategory, AppColors.red),
              const SizedBox(height: 20),

              // Category list
              AppText.heading4('Chi tiết theo nhóm'),
              const SizedBox(height: 12),
              ...summary.expenseByCategory
                  .map((cat) => _buildCategoryItem(cat)),
            ] else
              _buildNoData(),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterInfo(FilterOptions filter) {
    String filterText = '';
    switch (filter.dateMode) {
      case DateMode.day:
        filterText = DateFormat('dd/MM/yyyy').format(filter.singleDate!);
        break;
      case DateMode.month:
        filterText = 'Tháng ${filter.month}/${filter.year}';
        break;
      case DateMode.year:
        filterText = 'Năm ${filter.year}';
        break;
      case DateMode.range:
        filterText =
            '${DateFormat('dd/MM').format(filter.startDate!)} - ${DateFormat('dd/MM/yyyy').format(filter.endDate!)}';
        break;
    }

    return AppCard.padded(
      color: Colors.blue.shade50,
      child: Row(
        children: [
          Icon(Icons.calendar_today, color: Colors.blue.shade700, size: 20),
          const SizedBox(width: 8),
          AppText.bodySmall(
            filterText,
            color: Colors.blue.shade700,
          ),
          const Spacer(),
          Icon(Icons.star, color: Colors.blue.shade700, size: 20),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
      String title, double amount, Color color, IconData icon) {
    return AppCard.padded(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 4),
              AppText.caption(title, color: Colors.grey.shade600),
            ],
          ),
          const SizedBox(height: 8),
          AppText.heading4(
            NumberFormat.currency(
              locale: 'vi_VN',
              symbol: 'đ',
              decimalDigits: 0,
            ).format(amount),
            color: color,
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(double balance) {
    final isPositive = balance >= 0;
    return AppCard.padded(
      elevation: 2,
      color: isPositive ? AppColors.green : AppColors.red,
      child: Row(
        children: [
          Icon(
            isPositive ? Icons.savings : Icons.warning,
            color: isPositive ? AppColors.green : AppColors.red,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 AppText.heading4(
                  'Số dư',
                  color: AppColors.white,
                ),
                const SizedBox(height: 4),
                AppText.heading4(
                  NumberFormat.currency(
                    locale: 'vi_VN',
                    symbol: 'đ',
                    decimalDigits: 0,
                  ).format(balance.abs()),
                  color: AppColors.white,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard(
      String title, double amount, Color color, IconData icon) {
    return AppCard.padded(
      elevation: 3,
      color: color.withOpacity(0.1),
      child: Column(
        children: [
          Icon(icon, color: color, size: 48),
          const SizedBox(height: 12),
          AppText.body(title, color: Colors.grey.shade700),
          const SizedBox(height: 8),
          AppText.heading2(
            NumberFormat.currency(
              locale: 'vi_VN',
              symbol: 'đ',
              decimalDigits: 0,
            ).format(amount),
            color: color,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCombinedChart(StatisticsSummary summary) {
    final formatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    );

    return SizedBox(
      height: 240,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.center,
          maxY: (summary.totalIncome > summary.totalExpense
                  ? summary.totalIncome
                  : summary.totalExpense) *
              1.3,
          barGroups: [
            BarChartGroupData(
              x: 0,
              barRods: [
                BarChartRodData(
                  toY: summary.totalIncome,
                  color: AppColors.green,
                  width: 60,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                ),
              ],
              showingTooltipIndicators: [0],
            ),
            BarChartGroupData(
              x: 1,
              barRods: [
                BarChartRodData(
                  toY: summary.totalExpense,
                  color: AppColors.red,
                  width: 60,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                ),
              ],
              showingTooltipIndicators: [0],
            ),
          ],
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => Colors.transparent,
              tooltipPadding: EdgeInsets.zero,
              tooltipMargin: 0,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  _formatCompactCurrency(rod.toY),
                  TextStyle(
                    color: rod.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  switch (value.toInt()) {
                    case 0:
                      return const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Thu',
                          style: TextStyle(
                            color: AppColors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    case 1:
                      return const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Chi',
                          style: TextStyle(
                            color: AppColors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    default:
                      return const Text('');
                  }
                },
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  Widget _buildCategoryPieChart(
      List<CategoryStatistics> categories, Color baseColor) {
    // Giới hạn top 5 categories
    final topCategories = categories.take(5).toList();

    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          sections: topCategories.map((cat) {
            return PieChartSectionData(
              value: cat.amount,
              title: '${cat.percentage.toStringAsFixed(1)}%',
              color: Color(cat.categoryColorValue),
              radius: 100,
              titleStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            );
          }).toList(),
          sectionsSpace: 2,
          centerSpaceRadius: 0,
        ),
      ),
    );
  }

  Widget _buildCategoryItem(CategoryStatistics cat) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: AppListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Color(cat.categoryColorValue).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _createIconData(cat),
            color: Color(cat.categoryColorValue),
          ),
        ),
        title: AppText.body(cat.categoryName),
        subtitle: AppText.caption('${cat.transactionCount} giao dịch'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AppText.body(
              NumberFormat.currency(
                locale: 'vi_VN',
                symbol: 'đ',
                decimalDigits: 0,
              ).format(cat.amount),
              color: Color(cat.categoryColorValue),
            ),
            AppText.caption('${cat.percentage.toStringAsFixed(1)}%'),
          ],
        ),
      ),
    );
  }

  Widget _buildNoData() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.inbox, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            AppText.body(
              'Không có dữ liệu cho khoảng thời gian này',
              color: Colors.grey.shade600,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.red),
          const SizedBox(height: 16),
          AppText.body(message),
          const SizedBox(height: 16),
          AppButton.primary(
            text: 'Thử lại',
            icon: Icons.refresh,
            onPressed: () {
              context.read<StatisticsBloc>().add(const LoadStatistics());
            },
          ),
        ],
      ),
    );
  }

  void _showFilterBottomSheet() async {
    final bloc = context.read<StatisticsBloc>();
    final state = bloc.state;

    if (state is! StatisticsLoaded) return;

    // Get categories from dashboard local data source
    // (In real app, inject via repository)
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BlocProvider.value(
        value: bloc,
        child: AdvancedFilterBottomSheet(
          currentFilter: state.activeFilter,
          categories: const [], // TODO: Get from repository
        ),
      ),
    );
  }

  /// Helper method để tạo IconData từ category statistics
  IconData _createIconData(CategoryStatistics cat) {
    return IconData(
      cat.categoryIconCodePoint,
      fontFamily: cat.categoryIconFontFamily,
      fontPackage: cat.categoryIconFontPackage,
    );
  }

  /// Format số tiền dạng compact cho hiển thị trên biểu đồ
  String _formatCompactCurrency(double amount) {
    if (amount >= 1000000000) {
      return '${(amount / 1000000000).toStringAsFixed(1)}B';
    } else if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return amount.toStringAsFixed(0);
  }
}
