import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../core/themes/themes.dart';
import '../../../core/widgets/widgets.dart';
import 'reset_password_controller.dart';

class ResetPasswordView extends GetView<ResetPasswordController> {
  const ResetPasswordView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSliverScaffold(
      title: 'Reset Password',
      subtitle: 'Set a strong password to protect your account',
      icon: Icons.lock_reset_rounded,
      maxContentWidth: 560,
      child: Form(
        key: controller.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 8.h),

            // ── Header ───────────────────────────────────────────
            const AuthHeader(
              icon: Icons.lock_reset_rounded,
              title: 'Reset Password',
              subtitle:
                  'Create a strong new password that you don\'t use on other sites.',
            ),

            // ── New Password ─────────────────────────────────────
            AppPasswordField(
              controller: controller.passwordController,
              label: 'New Password',
              hint: 'At least 8 characters',
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'New password is required';
                }
                return null;
              },
            ),
            SizedBox(height: AppSpacing.base),

            // ── Confirm Password ─────────────────────────────────
            AppPasswordField(
              controller: controller.confirmPasswordController,
              label: 'Confirm Password',
              hint: 'Re-enter your password',
              textInputAction: TextInputAction.done,
              validator: controller.validateConfirmPassword,
            ),

            SizedBox(height: 12.h),

            // ── Password Requirements ────────────────────────────
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppColors.infoLight,
                borderRadius: AppRadius.md,
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Password should contain:',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.info,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  _requirementRow('At least 8 characters'),
                  SizedBox(height: 4.h),
                  _requirementRow('Upper & lower case letters'),
                  SizedBox(height: 4.h),
                  _requirementRow('At least one number'),
                ],
              ),
            ),

            SizedBox(height: AppSpacing.xxl),

            // ── Reset Button ─────────────────────────────────────
            AppButton(
              text: 'Reset Password',
              icon: Icons.check_circle_outline_rounded,
              onPressed: controller.onResetPressed,
            ),

            SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _requirementRow(String text) {
    return Row(
      children: [
        Icon(
          Icons.check_circle_outline_rounded,
          size: 14.sp,
          color: AppColors.info,
        ),
        SizedBox(width: 8.w),
        Text(
          text,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.info),
        ),
      ],
    );
  }
}
