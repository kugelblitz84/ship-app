import 'package:flutter/material.dart';
import 'package:urgent/core/widgets/app_snackbar.dart';
import 'package:get/get.dart';

import '../../../core/services/api_error_handler.dart';
import '../../../core/services/firebase_auth_service.dart';
import '../../../routes/app_routes.dart';

class ForgotPasswordController extends GetxController {
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final RxBool _isLoading = false.obs;
  final AuthService _auth = Get.find<AuthService>();

  bool get isLoading => _isLoading.value;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is Map && args['email'] is String) {
      emailController.text = (args['email'] as String).trim();
      return;
    }
    emailController.text = _auth.currentUser?.email?.trim() ?? '';
  }

  Future<void> onContinuePressed() async {
    if (_isLoading.value) return;
    if (!(formKey.currentState?.validate() ?? false)) return;

    _isLoading.value = true;
    try {
      final response = await ApiErrorHandler.call(
        () => _auth.sendPasswordResetEmail(emailController.text.trim()),
        fallbackMessage: 'Failed to send password reset email',
      );
      if (!response.isSuccess) return;

      showAppSnackbar(
        'Email Sent',
        'Password reset instructions have been sent to your email.',
      );
      Get.offAllNamed(AppRoutes.login);
    } finally {
      _isLoading.value = false;
    }
  }

  @override
  void onClose() {
    emailController.dispose();
    super.onClose();
  }
}

