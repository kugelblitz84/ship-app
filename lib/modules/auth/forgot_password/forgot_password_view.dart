import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../core/themes/themes.dart';
import '../../../core/widgets/widgets.dart';
import 'forgot_password_controller.dart';

class ForgotPasswordView extends GetView<ForgotPasswordController> {
  const ForgotPasswordView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSliverScaffold(
      title: 'Forgot Password',
      subtitle: 'Request a reset link for your account',
      icon: Icons.mark_email_unread_outlined,
      maxContentWidth: 560,
      child: Form(
        key: controller.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 8.h),

            // ── Header ───────────────────────────────────────────
            const AuthHeader(
              icon: Icons.mark_email_unread_outlined,
              title: 'Forgot Password?',
              subtitle:
                  'No worries! Enter your email and we\'ll send you a password reset link.',
            ),

            // ── Email Field ──────────────────────────────────────
            AppTextField(
              controller: controller.emailController,
              label: 'Email Address',
              hint: 'you@example.com',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Email is required';
                }
                final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                if (!emailRegex.hasMatch(value.trim())) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),

            SizedBox(height: AppSpacing.xxl),

            // ── Send OTP Button ──────────────────────────────────
            Obx(
              () => AppButton(
                text: 'Send Reset Link',
                icon: Icons.send_rounded,
                onPressed: controller.onContinuePressed,
                isLoading: controller.isLoading,
              ),
            ),

            SizedBox(height: AppSpacing.lg),

            // ── Back to Login ────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Remember your password? ',
                  style: AppTextStyles.bodyMedium,
                ),
                AppLinkButton(text: 'Sign In', onPressed: () => Get.back()),
              ],
            ),

            SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}
