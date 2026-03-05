import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../core/services/firestore_services/user_access_service.dart';
import '../../../core/themes/themes.dart';
import '../../../core/widgets/widgets.dart';
import 'admin_users_controller.dart';

class AdminUsersView extends GetView<AdminUsersController> {
  const AdminUsersView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSliverScaffold(
      title: 'Admin Users',
      subtitle: 'User access control and export',
      icon: Icons.admin_panel_settings_rounded,
      maxContentWidth: 1120,
      onRefresh: controller.loadUsers,
      actions: [
        Obx(() {
          final exporting = controller.isExporting.value;
          return Padding(
            padding: EdgeInsets.only(right: 12.w),
            child: TextButton.icon(
              onPressed: exporting ? null : controller.exportUsersCollection,
              icon: exporting
                  ? SizedBox(
                      width: 16.w,
                      height: 16.w,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_rounded, color: Colors.white),
              label: Text(
                exporting ? 'Exporting...' : 'Export',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          );
        }),
      ],
      child: Obx(() {
        if (controller.isLoading.value && controller.users.isEmpty) {
          return SizedBox(
            height: 260.h,
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSummaryCard(),
            SizedBox(height: 14.h),
            Text(
              'Users',
              style: AppTextStyles.headlineSmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 10.h),
            if (controller.users.isEmpty)
              _buildEmptyState()
            else
              ...controller.users.map(_buildUserTile),
            SizedBox(height: 22.h),
          ],
        );
      }),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg,
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Admin Overview',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(
                child: _metric(
                  icon: Icons.group_rounded,
                  label: 'Total Users',
                  value: controller.totalUsers.toString(),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _metric(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Lifetime Earnings',
                  value:
                      '৳ ${_formatCurrency(controller.totalLifetimeEarnings)}',
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          // Optional: export button inside card too (keep if you want)
          Obx(() {
            final exporting = controller.isExporting.value;
            return AppButton(
              text: exporting ? "Exporting..." : "Export Users (JSON)",
              useGradient: false,
              isOutlined: true,
              onPressed: exporting ? null : controller.exportUsersCollection,
            );
          }),
        ],
      ),
    );
  }

  Widget _metric({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: AppRadius.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18.sp, color: AppColors.primary),
          SizedBox(height: 6.h),
          Text(
            value,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.neutral600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(AdminUserSummary user) {
    final isSelf = controller.currentUserId == user.uid;
    final isUpdating = controller.activeUserId.value == user.uid;

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.md,
        boxShadow: AppShadows.sm,
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        leading: Container(
          width: 38.w,
          height: 38.w,
          decoration: BoxDecoration(
            color: user.isBlocked
                ? AppColors.errorLight
                : AppColors.primarySurface,
            borderRadius: AppRadius.sm,
          ),
          child: Icon(
            user.isBlocked ? Icons.block_rounded : Icons.person_rounded,
            color: user.isBlocked ? AppColors.error : AppColors.primary,
          ),
        ),
        title: Text(
          user.name.isNotEmpty
              ? user.name
              : (user.email.isNotEmpty ? user.email : user.uid),
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user.email.isNotEmpty)
              Text(
                user.email,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            Text(
              'Lifetime Earnings: ৳ ${_formatCurrency(user.lifetimeEarnings)}',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (isSelf)
              Text(
                'Current account',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.info),
              ),
          ],
        ),
        trailing: isUpdating
            ? SizedBox(
                width: 20.w,
                height: 20.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            : Switch(
                value: user.isBlocked,
                onChanged: isSelf
                    ? null
                    : (value) => controller.toggleUserBlock(user, value),
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.all(22.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.group_off_rounded,
            color: AppColors.neutral400,
            size: 30.sp,
          ),
          SizedBox(height: 10.h),
          Text(
            'No users found',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 10.h),
          AppButton(
            text: 'Refresh',
            useGradient: false,
            isOutlined: true,
            onPressed: controller.loadUsers,
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double value) {
    if (value >= 1e7) {
      return '${(value / 1e7).toStringAsFixed(2)} Cr';
    }
    if (value >= 1e5) {
      return '${(value / 1e5).toStringAsFixed(2)} L';
    }
    if (value % 1 == 0) {
      return value.toInt().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
    }
    return value
        .toStringAsFixed(2)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }
}
