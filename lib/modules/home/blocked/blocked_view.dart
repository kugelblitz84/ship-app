import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../core/themes/themes.dart';
import '../../../core/widgets/widgets.dart';
import 'blocked_controller.dart';

class BlockedView extends GetView<BlockedController> {
  const BlockedView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSliverScaffold(
      title: 'Account Locked',
      subtitle: 'Contact support to restore access',
      icon: Icons.lock_outline_rounded,
      showBackButton: false,
      maxContentWidth: 620,
      child: Center(
        child: Container(
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.lg,
            boxShadow: AppShadows.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68.w,
                height: 68.w,
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 34.sp,
                  color: AppColors.error,
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'Account Locked',
                style: AppTextStyles.headlineMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10.h),
              Text(
                'Your account is locked by an administrator. Please contact support to restore access.',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),
              Obx(
                () => AppButton(
                  text: 'Sign Out',
                  icon: Icons.logout_rounded,
                  isLoading: controller.isLoading.value,
                  onPressed: controller.signOut,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
