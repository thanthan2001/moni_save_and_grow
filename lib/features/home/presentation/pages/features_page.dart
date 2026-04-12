import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/app_back_scope.dart';
import '../../../../global/widgets/widgets.dart';

/// Màn hình Thêm tính năng - hiển thị các features của app
class FeaturesPage extends StatelessWidget {
  const FeaturesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBackScope(
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF5F7FA),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => AppBackScope.handleBack(context),
          ),
          title: AppText.heading4('Chức năng'),
        ),
        body: _buildFeaturesGrid(context),
      ),
    );
  }

  Widget _buildFeaturesGrid(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.95,
        children: [
          _buildFeatureCard(
            icon: Icons.assessment_outlined,
            title: 'Ngân sách',
            description: 'Quản lý ngân sách theo danh mục',
            iconColor: const Color(0xFF2196F3), // Blue
            onTap: () => context.push('/budgets'),
          ),
          _buildFeatureCard(
            icon: Icons.payments_outlined,
            title: 'Giới hạn chi tiêu',
            description: 'Thiết lập giới hạn chi tiêu tuần/tháng',
            iconColor: const Color(0xFFFF9800), // Orange
            onTap: () => context.push('/spending-limit'),
          ),
          _buildFeatureCard(
            icon: Icons.category_outlined,
            title: 'Nhóm',
            description: 'Quản lý danh mục thu chi',
            iconColor: const Color(0xFF9C27B0), // Purple
            onTap: () => context.push('/categories'),
          ),
          _buildFeatureCard(
            icon: Icons.backup_outlined,
            title: 'Sao lưu',
            description: 'Sao lưu & khôi phục dữ liệu',
            iconColor: const Color(0xFF4CAF50), // Green
            onTap: () => context.push('/backup'),
          ),
          _buildFeatureCard(
            icon: Icons.smart_toy_outlined,
            title: 'Trợ lí AI',
            description: 'Phân tích tin nhắn thành giao dịch tự động',
            iconColor: const Color(0xFF00695C), // Teal
            onTap: () => context.push('/ai-assistant'),
          ),
          // _buildFeatureCard(
          //   icon: Icons.bar_chart_outlined,
          //   title: 'Thống kê',
          //   description: 'Xem báo cáo và thống kê',
          //   iconColor: const Color(0xFF00BCD4), // Teal
          //   onTap: () => context.push('/statistics'),
          // ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 32,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                height: 1.3,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
