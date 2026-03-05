import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_update_service.dart';
import '../services/firestore_services/admin_access_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/firestore_services/user_access_service.dart';
import '../../routes/app_routes.dart';

class BootstrapController extends GetxController {
  static const String loginStatusKey = 'is_logged_in';
  static const String updateMessageArg = 'updateMessage';
  static const String updateUrlArg = 'updateUrl';
  static const String currentVersionCodeArg = 'currentVersionCode';
  static const String latestVersionCodeArg = 'latestVersionCode';

  final AuthService _auth = Get.find<AuthService>();
  final UserAccessService _userAccessService = Get.find<UserAccessService>();
  final AdminAccessService _adminAccessService = Get.find<AdminAccessService>();
  final AppUpdateService _appUpdateService = Get.find<AppUpdateService>();
  final RxString statusMessage = 'Preparing app...'.obs;

  bool _hasNavigated = false;

  @override
  void onReady() {
    super.onReady();
    _resolveInitialRoute();
  }

  Future<void> _resolveInitialRoute() async {
    try {
      statusMessage.value = 'Checking app version...';
      final updateDecision = await _appUpdateService
          .checkForRequiredUpdate()
          .timeout(
            const Duration(seconds: 12),
            onTimeout: () => _nonBlockingUpdateDecision(),
          );

      if (updateDecision.mustBlock) {
        _navigateOnce(
          AppRoutes.forceUpdate,
          arguments: {
            updateMessageArg: updateDecision.updateMessage,
            updateUrlArg: updateDecision.updateUrl,
            currentVersionCodeArg: updateDecision.currentVersionCode,
            latestVersionCodeArg: updateDecision.latestVersionCode,
          },
        );
        return;
      }

      statusMessage.value = 'Checking session...';
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 6),
      );
      final isMarkedLoggedIn = prefs.getBool(loginStatusKey) ?? false;
      final hasActiveSession = _auth.currentUser != null;

      if (hasActiveSession) {
        statusMessage.value = 'Verifying account access...';
        final isBlocked = await _userAccessService
            .isCurrentUserBlocked(_auth.currentUser!.uid)
            .timeout(const Duration(seconds: 8), onTimeout: () => false);

        if (isBlocked) {
          await prefs.setBool(loginStatusKey, true);
          _adminAccessService.clear();
          _navigateOnce(AppRoutes.lockedAccount);
          return;
        }
      }

      if (isMarkedLoggedIn && hasActiveSession) {
        _navigateOnce(AppRoutes.home);
        return;
      }

      if (hasActiveSession) {
        await prefs.setBool(loginStatusKey, true);
        _navigateOnce(AppRoutes.home);
        return;
      }

      await prefs.remove(loginStatusKey);
      _navigateOnce(AppRoutes.login);
    } catch (_) {
      _adminAccessService.clear();
      _navigateOnce(AppRoutes.login);
    }
  }

  AppUpdateDecision _nonBlockingUpdateDecision() {
    return const AppUpdateDecision(
      mustBlock: false,
      forceUpdate: false,
      currentVersionCode: 0,
      latestVersionCode: 0,
      minVersionCode: 0,
      updateMessage: '',
      updateUrl: '',
    );
  }

  void _navigateOnce(String route, {Map<String, dynamic>? arguments}) {
    if (_hasNavigated || isClosed) return;
    _hasNavigated = true;
    Get.offAllNamed(route, arguments: arguments);
  }
}
