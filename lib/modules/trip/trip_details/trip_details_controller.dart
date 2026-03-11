import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/api_error_handler.dart';
import '../../../core/services/firestore_services/tripdata_service.dart';
import '../models/trip_model.dart';

class TripDetailsController extends GetxController {
  final FirestoreTripService _tripService = Get.find<FirestoreTripService>();

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

  /// Reactive display string for the auto-calculated total bill.
  final RxString totalBillDisplay = '--'.obs;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is TripModel) {
      trip = args;
    } else if (args is Map<String, dynamic>) {
      trip = TripModel.fromMap(args);
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

      currentTrip.from = fromController.text.trim();
      currentTrip.to = toController.text.trim();
      currentTrip.date = dateController.text.trim();
      currentTrip.rate = rateController.text.trim();
      currentTrip.totalBill = totalBillDisplay.value == '--'
          ? '0'
          : totalBillDisplay.value;

      final productName = productNameController.text.trim();
      if (productName.isEmpty) {
        currentTrip.product = null;
      } else {
        currentTrip.product = ProductInfo(
          productName: productName,
          quantity: productQuantityController.text.trim(),
          unit: productUnitController.text.trim(),
          desctription: productDescriptionController.text.trim().isEmpty
              ? null
              : productDescriptionController.text.trim(),
        );
      }

      currentTrip.isEdited = true;

      final response = await ApiErrorHandler.call(
        () => _tripService.updateTrip(
          trip: currentTrip,
          previousFrom: previousFrom,
          previousTo: previousTo,
          previousDate: previousDate,
        ),
        fallbackMessage: 'Failed to update trip details',
      );
      if (!response.isSuccess) return;

      isEditing.value = false;
      Get.snackbar('Success', 'Trip details updated successfully.');
    } finally {
      isSaving.value = false;
    }
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
