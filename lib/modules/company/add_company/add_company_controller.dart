import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:urgent/core/services/api_error_handler.dart';
import 'package:urgent/core/services/firestore_services/companydata_service.dart';
import '../../../core/themes/themes.dart';

class AddCompanyController extends GetxController {
  final formKey = GlobalKey<FormState>();

  final companyNameController = TextEditingController();
  final companyDescriptionController = TextEditingController();

  final FirestoreCompanyService _firestoreService =
      Get.find<FirestoreCompanyService>();
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

  Future<void> onAddCompanyPressed() async {
    if (_isLoading.value) return;
    if (!(formKey.currentState?.validate() ?? false)) return;

    _isLoading.value = true;
    try {
      final companyName = companyNameController.text.trim();
      final companyDescription = companyDescriptionController.text.trim();

      final response = await ApiErrorHandler.call(
        () => _firestoreService.AddCompany({
          'name': companyName,
          'description': companyDescription,
          'logoUrl': '',
        }),
        fallbackMessage: 'Failed to add company',
      );

      if (!response.isSuccess) {
        return;
      }

      Get.back();
      Get.snackbar(
        'Company Added',
        '$companyName has been added.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.successLight,
        colorText: AppColors.success,
        icon: const Icon(Icons.check_circle_rounded, color: AppColors.success),
      );
    } finally {
      _isLoading.value = false;
    }
  }

  void onClearPressed() {
    companyNameController.clear();
    companyDescriptionController.clear();
  }

  @override
  void onClose() {
    companyNameController.dispose();
    companyDescriptionController.dispose();
    super.onClose();
  }
}
