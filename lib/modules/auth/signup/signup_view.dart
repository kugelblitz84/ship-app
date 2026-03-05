import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../core/themes/themes.dart';
import '../../../core/widgets/widgets.dart';
import 'signup_controller.dart';

class SignupView extends GetView<SignupController> {
  const SignupView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSliverScaffold(
      title: 'Create Account',
      subtitle: 'Register with your email and password',
      icon: Icons.person_add_alt_rounded,
      maxContentWidth: 560,
      child: Form(
        key: controller.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 8.h),

            // ── Brand Header ─────────────────────────────────────
            const AuthHeader(
              icon: Icons.person_add_alt_rounded,
              title: 'Create Account',
              subtitle: 'Use your email and password to create your account',
            ),

            // ── Email ────────────────────────────────────────────
            AppTextField(
              controller: controller.emailController,
              label: 'Email Address',
              hint: 'you@example.com',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: _requiredValidator('Email'),
            ),
            SizedBox(height: AppSpacing.base),

            // ── Password ─────────────────────────────────────────
            AppPasswordField(
              controller: controller.passwordController,
              label: 'Password',
              textInputAction: TextInputAction.done,
              validator: _requiredValidator('Password'),
            ),

            SizedBox(height: AppSpacing.xxl),

            // ── Continue Button ──────────────────────────────────
            Obx(
              () => AppButton(
                text: 'Continue',
                icon: Icons.arrow_forward_rounded,
                onPressed: controller.onContinuePressed,
                isLoading: controller.isLoading,
              ),
            ),

            SizedBox(height: AppSpacing.lg),

            // ── Already have account ─────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Already have an account? ',
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

  FormFieldValidator<String> _requiredValidator(String fieldLabel) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return '$fieldLabel is required';
      }
      return null;
    };
  }
}
