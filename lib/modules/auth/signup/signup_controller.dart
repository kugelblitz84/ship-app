import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../../../core/services/api_error_handler.dart';
import '../../../routes/app_routes.dart';
import '../../../core/services/firebase_auth_service.dart';

class SignupController extends GetxController {
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final RxBool _isLoading = false.obs;
  bool get isLoading => _isLoading.value;
  final AuthService _auth = Get.find<AuthService>();

  Future<void> onContinuePressed() async {
    if (_isLoading.value) return;

    if (formKey.currentState?.validate() ?? false) {
      _isLoading.value = true;

      try {
        final signupResponse = await ApiErrorHandler.call(
          () => _auth.signUpWithEmail(
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
          ),
        );
        if (!signupResponse.isSuccess) return;
        final email = emailController.text.trim();
        Get.snackbar(
          'Success',
          'Account created. Enter the OTP sent to your email.',
        );
        Get.offNamed(AppRoutes.otpVerification, arguments: {'email': email});
      } finally {
        _isLoading.value = false;
      }
    }
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}
