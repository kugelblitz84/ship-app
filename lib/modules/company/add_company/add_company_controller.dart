import 'package:get/get.dart';
import 'package:urgent/core/services/firestore_services/shipdata_service.dart';
import 'package:urgent/core/widgets/app_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:urgent/core/services/api_error_handler.dart';
import 'package:urgent/core/services/firestore_services/companydata_service.dart';
import '../../../core/themes/themes.dart';
//import '../../../core/services/firestore_services/companydata_service.dart';
import '../models/company_model.dart';
import '../../ship/models/ship_model.dart';

class AddCompanyController extends GetxController {
  final formKey = GlobalKey<FormState>();
  final companyNameController = TextEditingController();
  final companyDescriptionController = TextEditingController();
  final openingDueAmountController = TextEditingController();
  final openingDueDateController = TextEditingController();
  final openingDueDescriptionController = TextEditingController();

  final FirestoreCompanyService _companyService =
      Get.find<FirestoreCompanyService>();
  final FirestoreShipService _shipService = Get.find<FirestoreShipService>();
  final RxList<ShipModel> ships = <ShipModel>[].obs;
  final RxBool _isShipsLoading = false.obs;
  bool get isShipsLoading => _isShipsLoading.value;
  final RxBool includeOpeningDue = false.obs;
  final RxBool _isLoading = false.obs;
  bool get isLoading => _isLoading.value;

  @override
  void onInit() {
    super.onInit();
    //loadCompanies();
    loadShips();
  }

  // Future<void> loadCompanies() async {
  //   _isCompaniesLoading.value = true;

  //   final response = await ApiErrorHandler.call(
  //     () => _companyService.getCompaniesSortedByName(),
  //     fallbackMessage: 'Failed to load companies',
  //     showErrorSnackbar: true,
  //   );

  //   if (response.isSuccess && response.data != null) {
  //     companies.assignAll(response.data!);
  //   }

  //   _isCompaniesLoading.value = false;
  // }

  Future<void> loadShips() async {
    _isShipsLoading.value = true;

    final response = await ApiErrorHandler.call(
      () => _shipService.getShips(),
      fallbackMessage: 'Failed to load ships',
      showErrorSnackbar: true,
    );

    if (response.isSuccess && response.data != null) {
      ships.assignAll(response.data!);
    }

    _isShipsLoading.value = false;
  }

  FormFieldValidator<String> requiredValidator(String fieldLabel) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return '$fieldLabel is required';
      }
      return null;
    };
  }

  FormFieldValidator<String> openingDueAmountValidator() {
    return (value) {
      if (!includeOpeningDue.value) return null;
      final raw = (value ?? '').trim();
      if (raw.isEmpty) return 'Opening due amount is required';

      final parsed = _toDouble(raw);
      if (parsed == null || parsed <= 0) {
        return 'Enter a valid amount greater than 0';
      }
      return null;
    };
  }

  FormFieldValidator<String> openingDueDateValidator() {
    return (value) {
      if (!includeOpeningDue.value) return null;
      final raw = (value ?? '').trim();
      if (raw.isEmpty) return 'Opening due date is required';
      if (_tryParseDate(raw) == null) return 'Use a valid date';
      return null;
    };
  }

  void onIncludeOpeningDueChanged(bool value) {
    includeOpeningDue.value = value;
    if (value && openingDueDateController.text.trim().isEmpty) {
      openingDueDateController.text = _formatDate(DateTime.now());
    }
  }

  Future<void> onPickOpeningDueDatePressed(BuildContext context) async {
    final now = DateTime.now();
    final current = _tryParseDate(openingDueDateController.text.trim()) ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 10),
    );

    if (picked == null) return;
    openingDueDateController.text = _formatDate(picked);
  }

  Future<void> onAddCompanyPressed() async {
    if (_isLoading.value) return;
    if (!(formKey.currentState?.validate() ?? false)) return;

    _isLoading.value = true;
    try {
      final companyName = companyNameController.text.trim();
      final companyDescription = companyDescriptionController.text.trim();
      final openingDueAmount = includeOpeningDue.value
          ? _formatAmount(
              _toDouble(openingDueAmountController.text.trim()) ?? 0,
            )
          : '0';
      final openingDueDate = includeOpeningDue.value
          ? openingDueDateController.text.trim()
          : '';
      final openingDueDescription = includeOpeningDue.value
          ? openingDueDescriptionController.text.trim()
          : '';

      final response = await ApiErrorHandler.call(
        () => _companyService.AddCompany({
          'name': companyName,
          'description': companyDescription,
          'logoUrl': '',
          'openingDueAmount': openingDueAmount,
          'openingDueDate': openingDueDate,
          'openingDueDescription': openingDueDescription,
        }),
        fallbackMessage: 'Failed to add company',
      );

      if (!response.isSuccess) {
        return;
      }

      Get.back();
      showAppSnackbar(
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
    openingDueAmountController.clear();
    openingDueDateController.clear();
    openingDueDescriptionController.clear();
    includeOpeningDue.value = false;
  }

  @override
  void onClose() {
    companyNameController.dispose();
    companyDescriptionController.dispose();
    openingDueAmountController.dispose();
    openingDueDateController.dispose();
    openingDueDescriptionController.dispose();
    super.onClose();
  }

  DateTime? _tryParseDate(String value) {
    if (value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  double? _toDouble(String value) {
    final sanitized = value.replaceAll(',', '').trim();
    if (sanitized.isEmpty) return null;
    return double.tryParse(sanitized);
  }

  String _formatAmount(double value) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'\.00$'), '');
  }
}
