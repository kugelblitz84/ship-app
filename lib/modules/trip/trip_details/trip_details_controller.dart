import 'package:flutter/material.dart';
import 'package:urgent/core/widgets/app_snackbar.dart';
import 'package:get/get.dart';

import '../../../core/services/api_error_handler.dart';
import '../../../core/services/firebase_auth_service.dart';
import '../../../core/services/firestore_services/tripdata_service.dart';
import '../../../core/widgets/widgets.dart';
import '../../home/home_controller.dart';
import '../../Transactions/transactions_history/transaction_history_controller.dart';
import '../trip_history/trip_hisotry_controller.dart';
import '../models/trip_model.dart';

class TripDetailsController extends GetxController {
  final FirestoreTripService _tripService = Get.find<FirestoreTripService>();
  final AuthService _authService = Get.find<AuthService>();

  TripModel? trip;

  final formKey = GlobalKey<FormState>();
  final fromController = TextEditingController();
  final toController = TextEditingController();
  final dateController = TextEditingController();
  final rateController = TextEditingController();
  final productNameController = TextEditingController();
  final productQuantityController = TextEditingController();
  final productUnitController = TextEditingController();
  final productDescriptionController = TextEditingController();

  final RxBool isEditing = false.obs;
  final RxBool isSaving = false.obs;
  final RxBool isDeleting = false.obs;

  /// Reactive display string for the auto-calculated total bill.
  final RxString totalBillDisplay = '--'.obs;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is TripModel) {
      trip = args;
    } else if (args is Map<String, dynamic>) {
      final fallbackTripId = (args['docId'] ?? args['documentId'] ?? '')
          .toString();
      trip = TripModel.fromMap(args, fallbackTripId: fallbackTripId);
    }

    _populateFieldsFromTrip();
    rateController.addListener(_recalculate);
    productQuantityController.addListener(_recalculate);
  }

  void _recalculate() {
    final rate = _tryParseAmount(rateController.text);
    final quantity = _tryParseAmount(productQuantityController.text);

    if (rate == null || quantity == null) {
      totalBillDisplay.value = '--';
      return;
    }

    final total = rate * quantity;
    final formatted = _formatAmount(total);
    totalBillDisplay.value = formatted;
  }

  double? _tryParseAmount(String value) {
    final sanitized = value.replaceAll(',', '').trim();
    if (sanitized.isEmpty) return null;
    return double.tryParse(sanitized);
  }

  String _formatAmount(double value) {
    return value.clamp(0, double.infinity).toInt().toString();
  }

  void startEditing() {
    if (trip == null) return;
    _populateFieldsFromTrip();
    isEditing.value = true;
  }

  void cancelEditing() {
    _populateFieldsFromTrip();
    isEditing.value = false;
  }

  Future<void> saveChanges() async {
    final currentTrip = trip;
    if (currentTrip == null) return;
    if (isSaving.value) return;

    final formState = formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    isSaving.value = true;
    try {
      final previousFrom = currentTrip.from;
      final previousTo = currentTrip.to;
      final previousDate = currentTrip.date;

      final productName = productNameController.text.trim();
      final productDescription = productDescriptionController.text.trim();
      final updatedTrip = TripModel(
        tripId: currentTrip.tripId,
        from: fromController.text.trim(),
        to: toController.text.trim(),
        date: dateController.text.trim(),
        isEdited: true,
        companyAndShipInfo: CompanyAndShipInfo(
          shipName: currentTrip.companyAndShipInfo.shipName,
          companyName: currentTrip.companyAndShipInfo.companyName,
        ),
        rate: rateController.text.trim(),
        totalBill: totalBillDisplay.value == '--'
            ? '0'
            : totalBillDisplay.value,
        product: productName.isEmpty
            ? null
            : ProductInfo(
                productName: productName,
                quantity: productQuantityController.text.trim(),
                unit: productUnitController.text.trim(),
                desctription: productDescription.isEmpty
                    ? null
                    : productDescription,
              ),
      );

      final response = await ApiErrorHandler.call(
        () => _tripService.updateTrip(
          trip: updatedTrip,
          previousFrom: previousFrom,
          previousTo: previousTo,
          previousDate: previousDate,
        ),
        fallbackMessage: 'Failed to update trip details',
      );
      if (!response.isSuccess) return;

      trip = updatedTrip;

      isEditing.value = false;
      showAppSnackbar('Success', 'Trip details updated successfully.');
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> deleteTripWithPassword(String password) async {
    final currentTrip = trip;
    if (currentTrip == null || isDeleting.value || isSaving.value) {
      return false;
    }

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
        () => _tripService.deleteTrip(trip: currentTrip),
        fallbackMessage: 'Failed to delete trip',
      );
      if (!deleteResponse.isSuccess) return false;

      if (Get.isRegistered<TripHistoryController>()) {
        final historyController = Get.find<TripHistoryController>();
        historyController.trips.removeWhere(
          (item) => item.tripId == currentTrip.tripId,
        );
      }

      if (Get.isRegistered<HomeController>()) {
        await Get.find<HomeController>().loadHomeData();
      }

      return true;
    } finally {
      isDeleting.value = false;
    }
  }

  Future<void> onDeleteTripPressed(BuildContext context) async {
    final currentTrip = trip;
    if (currentTrip == null) return;

    final deleted = await showPasswordConfirmDeletionDialog(
      context: context,
      title: 'Delete Trip',
      message:
          'Enter your password to delete this trip bill of ৳ ${_formatAmount(_tryParseAmount(currentTrip.totalBill) ?? 0)}.',
      onConfirm: deleteTripWithPassword,
    );

    if (!deleted) return;

    showAppSnackbar('Success', 'Trip deleted successfully.');
    Get.back(result: true);
  }

  String? requiredValidator(String label, String? value) {
    if ((value ?? '').trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  String? numericRequiredValidator(String label, String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return '$label is required';
    }
    if (double.tryParse(text.replaceAll(',', '')) == null) {
      return '$label must be a valid number';
    }
    return null;
  }

  void _populateFieldsFromTrip() {
    final currentTrip = trip;
    if (currentTrip == null) return;

    fromController.text = currentTrip.from;
    toController.text = currentTrip.to;
    dateController.text = currentTrip.date;
    rateController.text = currentTrip.rate;
    productNameController.text = currentTrip.product?.productName ?? '';
    productQuantityController.text = currentTrip.product?.quantity ?? '';
    productUnitController.text = currentTrip.product?.unit ?? '';
    productDescriptionController.text = currentTrip.product?.desctription ?? '';

    // Trigger initial calculation after populating fields.
    _recalculate();
  }

  @override
  void onClose() {
    rateController.removeListener(_recalculate);
    productQuantityController.removeListener(_recalculate);
    fromController.dispose();
    toController.dispose();
    dateController.dispose();
    rateController.dispose();
    productNameController.dispose();
    productQuantityController.dispose();
    productUnitController.dispose();
    productDescriptionController.dispose();
    super.onClose();
  }
}
