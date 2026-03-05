import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/bootstrap/bootstrap_controller.dart';

class ForceUpdateController extends GetxController {
  final RxBool isLaunching = false.obs;

  late final String message;
  late final String updateUrl;
  late final int currentVersionCode;
  late final int latestVersionCode;

  @override
  void onInit() {
    super.onInit();

    final args = (Get.arguments as Map?) ?? const <String, dynamic>{};
    message =
        (args[BootstrapController.updateMessageArg] as String?)
                ?.trim()
                .isNotEmpty ==
            true
        ? args[BootstrapController.updateMessageArg] as String
        : 'New version of app available! Please update.';

    updateUrl =
        (args[BootstrapController.updateUrlArg] as String?)?.trim() ?? '';
    currentVersionCode =
        (args[BootstrapController.currentVersionCodeArg] as int?) ?? 0;
    latestVersionCode =
        (args[BootstrapController.latestVersionCodeArg] as int?) ?? 0;
  }

  Future<void> openUpdateUrl() async {
    if (isLaunching.value) return;

    if (updateUrl.isEmpty) {
      Get.snackbar('Update Link Missing', 'Update URL is not configured.');
      return;
    }

    isLaunching.value = true;
    try {
      final uri = Uri.tryParse(updateUrl);
      if (uri == null) {
        Get.snackbar('Invalid Link', 'Update URL is not valid.');
        return;
      }

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        Get.snackbar('Unable to Open Link', 'Please try again in a moment.');
      }
    } finally {
      isLaunching.value = false;
    }
  }
}
