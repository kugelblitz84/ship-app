import 'package:flutter/material.dart';
import 'package:urgent/core/widgets/app_snackbar.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/services/api_error_handler.dart';
import '../../../core/services/firebase_auth_service.dart';
import '../../../core/services/firestore_services/userdata_service.dart';
import '../../../core/services/local_otp_service.dart';
import '../../../routes/app_routes.dart';

class OtpVerificationController extends GetxController {
  final AuthService _auth = Get.find<AuthService>();
  final LocalOtpService _otpService = Get.find<LocalOtpService>();
  final FirestoreUserService _firestoreUserService =
      Get.find<FirestoreUserService>();

  final targetEmail = ''.obs;
  final isSendingOtp = false.obs;
  final isVerifyingOtp = false.obs;

  @override
  void onInit() {
    super.onInit();
    _resolveTargetEmail();
    _sendOtp();
  }

  void _resolveTargetEmail() {
    final args = Get.arguments;
    if (args is Map && args['email'] is String) {
      targetEmail.value = (args['email'] as String).trim();
    }
    if (targetEmail.value.isEmpty) {
      targetEmail.value = _auth.currentUser?.email?.trim() ?? '';
    }
  }

  final digitControllers = List.generate(
    6,
    (_) => TextEditingController(),
    growable: false,
  );
  final focusNodes = List.generate(6, (_) => FocusNode(), growable: false);

  final showOtpError = false.obs;
  final focusedIndex = (-1).obs;

  String get _enteredOtp =>
      digitControllers.map((controller) => controller.text.trim()).join();

  Future<void> _sendOtp() async {
    if (targetEmail.value.isEmpty || isSendingOtp.value) return;

    isSendingOtp.value = true;
    try {
      final response = await OtpMailerErrorHandler.call(
        () => _otpService.issueOtp(email: targetEmail.value),
        fallbackMessage: 'Failed to send OTP. Please try again.',
      );
      if (!response.isSuccess) return;

      showAppSnackbar(
        'OTP Sent',
        'A 6-digit OTP has been sent to ${targetEmail.value}.',
      );
    } finally {
      isSendingOtp.value = false;
    }
  }

  void onOtpChanged(int index, String value) {
    showOtpError.value = false;

    if (value.isNotEmpty && index < focusNodes.length - 1) {
      focusNodes[index + 1].requestFocus();
      return;
    }

    if (value.isEmpty && index > 0) {
      focusNodes[index - 1].requestFocus();
    }
  }

  KeyEventResult onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        digitControllers[index].text.isEmpty &&
        index > 0) {
      focusNodes[index - 1].requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> onVerifyPressed() async {
    if (isVerifyingOtp.value) return;

    final isValid = digitControllers
        .map((controller) => controller.text.trim())
        .every((digit) => digit.isNotEmpty);

    if (!isValid) {
      showOtpError.value = true;
      return;
    }

    if (targetEmail.value.isEmpty) {
      showAppSnackbar('Error', 'Email was not found. Please login again.');
      return;
    }

    isVerifyingOtp.value = true;
    try {
      final response = await OtpMailerErrorHandler.call(
        () => _otpService.verifyOtp(
          email: targetEmail.value,
          enteredOtp: _enteredOtp,
        ),
        fallbackMessage: 'Failed to verify OTP. Please try again.',
      );
      if (!response.isSuccess || response.data == null) return;

      final result = response.data!;

      switch (result.status) {
        case OtpValidationStatus.success:
          final verificationResponse = await ApiErrorHandler.call(
            () => _firestoreUserService.setCurrentUserVerified(true),
            fallbackMessage:
                'OTP validated but verification status update failed.',
          );
          if (!verificationResponse.isSuccess) return;

          Get.toNamed(AppRoutes.postVerificationDetails);
          break;
        case OtpValidationStatus.invalid:
          showOtpError.value = true;
          showAppSnackbar('Invalid OTP', 'The OTP you entered is incorrect.');
          break;
        case OtpValidationStatus.expired:
          showOtpError.value = true;
          showAppSnackbar(
            'OTP Expired',
            'Your OTP expired. Please resend a new code.',
          );
          break;
        case OtpValidationStatus.noOtp:
          showOtpError.value = true;
          showAppSnackbar('No OTP', 'No OTP found. Please resend the code.');
          break;
        case OtpValidationStatus.emailMismatch:
          showAppSnackbar(
            'Error',
            'OTP does not match this account. Please login again.',
          );
          break;
      }
    } finally {
      isVerifyingOtp.value = false;
    }
  }

  Future<void> onResendPressed() async {
    for (final controller in digitControllers) {
      controller.clear();
    }
    showOtpError.value = false;

    await _sendOtp();
  }

  @override
  void onClose() {
    for (final controller in digitControllers) {
      controller.dispose();
    }
    for (final focusNode in focusNodes) {
      focusNode.dispose();
    }
    super.onClose();
  }
}

