import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../core/themes/themes.dart';
import '../../../core/widgets/widgets.dart';
import 'login_controller.dart';

class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSliverScaffold(
      title: 'Sign In',
      subtitle: 'Access your account securely',
      icon: Icons.lock_open_rounded,
      showBackButton: false,
      maxContentWidth: 560,
      child: Form(
        key: controller.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 48.h),

            // ── Brand Header ─────────────────────────────────────
            const AuthHeader(
              icon: Icons.lock_open_rounded,
              title: 'Welcome Back',
              subtitle: 'Sign in to continue to your account',
            ),

            // ── Email Field ──────────────────────────────────────
            AppTextField(
              controller: controller.emailController,
              label: 'Email Address',
              hint: 'you@example.com',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Email is required';
                }
                return null;
              },
            ),
            SizedBox(height: AppSpacing.base),

            // ── Password Field ───────────────────────────────────
            AppPasswordField(
              controller: controller.passwordController,
              label: 'Password',
              textInputAction: TextInputAction.done,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Password is required';
                }
                return null;
              },
            ),

            // ── Forgot Password Link ─────────────────────────────
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.only(top: 10.h),
                child: AppLinkButton(
                  text: 'Forgot Password?',
                  onPressed: controller.goToForgotPassword,
                ),
              ),
            ),

            SizedBox(height: AppSpacing.xxl),

            // ── Sign In Button ───────────────────────────────────
            Obx(
              () => AppButton(
                text: 'Sign In',
                icon: Icons.arrow_forward_rounded,
                onPressed: controller.onLoginPressed,
                isLoading: controller.isLoading,
              ),
            ),

            SizedBox(height: AppSpacing.xl),

            // ── Divider ──────────────────────────────────────────
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Text('OR', style: AppTextStyles.overline),
                ),
                const Expanded(child: Divider()),
              ],
            ),

            SizedBox(height: AppSpacing.xl),

            // ── Create Account Button ────────────────────────────
            AppButton(
              text: 'Create Account',
              onPressed: controller.goToSignup,
              isOutlined: true,
            ),

            SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}
