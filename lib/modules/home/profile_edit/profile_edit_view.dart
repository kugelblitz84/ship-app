import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../core/themes/themes.dart';
import '../../../core/widgets/widgets.dart';
import 'profile_edit_controller.dart';

class ProfileEditView extends GetView<ProfileEditController> {
  const ProfileEditView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSliverScaffold(
      title: 'Edit Profile',
      subtitle: 'Update your account details',
      icon: Icons.manage_accounts_rounded,
      maxContentWidth: 560,
      child: Form(
        key: controller.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 8.h),
            const AuthHeader(
              icon: Icons.manage_accounts_rounded,
              title: 'Edit Profile',
              subtitle:
                  'Keep your personal and organization details up to date.',
            ),
            AppTextField(
              controller: controller.usernameController,
              label: 'Username',
              hint: 'Your full name',
              prefixIcon: Icons.person_outline_rounded,
              textInputAction: TextInputAction.next,
              validator: controller.requiredValidator('Username'),
            ),
            SizedBox(height: AppSpacing.base),
            AppTextField(
              controller: controller.organizationController,
              label: 'Organization Name',
              hint: 'Your organization',
              prefixIcon: Icons.business_outlined,
              textInputAction: TextInputAction.done,
              validator: controller.requiredValidator('Organization name'),
            ),
            SizedBox(height: AppSpacing.base),
            Obx(
              () => _ReadOnlyField(
                label: 'Email',
                value: controller.email.value,
                icon: Icons.email_outlined,
              ),
            ),
            SizedBox(height: AppSpacing.base),
            Obx(
              () => Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: controller.isVerified.value
                      ? AppColors.successLight
                      : AppColors.warningLight,
                  borderRadius: AppRadius.md,
                  border: Border.all(
                    color: controller.isVerified.value
                        ? AppColors.success.withValues(alpha: 0.25)
                        : AppColors.warning.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      controller.isVerified.value
                          ? Icons.verified_rounded
                          : Icons.error_outline_rounded,
                      size: 18.sp,
                      color: controller.isVerified.value
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      controller.isVerified.value
                          ? 'Verified Account'
                          : 'Not Verified',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: controller.isVerified.value
                            ? AppColors.success
                            : AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: AppSpacing.xxl),
            Obx(
              () => AppButton(
                text: 'Save Changes',
                icon: Icons.save_rounded,
                onPressed: controller.onSavePressed,
                isLoading: controller.isLoading,
              ),
            ),
            SizedBox(height: AppSpacing.base),
            AppButton(
              text: 'Reset Password',
              icon: Icons.lock_reset_rounded,
              onPressed: controller.onResetPasswordPressed,
              isOutlined: true,
            ),
            SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 8.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
          decoration: BoxDecoration(
            color: AppColors.neutral50,
            borderRadius: AppRadius.md,
            border: Border.all(color: AppColors.neutral200),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20.sp, color: AppColors.neutral500),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  value.isEmpty ? 'No email available' : value,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
