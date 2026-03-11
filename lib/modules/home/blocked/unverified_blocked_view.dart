import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../core/themes/themes.dart';
import '../../../core/widgets/widgets.dart';
import 'blocked_controller.dart';

class UnverifiedBlockedView extends GetView<BlockedController> {
  const UnverifiedBlockedView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSliverScaffold(
      title: 'Verify Your Account',
      subtitle: 'Complete OTP verification to continue',
      icon: Icons.mark_email_unread_outlined,
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
                  color: AppColors.warningLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.verified_user_outlined,
                  size: 34.sp,
                  color: AppColors.warning,
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'Account Not Verified',
                style: AppTextStyles.headlineMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10.h),
              Text(
                'Your account is not verified yet. Verify with OTP to unlock all app features.',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),
              AppButton(
                text: 'Go To OTP Verification',
                icon: Icons.shield_outlined,
                onPressed: controller.goToOtpVerification,
              ),
              SizedBox(height: 12.h),
              Obx(
                () => AppButton(
                  text: 'Sign Out',
                  icon: Icons.logout_rounded,
                  isLoading: controller.isLoading.value,
                  isOutlined: true,
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
