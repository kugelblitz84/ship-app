import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/api_error_handler.dart';
import '../../../core/services/firestore_services/shipdata_service.dart';
import '../../../core/themes/themes.dart';

class AddShipController extends GetxController {
  final formKey = GlobalKey<FormState>();

  final shipNameController = TextEditingController();
  final licenseNumberController = TextEditingController();

  final FirestoreShipService _shipService = Get.find<FirestoreShipService>();

  final RxBool _isLoading = false.obs;
  bool get isLoading => _isLoading.value;

  FormFieldValidator<String> requiredValidator(String fieldLabel) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return '$fieldLabel is required';
      }
      return null;
    };
  }

  Future<void> onAddShipPressed() async {
    if (_isLoading.value) return;
    if (!(formKey.currentState?.validate() ?? false)) return;

    _isLoading.value = true;
    try {
      final response = await ApiErrorHandler.call(
        () => _shipService.addShip(
          shipName: shipNameController.text.trim(),
          licenseNumber: licenseNumberController.text.trim(),
        ),
        fallbackMessage: 'Failed to add ship',
      );

      if (!response.isSuccess) {
        return;
      }
      print(response.isSuccess);

      Get.back();
      Get.snackbar(
        'Ship Added',
        '${shipNameController.text.trim()} has been added.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.successLight,
        colorText: AppColors.success,
        icon: const Icon(Icons.check_circle_rounded, color: AppColors.success),
      );
    } finally {
      _isLoading.value = false;
    }
  }

  @override
  void onClose() {
    shipNameController.dispose();
    licenseNumberController.dispose();
    super.onClose();
  }
}
