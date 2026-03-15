import 'package:get/get.dart';
import 'package:urgent/core/widgets/app_snackbar.dart';
import '../../../core/services/api_error_handler.dart';
import '../../../core/services/firestore_services/companydata_service.dart';
import '../../../core/services/firestore_services/shipdata_service.dart';
import '../../../core/services/firestore_services/transactiondata_service.dart';
import '../../../core/services/firestore_services/tripdata_service.dart';
import '../../../core/themes/themes.dart';
import '../../Transactions/models/transaction_model.dart' as tx_models;
import '../../home/home_controller.dart';
import '../../company/models/company_model.dart';
import '../../ship/models/ship_model.dart';
import '../models/trip_model.dart';
import 'package:flutter/material.dart';

class AddTripController extends GetxController {
  final formKey = GlobalKey<FormState>();
  final TextEditingController fromController = TextEditingController();
  final TextEditingController toController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController productController = TextEditingController();
  final TextEditingController productQuantityController = TextEditingController(
    text: '1',
  );
  final TextEditingController productUnitController = TextEditingController(
    text: 'kg',
  );
  final TextEditingController productDescriptionController =
      TextEditingController();
  final TextEditingController rateController = TextEditingController();
  final TextEditingController totalBillController = TextEditingController(
    text: '0',
  );

  final FirestoreCompanyService _companyService =
      Get.find<FirestoreCompanyService>();
  final FirestoreShipService _shipService = Get.find<FirestoreShipService>();
  final FirestoreTripService _tripService = Get.find<FirestoreTripService>();
  final FirestoreTransactionService _transactionService =
      Get.find<FirestoreTransactionService>();

  final RxBool _isLoading = false.obs;
  bool get isLoading => _isLoading.value;

  final RxBool _isCompaniesLoading = true.obs;
  bool get isCompaniesLoading => _isCompaniesLoading.value;

  final RxBool _isShipsLoading = true.obs;
  bool get isShipsLoading => _isShipsLoading.value;

  final RxList<CompanyModel> companies = <CompanyModel>[].obs;
  final RxList<ShipModel> ships = <ShipModel>[].obs;
  final List<String> productUnits = const ['kg', 'piece', 'ton'];
  // Dropdown values now use names directly since names are unique IDs.
  final RxnString selectedCompanyName = RxnString();
  final RxnString selectedShipName = RxnString();
  final RxString totalBillDisplay = '--'.obs;

  CompanyAndShipInfo? selectedCompanyAndShip;

  @override
  void onInit() {
    super.onInit();
    rateController.addListener(_recalculateTotalBill);
    productQuantityController.addListener(_recalculateTotalBill);
    loadCompanies();
    loadShips();
  }

  bool get hasAnyValue =>
      fromController.text.trim().isNotEmpty ||
      toController.text.trim().isNotEmpty ||
      dateController.text.trim().isNotEmpty ||
      productController.text.trim().isNotEmpty ||
      productQuantityController.text.trim().isNotEmpty ||
      productUnitController.text.trim().isNotEmpty ||
      productDescriptionController.text.trim().isNotEmpty ||
      rateController.text.trim().isNotEmpty ||
      selectedCompanyName.value != null ||
      selectedCompanyAndShip != null;

  void onProductUnitChanged(String? unit) {
    if (unit == null || unit.trim().isEmpty) return;
    productUnitController.text = unit;
  }

  FormFieldValidator<String> requiredValidator(String fieldLabel) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return '$fieldLabel is required';
      }
      return null;
    };
  }

  String? quantityValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Quantity is required';
    }
    final parsed = _tryParseAmount(value);
    if (parsed == null || parsed <= 0) {
      return 'Quantity must be greater than zero';
    }
    return null;
  }

  String? companyValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Company is required';
    }
    return null;
  }

  void onCompanyChanged(String? companyName) {
    selectedCompanyName.value = companyName;
    _buildCompanyAndShipSelection();
  }

  String? shipValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ship is required';
    }
    return null;
  }

  void onShipChanged(String? shipName) {
    selectedShipName.value = shipName;
    _buildCompanyAndShipSelection();
  }

  Future<void> loadCompanies() async {
    _isCompaniesLoading.value = true;

    final response = await ApiErrorHandler.call(
      () => _companyService.getCompaniesSortedByName(),
      fallbackMessage: 'Failed to load companies',
      showErrorSnackbar: true,
    );

    if (response.isSuccess && response.data != null) {
      companies.assignAll(response.data!);
    }

    _isCompaniesLoading.value = false;
  }

  void _buildCompanyAndShipSelection() {
    final companyName = selectedCompanyName.value;
    final shipName = selectedShipName.value;

    if (companyName == null || shipName == null) {
      selectedCompanyAndShip = null;
      return;
    }

    final selectedCompany = companies.firstWhereOrNull(
      (item) => item.name == companyName,
    );

    final selectedShip = ships.firstWhereOrNull(
      (item) => item.name == shipName,
    );

    if (selectedCompany == null || selectedShip == null) {
      selectedCompanyAndShip = null;
      return;
    }

    selectedCompanyAndShip = CompanyAndShipInfo(
      shipName: selectedShip.name,
      companyName: selectedCompany.name,
    );
  }

  Future<void> loadShips() async {
    _isShipsLoading.value = true;

    final response = await ApiErrorHandler.call(
      () => _shipService.getShips(),
      fallbackMessage: 'Failed to load ships',
      showErrorSnackbar: true,
    );

    if (response.isSuccess && response.data != null) {
      ships.assignAll(response.data!);
      _buildCompanyAndShipSelection();
    }

    _isShipsLoading.value = false;
  }

  Future<void> onPickDatePressed(BuildContext context) async {
    final now = DateTime.now();
    final current = _tryParseDate(dateController.text.trim()) ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 10),
    );

    if (picked == null) return;

    dateController.text =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
  }

  DateTime? _tryParseDate(String value) {
    if (value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  void _recalculateTotalBill() {
    final rate = _tryParseAmount(rateController.text);
    final quantity = _tryParseAmount(productQuantityController.text);

    if (rate == null || quantity == null) {
      totalBillController.text = '';
      totalBillDisplay.value = '--';
      return;
    }

    final owed = rate * quantity;
    final formatted = _formatAmount(owed);
    totalBillController.text = formatted;
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

  Future<void> onAddTripPressed() async {
    if (_isLoading.value) return;
    if (!(formKey.currentState?.validate() ?? false)) return;
    if (selectedCompanyAndShip == null) {
      showAppSnackbar('Error', 'Please select company and ship');
      return;
    }
    if (totalBillController.text.trim().isEmpty) {
      showAppSnackbar('Error', 'Enter valid rate and quantity');
      return;
    }

    _isLoading.value = true;
    try {
      final productName = productController.text.trim();
      final quantity = productQuantityController.text.trim();
      final unit = productUnitController.text.trim();
      final description = productDescriptionController.text.trim();

      if (productName.isEmpty) {
        showAppSnackbar('Error', 'Product name is required');
        return;
      }
      if (quantity.isEmpty || _tryParseAmount(quantity) == null) {
        showAppSnackbar('Error', 'Quantity is required');
        return;
      }
      if (unit.isEmpty) {
        showAppSnackbar('Error', 'Unit is required');
        return;
      }

      final trip = TripModel(
        tripId: _tripService.createTripId(),
        from: fromController.text.trim(),
        to: toController.text.trim(),
        date: dateController.text.trim(),
        companyAndShipInfo: selectedCompanyAndShip!,
        rate: rateController.text.trim(),
        totalBill: totalBillController.text.trim(),
        product: ProductInfo(
          productName: productName,
          quantity: quantity,
          unit: unit,
          desctription: description.isEmpty ? null : description,
        ),
      );

      final response = await ApiErrorHandler.call(() async {
        await _tripService.addTrip(trip: trip);

        final tripTransaction = tx_models.TransactionModel(
          transactionId: _transactionService.createTransactionId(),
          transactionType: 'trips',
          expenseSource: 'company',
          companyAndShipInfo: tx_models.CompanyAndShipInfo(
            companyName: selectedCompanyAndShip!.companyName,
            shipName: selectedCompanyAndShip!.shipName,
          ),
          tripId: trip.tripId,
          tripFrom: trip.from,
          tripTo: trip.to,
          description: description.isEmpty ? null : description,
          amount: trip.totalBill,
          totalPrice: '0',
          amountDue: '0',
          date: trip.date,
          type: 'trip',
        );

        await _transactionService.addTransaction(transaction: tripTransaction);
      }, fallbackMessage: 'Failed to add trip');

      if (!response.isSuccess) return;

      if (Get.isRegistered<HomeController>()) {
        await Get.find<HomeController>().loadHomeData();
      }

      clear();
      Get.back();
      showAppSnackbar(
        'Trip Added',
        '${trip.from} to ${trip.to} has been added successfully.',
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
    rateController.removeListener(_recalculateTotalBill);
    productQuantityController.removeListener(_recalculateTotalBill);
    fromController.dispose();
    toController.dispose();
    dateController.dispose();
    productController.dispose();
    productQuantityController.dispose();
    productUnitController.dispose();
    productDescriptionController.dispose();
    rateController.dispose();
    totalBillController.dispose();
    super.onClose();
  }

  void clear() {
    fromController.clear();
    toController.clear();
    dateController.clear();
    productController.clear();
    productQuantityController.text = '1';
    productUnitController.text = productUnits.first;
    productDescriptionController.clear();
    rateController.clear();
    totalBillController.clear();
    totalBillDisplay.value = '--';
    selectedCompanyAndShip = null;
    selectedCompanyName.value = null;
    selectedShipName.value = null;
  }
}
