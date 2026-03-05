import 'package:flutter/material.dart';
import '../firebase_verification/firebase_verification_controller.dart';
import '../../../core/themes/themes.dart';
import '../../../core/widgets/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class FirebaseVerificationView extends GetView<FirebaseVerificationController> {
  const FirebaseVerificationView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSliverScaffold(
      title: 'Verify Email',
      subtitle: 'Confirm your email address to continue',
      icon: Icons.mark_email_read_outlined,
      maxContentWidth: 560,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 8.h),
          const AuthHeader(
            icon: Icons.mark_email_read_outlined,
            title: 'Verify Your Email',
            subtitle:
                'We sent a verification link to your email address. Open it and confirm your account.',
          ),
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.infoLight,
              borderRadius: AppRadius.md,
              border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18.sp,
                  color: AppColors.info,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    'Sent to: ${controller.email}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.info,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Didn\'t get it? ', style: AppTextStyles.bodyMedium),
              Obx(() {
                final isLoading = controller.isLoading.value;
                return AppLinkButton(
                  text: isLoading ? 'Sending...' : 'Resend Email',
                  onPressed: isLoading ? null : controller.onResendPressed,
                );
              }),
            ],
          ),
          SizedBox(height: AppSpacing.xxl),
          Obx(() {
            final isLoading = controller.isLoading.value;
            return AppButton(
              text: 'I\'ve Verified',
              icon: Icons.check_circle_outline_rounded,
              onPressed: controller.onIverifiedPressed,
              isLoading: isLoading,
            );
          }),
          SizedBox(height: AppSpacing.base),
          AppButton(
            text: 'Back to Sign In',
            isOutlined: true,
            onPressed: controller.onBackToLoginPressed,
          ),
          SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}
