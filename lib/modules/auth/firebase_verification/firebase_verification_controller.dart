import 'package:get/get.dart';
import '../../../core/services/api_error_handler.dart';
import '../../../core/services/firebase_auth_service.dart';
import '../../../routes/app_routes.dart';

class FirebaseVerificationController extends GetxController {
  final AuthService _auth = Get.find<AuthService>();
  final RxBool isLoading = false.obs;
  bool _didAutoSend = false;
  String get email => _auth.currentUser?.email ?? 'your email address';

  @override
  void onInit() {
    super.onInit();
    _autoSendVerificationOnLoad();
  }

  Future<void> _autoSendVerificationOnLoad() async {
    if (_didAutoSend) return;
    _didAutoSend = true;

    await ApiErrorHandler.call(
      () => _auth.sendEmailVerification(),
      showErrorSnackbar: false,
    );
  }

  Future<void> onResendPressed() async {
    if (isLoading.value) return;

    isLoading.value = true;
    try {
      final response = await ApiErrorHandler.call(
        () => _auth.sendEmailVerification(),
        fallbackMessage: 'Failed to resend verification email.',
      );
      if (!response.isSuccess) return;

      Get.snackbar(
        'Verification Sent',
        'A new verification email has been sent.',
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> onIverifiedPressed() async {
    if (isLoading.value) return;
    isLoading.value = true;
    try {
      final response = await ApiErrorHandler.call(
        () => _auth.reloadUser(),
        fallbackMessage: 'Failed to check verification status.',
      );
      if (!response.isSuccess) return;

      if (_auth.currentUser?.emailVerified ?? false) {
        Get.offNamed(AppRoutes.postVerificationDetails);
      } else {
        Get.snackbar('Not Verified', 'Please verify your email first.');
      }
    } finally {
      isLoading.value = false;
    }
  }

  void onBackToLoginPressed() {
    Get.offAllNamed(AppRoutes.login);
  }
}
