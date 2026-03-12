import 'package:get/get.dart';
import 'package:urgent/core/widgets/app_snackbar.dart';
import '../../../core/services/api_error_handler.dart';
import '../../../core/services/firebase_auth_service.dart';
import '../../../core/services/firestore_services/user_access_service.dart';
import '../../../routes/app_routes.dart';

class FirebaseVerificationController extends GetxController {
  final AuthService _auth = Get.find<AuthService>();
  final UserAccessService _userAccessService = Get.find<UserAccessService>();
  final RxBool isLoading = false.obs;
  String get email => _auth.currentUser?.email ?? 'your email address';

  @override
  void onInit() {
    super.onInit();
    // Keep this route as a compatibility entry-point, but the actual
    // verification flow is OTP-based.
  }

  Future<void> onResendPressed() async {
    Get.toNamed(AppRoutes.otpVerification, arguments: {'email': email});
  }

  Future<void> onIverifiedPressed() async {
    if (isLoading.value) return;
    isLoading.value = true;
    try {
      final uid = _auth.currentUser?.uid ?? '';
      final response = await ApiErrorHandler.call(
        () => _userAccessService.getCurrentUserAccessStatus(uid),
        fallbackMessage: 'Failed to check verification status.',
      );
      if (!response.isSuccess || response.data == null) return;

      if (response.data!.isVerified) {
        Get.offNamed(AppRoutes.postVerificationDetails);
      } else {
        showAppSnackbar(
          'Not Verified',
          'Please complete OTP verification to continue.',
        );
      }
    } finally {
      isLoading.value = false;
    }
  }

  void onBackToLoginPressed() {
    Get.offAllNamed(AppRoutes.login);
  }
}

