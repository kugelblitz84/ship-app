import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/bootstrap/bootstrap_controller.dart';
import '../../../core/services/api_error_handler.dart';
import '../../../core/services/firebase_auth_service.dart';
import '../../../core/services/firestore_services/admin_access_service.dart';
import '../../../routes/app_routes.dart';

class BlockedController extends GetxController {
  final AuthService _auth = Get.find<AuthService>();
  final AdminAccessService _adminAccessService = Get.find<AdminAccessService>();

  final RxBool isLoading = false.obs;

  void goToOtpVerification() {
    final email = _auth.currentUser?.email?.trim();
    Get.toNamed(AppRoutes.otpVerification, arguments: {'email': email});
  }

  Future<void> signOut() async {
    if (isLoading.value) return;
    isLoading.value = true;

    try {
      final response = await ApiErrorHandler.call(
        () => _auth.signOut(),
        fallbackMessage: 'Failed to sign out',
      );
      if (!response.isSuccess) return;

      _adminAccessService.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(BootstrapController.loginStatusKey);
      Get.offAllNamed(AppRoutes.login);
    } finally {
      isLoading.value = false;
    }
  }
}
