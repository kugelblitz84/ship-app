import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:urgent/modules/Transactions/models/transaction_model.dart';

import '../../../../core/services/api_error_handler.dart';
import '../../../../core/services/firebase_auth_service.dart';
import '../../../../core/services/firestore_services/companydata_service.dart';
import '../../../../core/services/firestore_services/shipdata_service.dart';
import '../../../../core/services/firestore_services/transactiondata_service.dart';
import '../../../../core/themes/themes.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../home/home_controller.dart';
import '../../../company/models/company_model.dart';
import '../../../ship/models/ship_model.dart';

class AddExpensesTransactionController extends GetxController {
  final formKey = GlobalKey<FormState>();

  final TextEditingController amountController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  final FirestoreCompanyService _companyService =
      Get.find<FirestoreCompanyService>();
  final FirestoreShipService _shipService = Get.find<FirestoreShipService>();
  final FirestoreTransactionService _transactionService =
      Get.find<FirestoreTransactionService>();
  final AuthService _authService = Get.find<AuthService>();

  final RxBool _isLoading = false.obs;
  bool get isLoading => _isLoading.value;

  final RxBool _isCompaniesLoading = true.obs;
  bool get isCompaniesLoading => _isCompaniesLoading.value;

  final RxBool _isShipsLoading = true.obs;
  bool get isShipsLoading => _isShipsLoading.value;

  final RxList<CompanyModel> companies = <CompanyModel>[].obs;
  final RxList<ShipModel> ships = <ShipModel>[].obs;
  final RxList<TransactionModel> transactions = <TransactionModel>[].obs;
  final RxnString selectedCompanyName = RxnString();
  final RxnString selectedShipName = RxnString();
  final RxnString selectedType = RxnString();
  final RxString selectedExpenseSource = 'company'.obs;

  final RxString currentReceivedDisplay = '--'.obs;
  final RxString currentDueDisplay = '--'.obs;
  final RxString currentMainBalanceDisplay = '0'.obs;
  final RxString updatedMainBalanceDisplay = '0'.obs;

  CompanyModel? selectedCompany;
  ShipModel? selectedShip;

  final RxList<String> transactionTypes = <String>[].obs;
  final RxBool isDeletingMethod = false.obs;

  static const List<String> expenseSources = <String>[
    'company',
    'main-balance',
  ];

  @override
  void onInit() {
    super.onInit();
    amountController.addListener(_updateCompanySummary);
    amountController.addListener(_updateMainBalancePreview);
    _setTransactionMethods();
    _setTodayDate();
    loadCompanies();
    loadShips();
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
      Get.snackbar('Error', 'Transaction method is required');
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
      Get.snackbar('Error', 'Transaction method is required');
      return false;
    }

    if (trimmedPassword.isEmpty) {
      Get.snackbar('Error', 'Password is required');
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

    Get.snackbar(
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
    if (isCompanySource && (value == null || value.trim().isEmpty)) {
      return 'Company is required';
    }
    return null;
  }

  String? shipValidator(String? value) {
    // Ship is optional for expenses.
    return null;
  }

  String? typeValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Transaction type is required';
    }
    return null;
  }

  String? expenseSourceValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Deduction source is required';
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
      _updateMainBalancePreview();
      _updateCompanySummary();
    }
  }

  void onCompanyChanged(String? companyName) {
    selectedCompanyName.value = companyName;

    if (companyName == null) {
      selectedCompany = null;
      _updateCompanySummary();
      return;
    }

    selectedCompany = companies.firstWhereOrNull(
      (company) => _normalize(company.name) == _normalize(companyName),
    );

    _updateCompanySummary();
  }

  void onExpenseSourceChanged(String? source) {
    if (source == null || source.trim().isEmpty) return;
    selectedExpenseSource.value = source;

    if (selectedExpenseSource.value == 'main-balance') {
      // Main-balance expenses must not keep a company reference.
      selectedCompany = null;
      selectedCompanyName.value = null;
    }

    _updateCompanySummary();
    _updateMainBalancePreview();
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

  bool get isCompanySource => selectedExpenseSource.value == 'company';
  bool get isMainBalanceSource => selectedExpenseSource.value == 'main-balance';

  Future<void> onAddTransactionPressed() async {
    if (_isLoading.value) return;
    if (!(formKey.currentState?.validate() ?? false)) {
      Get.snackbar(
        'Missing Information',
        'Please complete all required fields before submitting.',
      );
      return;
    }
    if (isCompanySource && selectedCompany == null) {
      Get.snackbar('Error', 'Please select a company');
      return;
    }
    if ((selectedType.value ?? '').trim().isEmpty) {
      Get.snackbar('Error', 'Please select a transaction type');
      return;
    }

    _isLoading.value = true;
    try {
      final sourceAtSubmit = selectedExpenseSource.value;
      final expenseAmount = _toDouble(amountController.text.trim());

      final company = selectedCompany;
      final companyDue = company == null
          ? 0.0
          : _toDouble(company.totalAmountDue);

      final transaction = TransactionModel(
        transactionId: _transactionService.createTransactionId(),
        transactionType: 'expenses',
        expenseSource: selectedExpenseSource.value,
        companyAndShipInfo: CompanyAndShipInfo(
          companyName: isCompanySource ? company!.name : '',
          shipName: selectedShip?.name ?? '',
        ),
        description: descriptionController.text.trim(),
        amount: amountController.text.trim(),
        totalPrice: company?.totalAmountBilled ?? '0',
        amountDue: isCompanySource
            ? _formatAmount(companyDue - expenseAmount)
            : _formatAmount(currentMainBalance - expenseAmount),
        date: dateController.text.trim(),
        type: selectedType.value!.trim(),
      );

      final response = await ApiErrorHandler.call(
        () => _transactionService.addTransaction(transaction: transaction),
        fallbackMessage: 'Failed to add expense transaction',
        showErrorSnackbar: true,
      );

      if (!response.isSuccess) return;

      clear();
      await loadCompanies();
      await loadShips();
      await loadTransactions();
      if (Get.isRegistered<HomeController>()) {
        await Get.find<HomeController>().loadHomeData();
      }
      Get.back();
      Get.snackbar(
        'Expense Added',
        sourceAtSubmit == 'company'
            ? 'Expense deducted from the selected company due amount.'
            : 'Expense deducted from main balance successfully.',
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

  void _updateCompanySummary() {
    if (!isCompanySource || selectedCompany == null) {
      currentReceivedDisplay.value = '--';
      currentDueDisplay.value = '--';
      return;
    }

    final received = _getSelectedCompanyReceivedAmount();
    final due = _toDouble(selectedCompany!.totalAmountDue);

    final enteredAmount = _toDouble(amountController.text);

    final updatedReceived = received;
    final updatedDue = due - enteredAmount;

    currentReceivedDisplay.value = _formatAmount(updatedReceived);
    currentDueDisplay.value = _formatAmount(updatedDue.toDouble());
  }

  void _updateMainBalancePreview() {
    currentMainBalanceDisplay.value = _formatAmount(currentMainBalance);

    final enteredAmount = _toDouble(amountController.text);
    final updated = currentMainBalance - enteredAmount;
    updatedMainBalanceDisplay.value = _formatAmount(updated);
  }

  double get currentMainBalance {
    double total = 0;
    for (final transaction in transactions) {
      final amount = _toDouble(transaction.amount);
      final category = transaction.transactionType.trim().toLowerCase();
      final source = transaction.expenseSource.trim().toLowerCase();

      if (category == 'payment') {
        total += amount;
      } else if (category == 'expenses' && source == 'main-balance') {
        total -= amount;
      }
    }
    return total;
  }

  double _getSelectedCompanyReceivedAmount() {
    if (selectedCompany == null) return 0;
    return _toDouble(selectedCompany!.totalAmountReceived);
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
    selectedExpenseSource.value = 'company';
    selectedCompany = null;
    selectedCompanyName.value = null;
    selectedShip = null;
    selectedShipName.value = null;
    selectedType.value = null;
    currentReceivedDisplay.value = '--';
    currentDueDisplay.value = '--';
    currentMainBalanceDisplay.value = _formatAmount(currentMainBalance);
    updatedMainBalanceDisplay.value = _formatAmount(currentMainBalance);
    _setTodayDate();
  }

  @override
  void onClose() {
    amountController.removeListener(_updateCompanySummary);
    amountController.removeListener(_updateMainBalancePreview);
    amountController.dispose();
    dateController.dispose();
    descriptionController.dispose();
    super.onClose();
  }
}
