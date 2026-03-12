import 'package:flutter/material.dart';
import 'package:urgent/core/widgets/app_snackbar.dart';
import 'package:get/get.dart';

import '../../../core/services/api_error_handler.dart';
import '../../../core/services/firebase_auth_service.dart';
import '../../../core/services/firestore_services/userdata_service.dart';
import '../../../routes/app_routes.dart';
import '../home_controller.dart';

class ProfileEditController extends GetxController {
  final formKey = GlobalKey<FormState>();
  final usernameController = TextEditingController();
  final organizationController = TextEditingController();

  final RxString email = ''.obs;
  final RxBool isVerified = false.obs;
  final RxBool _isLoading = false.obs;

  bool get isLoading => _isLoading.value;

  final AuthService _auth = Get.find<AuthService>();
  final FirestoreUserService _firestore = Get.find<FirestoreUserService>();

  @override
  void onInit() {
    super.onInit();
    loadProfile();
  }

  Future<void> loadProfile() async {
    if (_isLoading.value) return;

    _isLoading.value = true;
    try {
      final response = await ApiErrorHandler.call(
        () => _firestore.getUserDetails(),
        fallbackMessage: 'Failed to load profile details',
      );
      if (!response.isSuccess || response.data == null) return;

      final data = response.data!;
      usernameController.text = data.username.trim();
      organizationController.text = data.organization.trim();

      final currentUser = _auth.currentUser;
      email.value = (currentUser?.email ?? data.email).trim();

      isVerified.value = data.isVerified;
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> onSavePressed() async {
    if (_isLoading.value) return;
    if (!(formKey.currentState?.validate() ?? false)) return;

    _isLoading.value = true;
    try {
      final response = await ApiErrorHandler.call(
        () => _firestore.updateCurrentUserProfile(
          username: usernameController.text.trim(),
          organization: organizationController.text.trim(),
        ),
        fallbackMessage: 'Failed to update profile',
      );
      if (!response.isSuccess) return;

      if (Get.isRegistered<HomeController>()) {
        await Get.find<HomeController>().loadHomeData();
      }

      showAppSnackbar('Profile Updated', 'Your profile details have been saved.');
    } finally {
      _isLoading.value = false;
    }
  }

  void onResetPasswordPressed() {
    Get.toNamed(AppRoutes.forgotPassword, arguments: {'email': email.value});
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
    usernameController.dispose();
    organizationController.dispose();
    super.onClose();
  }
}

