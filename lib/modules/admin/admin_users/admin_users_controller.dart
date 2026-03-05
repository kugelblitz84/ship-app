import 'package:get/get.dart';
import 'package:flutter/material.dart';

import '../../../core/services/api_error_handler.dart';
import '../../../core/services/firebase_auth_service.dart';
import '../../../core/services/firestore_services/admin_access_service.dart';
import '../../../core/services/firestore_services/user_access_service.dart';
import '../../../routes/app_routes.dart';
import '../../../core/services/firestore_services/users_export_service.dart';
import '../../../core/services/download/download_service.dart';

class AdminUsersController extends GetxController {
  final UserAccessService _userAccessService = Get.find<UserAccessService>();
  final AdminAccessService _adminAccessService = Get.find<AdminAccessService>();
  final AuthService _auth = Get.find<AuthService>();

  final RxBool isLoading = false.obs;
  final RxString activeUserId = ''.obs;
  final RxList<AdminUserSummary> users = <AdminUserSummary>[].obs;
  final RxBool isExporting = false.obs;
  final UsersExportService _exportService = Get.find<UsersExportService>();
  final DownloadService _downloadService = createDownloadService();
  String? get currentUserId => _auth.currentUser?.uid;
  int get totalUsers => users.length;
  double get totalLifetimeEarnings =>
      users.fold(0.0, (sum, user) => sum + user.lifetimeEarnings);

  @override
  void onInit() {
    super.onInit();
    loadUsers();
  }

  Future<void> loadUsers() async {
    isLoading.value = true;
    try {
      final isAdmin = await _adminAccessService.refreshCurrentUserRole();
      if (!isAdmin) {
        Get.offAllNamed(AppRoutes.home);
        return;
      }

      final response = await ApiErrorHandler.call<List<AdminUserSummary>>(
        () => _userAccessService.getAllUsersWithLifetimeEarnings(),
        fallbackMessage: 'Failed to load users',
      );

      if (!response.isSuccess || response.data == null) return;
      users.assignAll(response.data!);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> exportUsersCollection() async {
    if (isExporting.value) return;
    try {
      isExporting.value = true;

      final savedFile = await _exportService.exportUsersToJsonFile();
      if (savedFile.supportsExplicitDownload) {
        final downloaded = await _downloadService.triggerDownload(savedFile);
        if (!downloaded) {
          throw Exception('Could not start browser download for JSON export.');
        }
      }

      Get.snackbar(
        'Exported',
        'Users exported successfully.\n${savedFile.fileName}\n${savedFile.locationLabel}',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Export failed',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isExporting.value = false;
    }
  }

  Future<void> toggleUserBlock(AdminUserSummary user, bool shouldBlock) async {
    if (activeUserId.value.isNotEmpty) return;
    activeUserId.value = user.uid;

    try {
      final response = await ApiErrorHandler.call(
        () => _userAccessService.setUserBlocked(
          userId: user.uid,
          isBlocked: shouldBlock,
          email: user.email,
        ),
        fallbackMessage: 'Failed to update restriction status',
      );

      if (!response.isSuccess) return;
      await loadUsers();
    } finally {
      activeUserId.value = '';
    }
  }
}
