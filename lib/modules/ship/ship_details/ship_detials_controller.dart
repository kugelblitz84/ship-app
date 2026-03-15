import 'package:flutter/material.dart';
import 'package:urgent/core/widgets/app_snackbar.dart';
import 'package:get/get.dart';

import '../../../core/services/api_error_handler.dart';
import '../../../core/services/firebase_auth_service.dart';
import '../../../core/services/firestore_services/shipdata_service.dart';
import '../../../core/services/firestore_services/tripdata_service.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routes/app_routes.dart';
import '../../home/home_controller.dart';
import '../../trip/models/trip_model.dart';
import '../models/ship_model.dart';

class ShipDetailsController extends GetxController {
  final FirestoreTripService _tripService = Get.find<FirestoreTripService>();
  final FirestoreShipService _shipService = Get.find<FirestoreShipService>();
  final AuthService _authService = Get.find<AuthService>();

  ShipModel? ship;

  final licenseController = TextEditingController();

  final RxBool _isLoading = false.obs;
  bool get isLoading => _isLoading.value;

  final RxBool isEditing = false.obs;
  final RxBool isSaving = false.obs;
  final RxBool isDeleting = false.obs;

  final RxList<TripModel> trips = <TripModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;

    if (args is ShipModel) {
      ship = args;
    } else if (args is Map<String, dynamic>) {
      ship = ShipModel.fromMap(args);
    }

    _populateFields();
  }

  @override
  void onReady() {
    super.onReady();
    loadShipDetails();
  }

  Future<void> loadShipDetails() async {
    if (ship == null) {
      return;
    }

    _isLoading.value = true;
    try {
      final response = await ApiErrorHandler.call(
        () => _tripService.getTrips(),
        fallbackMessage: 'Failed to load ship trips',
      );
      if (!response.isSuccess || response.data == null) return;

      final allTrips = response.data!;
      trips.assignAll(
        allTrips.where(
          (trip) =>
              _normalize(trip.companyAndShipInfo.shipName) ==
              _normalize(ship!.name),
        ),
      );
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> onRefresh() => loadShipDetails();

  void startEditing() {
    if (ship == null) return;
    _populateFields();
    isEditing.value = true;
  }

  void cancelEditing() {
    _populateFields();
    isEditing.value = false;
  }

  Future<void> saveChanges() async {
    final currentShip = ship;
    if (currentShip == null || isSaving.value) return;

    isSaving.value = true;
    try {
      final updatedLicense = licenseController.text.trim();

      final response = await ApiErrorHandler.call(
        () => _shipService.updateShipDetails(
          shipName: currentShip.name,
          licenseNumber: updatedLicense,
        ),
        fallbackMessage: 'Failed to update ship details',
      );
      if (!response.isSuccess) return;

      currentShip.licenseNumber = updatedLicense;
      isEditing.value = false;
      showAppSnackbar('Success', 'Ship details updated successfully.');
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> deleteShipWithPassword(String password) async {
    final currentShip = ship;
    if (currentShip == null || isDeleting.value) return false;

    final trimmedPassword = password.trim();
    if (trimmedPassword.isEmpty) {
      showAppSnackbar('Error', 'Password is required');
      return false;
    }

    isDeleting.value = true;
    try {
      final reauthResponse = await ApiErrorHandler.call(
        () => _authService.reauthenticate(trimmedPassword),
        fallbackMessage: 'Failed to verify password',
      );
      if (!reauthResponse.isSuccess) return false;

      final deleteResponse = await ApiErrorHandler.call(
        () => _shipService.deleteShip(shipName: currentShip.name),
        fallbackMessage: 'Failed to delete ship',
      );

      if (!deleteResponse.isSuccess) return false;
      return true;
    } finally {
      isDeleting.value = false;
    }
  }

  Future<void> onDeleteShipPressed(BuildContext context) async {
    final deleted = await showPasswordConfirmDeletionDialog(
      context: context,
      title: 'Delete Ship',
      message: 'Enter your password to confirm deletion.',
      onConfirm: deleteShipWithPassword,
    );

    if (!deleted) return;
    Get.back(result: true);
  }

  Future<bool> deleteTripWithPassword({
    required TripModel trip,
    required String password,
  }) async {
    if (isDeleting.value) return false;

    final trimmedPassword = password.trim();
    if (trimmedPassword.isEmpty) {
      showAppSnackbar('Error', 'Password is required');
      return false;
    }

    isDeleting.value = true;
    try {
      final reauthResponse = await ApiErrorHandler.call(
        () => _authService.reauthenticate(trimmedPassword),
        fallbackMessage: 'Failed to verify password',
      );
      if (!reauthResponse.isSuccess) return false;

      final deleteResponse = await ApiErrorHandler.call(
        () => _tripService.deleteTrip(trip: trip),
        fallbackMessage: 'Failed to delete trip',
      );
      if (!deleteResponse.isSuccess) return false;

      await loadShipDetails();
      if (Get.isRegistered<HomeController>()) {
        await Get.find<HomeController>().loadHomeData();
      }
      return true;
    } finally {
      isDeleting.value = false;
    }
  }

  Future<void> onDeleteTripPressed(BuildContext context, TripModel trip) async {
    final deleted = await showPasswordConfirmDeletionDialog(
      context: context,
      title: 'Delete Trip',
      message:
          'Enter your password to delete this trip bill of ৳ ${_formatAmount(_toDouble(trip.totalBill))}.',
      onConfirm: (password) =>
          deleteTripWithPassword(trip: trip, password: password),
    );

    if (!deleted) return;
    showAppSnackbar('Success', 'Trip deleted successfully.');
  }

  Future<void> openTripDetails(TripModel trip) async {
    final result = await Get.toNamed(AppRoutes.tripDetails, arguments: trip);
    if (result == true) {
      await loadShipDetails();
    }
  }

  void _populateFields() {
    final currentShip = ship;
    if (currentShip == null) return;
    licenseController.text = currentShip.licenseNumber?.trim() ?? '';
  }

  @override
  void onClose() {
    licenseController.dispose();
    super.onClose();
  }

  String _normalize(String value) {
    return value.trim().toLowerCase();
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    final sanitized = value.toString().replaceAll(',', '').trim();
    if (sanitized.isEmpty) return 0;
    return double.tryParse(sanitized) ?? 0;
  }

  String _formatAmount(double value) {
    return value.toInt().toString();
  }
}
