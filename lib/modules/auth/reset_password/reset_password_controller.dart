import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../core/themes/themes.dart';
import '../../../routes/app_routes.dart';

class ResetPasswordController extends GetxController {
  final formKey = GlobalKey<FormState>();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  void onResetPressed() {
    if (formKey.currentState?.validate() ?? false) {
      Get.offAllNamed(AppRoutes.login);
      Get.snackbar(
        'Password Reset Successful',
        'You can now sign in with your new password',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.successLight,
        colorText: AppColors.success,
        icon: const Icon(Icons.check_circle_rounded, color: AppColors.success),
        margin: EdgeInsets.all(16.w),
        borderRadius: 12,
        duration: const Duration(seconds: 3),
      );
    }
  }

  String? validateConfirmPassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Confirm password is required';
    }

    if (value != passwordController.text) {
      return 'Passwords do not match';
    }

    return null;
  }

  @override
  void onClose() {
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
}
