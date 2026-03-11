import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/bootstrap/bootstrap_controller.dart';
import '../../../core/services/api_error_handler.dart';
import '../../../core/services/firebase_auth_service.dart';
import '../../../core/services/firestore_services/admin_access_service.dart';
import '../../../core/services/firestore_services/user_access_service.dart';
import '../../../routes/app_routes.dart';

class LoginController extends GetxController {
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final _isLoading = false.obs;
  final AuthService _auth = Get.find<AuthService>();
  final AdminAccessService _adminAccess = Get.find<AdminAccessService>();
  final UserAccessService _userAccessService = Get.find<UserAccessService>();
  bool get isLoading => _isLoading.value;

  Future<void> onLoginPressed() async {
    if (_isLoading.value) return;
    if (formKey.currentState?.validate() ?? false) {
      _isLoading.value = true;
      try {
        final response = await ApiErrorHandler.call(
          () => _auth.signInWithEmail(
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
          ),
        );
        if (!response.isSuccess) return;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(BootstrapController.loginStatusKey, true);
        final uid = _auth.currentUser?.uid ?? response.data?.user?.uid ?? '';
        final accessResponse = await ApiErrorHandler.call(
          () => _userAccessService.getCurrentUserAccessStatus(uid),
          fallbackMessage: 'Failed to verify account access',
        );
        if (!accessResponse.isSuccess || accessResponse.data == null) return;

        final accessStatus = accessResponse.data!;
        if (accessStatus.isBlocked) {
          _adminAccess.clear();
          Get.offAllNamed(AppRoutes.lockedAccount);
          return;
        }

        if (!accessStatus.isVerified) {
          _adminAccess.clear();
          Get.offAllNamed(AppRoutes.unverifiedAccount);
          return;
        }

        await _adminAccess.refreshCurrentUserRole();

        Get.offAllNamed(AppRoutes.home);
      } finally {
        _isLoading.value = false;
      }
    }
  }

  void goToSignup() {
    Get.toNamed(AppRoutes.signup);
  }

  void goToForgotPassword() {
    Get.toNamed(AppRoutes.forgotPassword);
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}
