import 'package:get/get.dart';
import 'package:flutter/material.dart';

import '../../../core/services/api_error_handler.dart';
import '../../../core/services/firebase_auth_service.dart';
import '../../../core/services/firestore_services/shipdata_service.dart';
import '../../../routes/app_routes.dart';
import '../models/ship_model.dart';

enum ShipSortOption { nameAZ, nameZA, licenseAZ, licenseZA }

enum ShipLicenseFilter { all, withLicense, withoutLicense }

class ShipListController extends GetxController {
  final FirestoreShipService _shipService = Get.find<FirestoreShipService>();
  final AuthService _authService = Get.find<AuthService>();

  final RxBool _isLoading = true.obs;
  bool get isLoading => _isLoading.value;

  final RxList<ShipModel> ships = <ShipModel>[].obs;
  final TextEditingController searchController = TextEditingController();
  final RxString searchQuery = ''.obs;
  final Rx<ShipSortOption> sortOption = ShipSortOption.nameAZ.obs;
  final Rx<ShipLicenseFilter> licenseFilter = ShipLicenseFilter.all.obs;
  final RxBool isDeleting = false.obs;

  @override
  void onInit() {
    super.onInit();
    searchController.addListener(() {
      searchQuery.value = searchController.text;
    });
    loadShips();
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  Future<void> loadShips({bool showLoader = true}) async {
    if (showLoader) {
      _isLoading.value = true;
    }

    final response = await ApiErrorHandler.call(
      () => _shipService.getShips(),
      fallbackMessage: 'Failed to load ships',
      showErrorSnackbar: !showLoader,
    );

    if (response.isSuccess && response.data != null) {
      ships.assignAll(response.data!);
    }

    _isLoading.value = false;
  }

  Future<void> onRefresh() async {
    await loadShips(showLoader: false);
  }

  Future<void> onAddShipPressed() async {
    await Get.toNamed(AppRoutes.addShip);
    await loadShips(showLoader: false);
  }

  Future<void> onShipPressed(ShipModel ship) async {
    final result = await Get.toNamed(AppRoutes.shipDetails, arguments: ship);
    await loadShips(showLoader: false);
    if (result == true) {
      Get.snackbar('Success', 'Ship deleted successfully.');
    }
  }

  Future<bool> deleteShipWithPassword({
    required ShipModel ship,
    required String password,
  }) async {
    final trimmedPassword = password.trim();
    if (trimmedPassword.isEmpty) {
      Get.snackbar('Error', 'Password is required');
      return false;
    }

    if (isDeleting.value) return false;

    isDeleting.value = true;
    try {
      final reauthResponse = await ApiErrorHandler.call(
        () => _authService.reauthenticate(trimmedPassword),
        fallbackMessage: 'Failed to verify password',
      );
      if (!reauthResponse.isSuccess) return false;

      final deleteResponse = await ApiErrorHandler.call(
        () => _shipService.deleteShip(shipName: ship.name),
        fallbackMessage: 'Failed to delete ship',
      );
      if (!deleteResponse.isSuccess) return false;

      await loadShips(showLoader: false);
      return true;
    } finally {
      isDeleting.value = false;
    }
  }

  List<ShipModel> get visibleShips {
    final query = searchQuery.value.trim().toLowerCase();

    final filtered = ships.where((ship) {
      final name = ship.name.trim().toLowerCase();
      final license = (ship.licenseNumber ?? '').trim().toLowerCase();
      final hasLicense = license.isNotEmpty;

      final licenseMatch = switch (licenseFilter.value) {
        ShipLicenseFilter.all => true,
        ShipLicenseFilter.withLicense => hasLicense,
        ShipLicenseFilter.withoutLicense => !hasLicense,
      };

      final searchMatch =
          query.isEmpty || name.contains(query) || license.contains(query);

      return licenseMatch && searchMatch;
    }).toList();

    filtered.sort((left, right) {
      final leftName = left.name.trim().toLowerCase();
      final rightName = right.name.trim().toLowerCase();
      final leftLicense = (left.licenseNumber ?? '').trim().toLowerCase();
      final rightLicense = (right.licenseNumber ?? '').trim().toLowerCase();

      switch (sortOption.value) {
        case ShipSortOption.nameAZ:
          return leftName.compareTo(rightName);
        case ShipSortOption.nameZA:
          return rightName.compareTo(leftName);
        case ShipSortOption.licenseAZ:
          return leftLicense.compareTo(rightLicense);
        case ShipSortOption.licenseZA:
          return rightLicense.compareTo(leftLicense);
      }
    });

    return filtered;
  }

  bool get hasActiveFilters =>
      searchQuery.value.trim().isNotEmpty ||
      licenseFilter.value != ShipLicenseFilter.all ||
      sortOption.value != ShipSortOption.nameAZ;

  void onSortChanged(ShipSortOption? value) {
    if (value == null) return;
    sortOption.value = value;
  }

  void onLicenseFilterChanged(ShipLicenseFilter? value) {
    if (value == null) return;
    licenseFilter.value = value;
  }

  void clearAllFilters() {
    searchController.clear();
    searchQuery.value = '';
    licenseFilter.value = ShipLicenseFilter.all;
    sortOption.value = ShipSortOption.nameAZ;
  }
}
