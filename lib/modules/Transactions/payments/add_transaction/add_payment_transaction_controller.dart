import 'package:flutter/material.dart';
import 'package:urgent/core/widgets/app_snackbar.dart';
import 'package:get/get.dart';

import '../../../../core/services/api_error_handler.dart';
import '../../../../core/services/firebase_auth_service.dart';
import '../../../../core/services/firestore_services/companydata_service.dart';
import '../../../../core/services/firestore_services/shipdata_service.dart';
import '../../../../core/services/firestore_services/transactiondata_service.dart';
import '../../../../core/services/firestore_services/tripdata_service.dart';
import '../../../../core/themes/themes.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../home/home_controller.dart';
import '../../../company/models/company_model.dart';
import '../../../ship/models/ship_model.dart';
import '../../../trip/models/trip_model.dart' show TripModel;
import '../../models/transaction_model.dart';

class AddTransactionController extends GetxController {
  final formKey = GlobalKey<FormState>();

  final TextEditingController amountController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  final FirestoreCompanyService _companyService =
      Get.find<FirestoreCompanyService>();
  final FirestoreShipService _shipService = Get.find<FirestoreShipService>();
  final FirestoreTripService _tripService = Get.find<FirestoreTripService>();
  final FirestoreTransactionService _transactionService =
      Get.find<FirestoreTransactionService>();
  final AuthService _authService = Get.find<AuthService>();

  final RxBool _isLoading = false.obs;
  bool get isLoading => _isLoading.value;

  final RxBool _isTripsLoading = true.obs;
  bool get isTripsLoading => _isTripsLoading.value;

  final RxBool _isCompaniesLoading = true.obs;
  bool get isCompaniesLoading => _isCompaniesLoading.value;

  final RxBool _isShipsLoading = true.obs;
  bool get isShipsLoading => _isShipsLoading.value;

  final RxList<CompanyModel> companies = <CompanyModel>[].obs;
  final RxList<ShipModel> ships = <ShipModel>[].obs;
  final RxList<TripModel> trips = <TripModel>[].obs;
  final RxList<TransactionModel> transactions = <TransactionModel>[].obs;
  final RxnString selectedCompanyName = RxnString();
  final RxnString selectedShipName = RxnString();
  final RxnString selectedTripId = RxnString();
  final RxnString selectedType = RxnString();

  final RxString currentReceivedDisplay = '--'.obs;
  final RxString currentDueDisplay = '--'.obs;

  CompanyModel? selectedCompany;
  ShipModel? selectedShip;
  TripModel? selectedTrip;

  final RxList<String> transactionTypes = <String>[].obs;
  final RxBool isDeletingMethod = false.obs;

  @override
  void onInit() {
    super.onInit();
    amountController.addListener(_updateCompanySummary);
    _setTransactionMethods();
    _setTodayDate();
    loadCompanies();
    loadShips();
    loadTrips();
    loadTransactions();
  }

  Future<void> _setTransactionMethods() async {
    final response = await ApiErrorHandler.call(
      () => _transactionService.setTransactionMethods(),
      fallbackMessage: 'Failed to load transaction methods',
      showErrorSnackbar: true,
    );

    if (response.isSuccess) {
      transactionTypes.clear();
      transactionTypes.addAll(_transactionService.allowedTypes);
    }
  }

  /// Persists a new transaction method via the API without updating reactive state.
  /// Returns the normalised type name on success, or `null` on failure.
  Future<String?> saveTransactionMethod(String type) async {
    final normalizedType = _normalize(type);

    if (normalizedType.isEmpty) {
      showAppSnackbar('Error', 'Transaction method is required');
      return null;
    }

    final response = await ApiErrorHandler.call(
      () => _transactionService.addTransactionMethod(normalizedType),
      fallbackMessage: 'Failed to add transaction method',
      showErrorSnackbar: true,
    );

    if (!response.isSuccess) return null;

    return normalizedType;
  }

  /// Updates reactive lists/selection after the dialog is fully closed.
  void applyTransactionMethod(String normalizedType) {
    if (!transactionTypes.contains(normalizedType)) {
      transactionTypes.add(normalizedType);
    }
    selectedType.value = normalizedType;
  }

  Future<bool> deleteTransactionMethodWithPassword({
    required String method,
    required String password,
  }) async {
    final normalizedMethod = _normalize(method);
    final trimmedPassword = password.trim();

    if (normalizedMethod.isEmpty) {
      showAppSnackbar('Error', 'Transaction method is required');
      return false;
    }

    if (trimmedPassword.isEmpty) {
      showAppSnackbar('Error', 'Password is required');
      return false;
    }

    if (isDeletingMethod.value) return false;

    isDeletingMethod.value = true;
    try {
      final reauthResponse = await ApiErrorHandler.call(
        () => _authService.reauthenticate(trimmedPassword),
        fallbackMessage: 'Failed to verify password',
      );
      if (!reauthResponse.isSuccess) return false;

      final deleteResponse = await ApiErrorHandler.call(
        () => _transactionService.deleteTransactionMethod(normalizedMethod),
        fallbackMessage: 'Failed to delete transaction method',
      );
      if (!deleteResponse.isSuccess) return false;

      transactionTypes.removeWhere(
        (type) => _normalize(type) == normalizedMethod,
      );
      if (_normalize(selectedType.value ?? '') == normalizedMethod) {
        selectedType.value = null;
      }
      return true;
    } finally {
      isDeletingMethod.value = false;
    }
  }

  Future<void> onDeleteTransactionMethodPressed(
    BuildContext context,
    String method,
  ) async {
    final deleted = await showPasswordConfirmDeletionDialog(
      context: context,
      title: 'Delete Transaction Method',
      message: 'Enter your password to delete "$method".',
      onConfirm: (password) => deleteTransactionMethodWithPassword(
        method: method,
        password: password,
      ),
    );

    if (!deleted) return;

    showAppSnackbar(
      'Method Deleted',
      'Transaction method deleted successfully.',
      snackPosition: SnackPosition.TOP,
      backgroundColor: AppColors.successLight,
      colorText: AppColors.success,
      icon: const Icon(Icons.check_circle_rounded, color: AppColors.success),
    );
  }

  FormFieldValidator<String> requiredValidator(String fieldLabel) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return '$fieldLabel is required';
      }
      return null;
    };
  }

  String? amountValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Amount is required';
    }
    final amount = _toDouble(value);
    if (amount <= 0) {
      return 'Amount must be greater than zero';
    }

    return null;
  }

  String? companyValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Company is required';
    }
    return null;
  }

  String? shipValidator(String? value) {
    // Ship is optional for payments.
    return null;
  }

  String? typeValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Transaction type is required';
    }
    return null;
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

  Future<void> loadTrips() async {
    _isTripsLoading.value = true;

    final response = await ApiErrorHandler.call(
      () => _tripService.getTripsSortedByDateDesc(),
      fallbackMessage: 'Failed to load trips',
      showErrorSnackbar: true,
    );

    if (response.isSuccess && response.data != null) {
      trips.assignAll(response.data!);
    }

    _isTripsLoading.value = false;
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
    }

    _isShipsLoading.value = false;
  }

  Future<void> loadTransactions() async {
    final response = await ApiErrorHandler.call(
      () => _transactionService.getTransactions(),
      fallbackMessage: 'Failed to load transactions',
      showErrorSnackbar: true,
    );

    if (response.isSuccess && response.data != null) {
      transactions.assignAll(response.data!);
      _updateCompanySummary();
    }
  }

  void onCompanyChanged(String? companyName) {
    selectedCompanyName.value = companyName;

    if (companyName == null) {
      selectedCompany = null;
      selectedTrip = null;
      selectedTripId.value = null;
      _updateCompanySummary();
      return;
    }

    selectedCompany = companies.firstWhereOrNull(
      (company) => _normalize(company.name) == _normalize(companyName),
    );

    if (selectedTrip != null &&
        _normalize(selectedTrip!.companyAndShipInfo.companyName) !=
            _normalize(companyName)) {
      selectedTrip = null;
      selectedTripId.value = null;
    }

    _updateCompanySummary();
  }

  void onTripChanged(String? tripId) {
    selectedTripId.value = tripId;

    if (tripId == null) {
      selectedTrip = null;
      _updateCompanySummary();
      return;
    }

    selectedTrip = trips.firstWhereOrNull((trip) => trip.tripId == tripId);
    if (selectedTrip != null) {
      final tripCompany = selectedTrip!.companyAndShipInfo.companyName;
      final tripShip = selectedTrip!.companyAndShipInfo.shipName;
      selectedCompanyName.value = tripCompany;
      selectedCompany = companies.firstWhereOrNull(
        (company) => _normalize(company.name) == _normalize(tripCompany),
      );
      selectedShip = ships.firstWhereOrNull(
        (ship) => _normalize(ship.name) == _normalize(tripShip),
      );
      selectedShipName.value = selectedShip?.name;
    }
    _updateCompanySummary();
  }

  void onShipChanged(String? shipName) {
    selectedShipName.value = shipName;
    if (shipName == null) {
      selectedShip = null;
      return;
    }

    selectedShip = ships.firstWhereOrNull(
      (ship) => _normalize(ship.name) == _normalize(shipName),
    );
  }

  void onTypeChanged(String? type) {
    selectedType.value = type;
  }

  Future<void> onAddTransactionPressed() async {
    if (_isLoading.value) return;
    if (!(formKey.currentState?.validate() ?? false)) {
      showAppSnackbar(
        'Missing Information',
        'Please complete all required fields before submitting.',
      );
      return;
    }
    if (selectedCompany == null) {
      showAppSnackbar('Error', 'Please select a company');
      return;
    }
    if ((selectedType.value ?? '').trim().isEmpty) {
      showAppSnackbar('Error', 'Please select a transaction type');
      return;
    }

    _isLoading.value = true;
    try {
      final paidAmount = _toDouble(amountController.text.trim());
      final company = selectedCompany!;

      final linkedTrip = selectedTrip;

      final transaction = TransactionModel(
        transactionId: _transactionService.createTransactionId(),
        transactionType: 'payment',
        companyAndShipInfo: CompanyAndShipInfo(
          companyName: company.name,
          shipName: selectedShip?.name ?? '',
        ),
        tripId: linkedTrip?.tripId ?? '',
        tripFrom: linkedTrip?.from ?? '',
        tripTo: linkedTrip?.to ?? '',
        description: descriptionController.text.trim(),
        amount: amountController.text.trim(),
        totalPrice: company.totalAmountBilled,
        amountDue: _formatAmount(
          _toDouble(company.totalAmountDue) - paidAmount,
        ),
        date: dateController.text.trim(),
        type: selectedType.value!.trim(),
      );

      final response = await ApiErrorHandler.call(
        () => _transactionService.addTransaction(transaction: transaction),
        fallbackMessage: 'Failed to add transaction',
        showErrorSnackbar: true,
      );

      if (!response.isSuccess) return;

      clear();
      await loadCompanies();
      await loadShips();
      await loadTrips();
      await loadTransactions();
      if (Get.isRegistered<HomeController>()) {
        await Get.find<HomeController>().loadHomeData();
      }
      Get.back();
      showAppSnackbar(
        'Transaction Added',
        'Payment recorded and company due updated successfully.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.successLight,
        colorText: AppColors.success,
        icon: const Icon(Icons.check_circle_rounded, color: AppColors.success),
      );
    } finally {
      _isLoading.value = false;
    }
  }

  void _setTodayDate() {
    dateController.text = _todayDateString();
  }

  String _todayDateString() => _formatDate(DateTime.now());

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

    dateController.text = _formatDate(picked);
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

  List<TripModel> get visibleTrips {
    final companyName = selectedCompanyName.value;
    if (companyName == null || companyName.trim().isEmpty) {
      return trips;
    }

    return trips
        .where(
          (trip) =>
              _normalize(trip.companyAndShipInfo.companyName) ==
              _normalize(companyName),
        )
        .toList();
  }

  void _updateCompanySummary() {
    if (selectedCompany == null) {
      currentReceivedDisplay.value = '--';
      currentDueDisplay.value = '--';
      return;
    }

    final received = _getSelectedCompanyReceivedAmount();
    final due = _getSelectedCompanyDueAmount();

    final enteredAmount = _toDouble(amountController.text);

    final updatedReceived = received + enteredAmount;
    final updatedDue = due - enteredAmount;

    currentReceivedDisplay.value = _formatAmount(updatedReceived);
    currentDueDisplay.value = _formatAmount(updatedDue.toDouble());
  }

  double _getSelectedCompanyReceivedAmount() {
    if (selectedCompany == null) return 0;

    final companyName = selectedCompany!.name;
    final storedReceived = _toDouble(selectedCompany!.totalAmountReceived);

    if (storedReceived > 0) {
      return storedReceived;
    }

    return transactions
        .where(
          (transaction) =>
              _normalize(transaction.companyAndShipInfo.companyName ?? '') ==
                  _normalize(companyName) &&
              transaction.transactionType.trim().toLowerCase() == 'payment',
        )
        .fold<double>(
          0,
          (sum, transaction) => sum + _toDouble(transaction.amount),
        );
  }

  double _getSelectedCompanyDueAmount() {
    if (selectedCompany == null) return 0;

    final companyName = selectedCompany!.name;

    final storedBilled = _toDouble(selectedCompany!.totalAmountBilled);
    final storedReceived = _toDouble(selectedCompany!.totalAmountReceived);
    final storedDue = _toDouble(selectedCompany!.totalAmountDue);

    if (storedDue != 0) {
      return storedDue;
    }

    final fallbackBilled = trips
        .where(
          (trip) =>
              _normalize(trip.companyAndShipInfo.companyName ?? '') ==
              _normalize(companyName),
        )
        .fold<double>(0, (sum, trip) => sum + _toDouble(trip.totalBill));

    final fallbackReceived = transactions
        .where(
          (transaction) =>
              _normalize(transaction.companyAndShipInfo.companyName ?? '') ==
                  _normalize(companyName) &&
              transaction.transactionType.trim().toLowerCase() == 'payment',
        )
        .fold<double>(
          0,
          (sum, transaction) => sum + _toDouble(transaction.amount),
        );

    final fallbackCompanyDueExpenses = transactions
        .where(
          (transaction) =>
              _normalize(transaction.companyAndShipInfo.companyName ?? '') ==
                  _normalize(companyName) &&
              transaction.transactionType.trim().toLowerCase() == 'expenses' &&
              transaction.expenseSource.trim().toLowerCase() == 'company',
        )
        .fold<double>(
          0,
          (sum, transaction) => sum + _toDouble(transaction.amount),
        );

    final billed = storedBilled > 0 ? storedBilled : fallbackBilled;
    final received = storedReceived > 0 ? storedReceived : fallbackReceived;

    return billed - received - fallbackCompanyDueExpenses;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) {
      final sanitized = value.replaceAll(',', '').trim();
      if (sanitized.isEmpty) return 0;
      return double.tryParse(sanitized) ?? 0;
    }
    return 0;
  }

  String _formatAmount(double value) {
    return value.toInt().toString();
  }

  String _normalize(String value) {
    return value.trim().toLowerCase();
  }

  void clear() {
    amountController.clear();
    descriptionController.clear();
    selectedCompany = null;
    selectedCompanyName.value = null;
    selectedShip = null;
    selectedShipName.value = null;
    selectedTrip = null;
    selectedTripId.value = null;
    selectedType.value = null;
    currentReceivedDisplay.value = '--';
    currentDueDisplay.value = '--';
    _setTodayDate();
  }

  @override
  void onClose() {
    amountController.removeListener(_updateCompanySummary);
    amountController.dispose();
    dateController.dispose();
    descriptionController.dispose();
    super.onClose();
  }
}
