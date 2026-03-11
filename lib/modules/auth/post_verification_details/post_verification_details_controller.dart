import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urgent/core/services/api_error_handler.dart';
import 'package:urgent/core/services/firestore_services/userdata_service.dart';
import '../../../core/bootstrap/bootstrap_controller.dart';
import '../../../routes/app_routes.dart';

class PostVerificationDetailsController extends GetxController {
  final formKey = GlobalKey<FormState>();

  final userNameController = TextEditingController();
  final organizationNameController = TextEditingController();
  final phoneController = TextEditingController();

  final RxBool _isLoading = false.obs;
  bool get isLoading => _isLoading.value;

  final FirestoreUserService _firestoreService =
      Get.find<FirestoreUserService>();
  Future<void> onContinuePressed() async {
    if (_isLoading.value) return;
    if (!(formKey.currentState?.validate() ?? false)) return;

    _isLoading.value = true;
    try {
      //await Future<void>.delayed(const Duration(milliseconds: 450));

      final response = await ApiErrorHandler.call(
        () => _firestoreService.saveUserDetails(
          userNameController.text.trim(),
          organizationNameController.text.trim(),
          phoneController.text.trim(),
        ),
        fallbackMessage: 'Failed to save user details',
      );
      if (!response.isSuccess) return;

      final verificationResponse = await ApiErrorHandler.call(
        () => _firestoreService.setCurrentUserVerified(true),
        fallbackMessage: 'Failed to finalize account verification',
      );
      if (!verificationResponse.isSuccess) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(BootstrapController.loginStatusKey, true);

      // final isBlocked = await _userAccessService.isCurrentUserBlocked();
      // if (isBlocked) {
      //   Get.offAllNamed(AppRoutes.lockedAccount);
      //   return;
      // }

      Get.offAllNamed(AppRoutes.home);
    } finally {
      _isLoading.value = false;
    }
  }

  FormFieldValidator<String> requiredValidator(String fieldLabel) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return '$fieldLabel is required';
      }
      return null;
    };
  }

  @override
  void onClose() {
    userNameController.dispose();
    organizationNameController.dispose();
    phoneController.dispose();
    super.onClose();
  }
}
