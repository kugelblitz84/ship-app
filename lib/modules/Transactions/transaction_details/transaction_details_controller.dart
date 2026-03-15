import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:urgent/core/widgets/app_snackbar.dart';

import '../../../core/services/api_error_handler.dart';
import '../../../core/services/firebase_auth_service.dart';
import '../../../core/services/firestore_services/cash_in_cash_out_service.dart';
import '../../../core/services/firestore_services/companydata_service.dart';
import '../../../core/services/firestore_services/shipdata_service.dart';
import '../../../core/services/firestore_services/transactiondata_service.dart';
import '../../../core/services/firestore_services/tripdata_service.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routes/app_routes.dart';
import '../../cashin_cashout/models/cash_in_cash_out_model.dart';
import '../../company/models/company_model.dart';
import '../../home/home_controller.dart';
import '../../ship/models/ship_model.dart';
import '../../trip/trip_history/trip_hisotry_controller.dart';
import '../models/transaction_model.dart';
import '../transactions_history/transaction_history_controller.dart';

class TransactionDetailsController extends GetxController {
  final FirestoreTripService _tripService = Get.find<FirestoreTripService>();
  final FirestoreTransactionService _transactionService =
      Get.find<FirestoreTransactionService>();
  final FirestoreCompanyService _companyService =
      Get.find<FirestoreCompanyService>();
  final FirestoreShipService _shipService = Get.find<FirestoreShipService>();
  final FirestoreCashInCashOutService _cashFlowService =
      Get.find<FirestoreCashInCashOutService>();
  final AuthService _authService = Get.find<AuthService>();

  TransactionModel? transaction;
  final RxBool isDeleting = false.obs;
  final RxBool isEditLoading = false.obs;
  final RxBool isUpdating = false.obs;

  final TextEditingController editAmountController = TextEditingController();
  final TextEditingController editDateController = TextEditingController();
  final TextEditingController editDescriptionController =
      TextEditingController();

  final RxnString editSelectedType = RxnString();
  final RxString editSelectedExpenseSource = 'company'.obs;
  final RxnString editSelectedCompanyName = RxnString();
  final RxnString editSelectedShipName = RxnString();

  final RxString currentCompanyDueDisplay = '--'.obs;
  final RxString updatedCompanyDueDisplay = '--'.obs;
  final RxString currentMainBalanceDisplay = '--'.obs;
  final RxString updatedMainBalanceDisplay = '--'.obs;

  final RxList<String> transactionTypes = <String>[].obs;
  final RxList<CompanyModel> companies = <CompanyModel>[].obs;
  final RxList<ShipModel> ships = <ShipModel>[].obs;
  final RxList<TransactionModel> transactions = <TransactionModel>[].obs;
  final RxList<CashInCashOutModel> cashFlowEntries = <CashInCashOutModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is TransactionModel) {
      transaction = args;
    } else if (args is Map<String, dynamic>) {
      transaction = TransactionModel.fromMap(args);
    }

    editAmountController.addListener(_updateFundPreview);
    _seedEditFields();
    _loadEditDependencies();
  }

  bool get isTripTransaction =>
      transaction?.transactionType.trim().toLowerCase() == 'trips';

  bool get isExpenseTransaction =>
      transaction?.transactionType.trim().toLowerCase() == 'expenses';

  bool get isPaymentTransaction =>
      transaction?.transactionType.trim().toLowerCase() == 'payment';

  bool get isCompanyExpenseEdit =>
      isExpenseTransaction && editSelectedExpenseSource.value == 'company';

  bool get isMainBalanceExpenseEdit =>
      isExpenseTransaction && editSelectedExpenseSource.value == 'main-balance';

  List<String> get availableCompanies =>
      companies.map((item) => item.name).toList(growable: false);

  List<String> get availableShips {
    final selectedCompany = (editSelectedCompanyName.value ?? '').trim();
    if (selectedCompany.isEmpty) {
      return ships.map((item) => item.name).toList(growable: false);
    }

    final fromTransactions = transactions
        .where(
          (item) =>
              _normalize(item.companyAndShipInfo.companyName ?? '') ==
                  _normalize(selectedCompany) &&
              (item.companyAndShipInfo.shipName ?? '').trim().isNotEmpty,
        )
        .map((item) => item.companyAndShipInfo.shipName!.trim())
        .toSet()
        .toList();

    if (fromTransactions.isNotEmpty) {
      fromTransactions.sort((a, b) => a.compareTo(b));
      return fromTransactions;
    }

    return ships.map((item) => item.name).toList(growable: false);
  }

  Future<void> openLinkedTrip() async {
    final current = transaction;
    if (current == null) return;

    final linkedTripId = current.tripId.trim();
    if (linkedTripId.isEmpty) {
      showAppSnackbar(
        'Trip Unavailable',
        'This transaction has no linked trip.',
      );
      return;
    }

    final response = await ApiErrorHandler.call(
      () => _tripService.getTrips(),
      fallbackMessage: 'Failed to load linked trip',
    );
    if (!response.isSuccess || response.data == null) return;

    final trips = response.data!;
    final linkedTrip = trips.firstWhereOrNull(
      (trip) => trip.tripId == linkedTripId,
    );

    if (linkedTrip == null) {
      showAppSnackbar('Trip Not Found', 'Linked trip could not be loaded.');
      return;
    }

    Get.toNamed(AppRoutes.tripDetails, arguments: linkedTrip);
  }

  Future<bool> deleteTransactionWithPassword(String password) async {
    final current = transaction;
    if (current == null || isDeleting.value) return false;

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
        () => _transactionService.deleteTransaction(
          transactionId: current.transactionId,
        ),
        fallbackMessage: 'Failed to delete transaction',
      );
      if (!deleteResponse.isSuccess) return false;

      if (Get.isRegistered<TransactionHistoryController>()) {
        final historyController = Get.find<TransactionHistoryController>();
        historyController.transactions.removeWhere(
          (item) => item.transactionId == current.transactionId,
        );
      }
      if (Get.isRegistered<TripHistoryController>()) {
        Get.find<TripHistoryController>().fetchTripsPage(
          reset: true,
          showLoader: false,
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

  Future<void> onDeleteTransactionPressed(BuildContext context) async {
    final current = transaction;
    if (current == null) return;

    final deleted = await showPasswordConfirmDeletionDialog(
      context: context,
      title: 'Delete Transaction',
      message:
          'Enter your password to delete this transaction of ৳ ${_formatAmount(_toDouble(current.amount))}.',
      onConfirm: deleteTransactionWithPassword,
    );

    if (!deleted) return;

    showAppSnackbar('Success', 'Transaction deleted successfully.');
    Get.back(result: true);
  }

  Future<void> onPickEditDatePressed(BuildContext context) async {
    final now = DateTime.now();
    final current = _tryParseDate(editDateController.text.trim()) ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 10),
    );

    if (picked == null) return;

    editDateController.text = _formatDate(picked);
  }

  void onEditTypeChanged(String? value) {
    editSelectedType.value = value;
  }

  void onEditExpenseSourceChanged(String? value) {
    if (value == null || value.trim().isEmpty) return;
    editSelectedExpenseSource.value = value.trim().toLowerCase();
    if (editSelectedExpenseSource.value == 'main-balance') {
      editSelectedCompanyName.value = null;
    }
    _updateFundPreview();
  }

  void onEditCompanyChanged(String? value) {
    editSelectedCompanyName.value = value;
    _updateFundPreview();
  }

  void onEditShipChanged(String? value) {
    editSelectedShipName.value = value;
  }

  Future<bool> saveEditedTransaction() async {
    final current = transaction;
    if (current == null || isUpdating.value) {
      return false;
    }

    // Force-preserve the original amount for trip transactions to prevent
    // desync with the trip's totalBill (which is derived from rate x quantity).
    if (isTripTransaction) {
      editAmountController.text = current.amount.trim();
    }

    final amount = _toDouble(editAmountController.text);
    if (amount <= 0) {
      showAppSnackbar('Error', 'Amount must be greater than zero.');
      return false;
    }

    final date = editDateController.text.trim();
    if (_tryParseDate(date) == null) {
      showAppSnackbar('Error', 'Date must be in YYYY-MM-DD format.');
      return false;
    }

    final category = current.transactionType.trim().toLowerCase();
    final expenseSource = category == 'expenses'
        ? editSelectedExpenseSource.value.trim().toLowerCase()
        : current.expenseSource.trim().toLowerCase();

    if (category != 'trips') {
      final selectedMethod = (editSelectedType.value ?? '')
          .trim()
          .toLowerCase();
      if (selectedMethod.isEmpty) {
        showAppSnackbar('Error', 'Transaction method is required.');
        return false;
      }
    }

    final needsCompany =
        category == 'payment' ||
        category == 'trips' ||
        (category == 'expenses' && expenseSource == 'company');

    final selectedCompany = (editSelectedCompanyName.value ?? '').trim();
    if (needsCompany && selectedCompany.isEmpty) {
      showAppSnackbar('Error', 'Company is required for this transaction.');
      return false;
    }

    isUpdating.value = true;
    try {
      final updated = TransactionModel(
        transactionId: current.transactionId,
        transactionType: category,
        expenseSource: expenseSource,
        companyAndShipInfo: CompanyAndShipInfo(
          companyName: needsCompany ? selectedCompany : '',
          shipName: (editSelectedShipName.value ?? '').trim(),
        ),
        tripId: current.tripId,
        tripFrom: current.tripFrom,
        tripTo: current.tripTo,
        description: editDescriptionController.text.trim(),
        amount: _formatAmount(amount),
        totalPrice: current.totalPrice,
        amountDue: current.amountDue,
        date: date,
        createdAt: current.createdAt,
        type: category == 'trips'
            ? current.type
            : (editSelectedType.value ?? '').trim(),
      );

      final response = await ApiErrorHandler.call(
        () => _transactionService.updateTransaction(transaction: updated),
        fallbackMessage: 'Failed to update transaction',
        showErrorSnackbar: true,
      );
      if (!response.isSuccess) return false;

      transaction = updated;

      if (Get.isRegistered<TransactionHistoryController>()) {
        final history = Get.find<TransactionHistoryController>();
        final index = history.transactions.indexWhere(
          (item) => item.transactionId == updated.transactionId,
        );
        if (index >= 0) {
          history.transactions[index] = updated;
          history.transactions.refresh();
        }
      }

      if (Get.isRegistered<HomeController>()) {
        await Get.find<HomeController>().loadHomeData();
      }

      await _loadEditDependencies(showLoader: false);
      return true;
    } finally {
      isUpdating.value = false;
    }
  }

  Future<void> _loadEditDependencies({bool showLoader = true}) async {
    if (showLoader) {
      isEditLoading.value = true;
    }

    try {
      final methodsResponse = await ApiErrorHandler.call(
        () => _transactionService.setTransactionMethods(),
        fallbackMessage: 'Failed to load transaction methods',
        showErrorSnackbar: false,
      );
      if (methodsResponse.isSuccess) {
        transactionTypes.assignAll(_transactionService.allowedTypes);
      }

      final companiesResponse = await ApiErrorHandler.call(
        () => _companyService.getCompaniesSortedByName(),
        fallbackMessage: 'Failed to load companies',
        showErrorSnackbar: false,
      );
      if (companiesResponse.isSuccess && companiesResponse.data != null) {
        companies.assignAll(companiesResponse.data!);
      }

      final shipsResponse = await ApiErrorHandler.call(
        () => _shipService.getShips(),
        fallbackMessage: 'Failed to load ships',
        showErrorSnackbar: false,
      );
      if (shipsResponse.isSuccess && shipsResponse.data != null) {
        ships.assignAll(shipsResponse.data!);
      }

      final transactionsResponse = await ApiErrorHandler.call(
        () => _transactionService.getTransactions(),
        fallbackMessage: 'Failed to load transactions',
        showErrorSnackbar: false,
      );
      if (transactionsResponse.isSuccess && transactionsResponse.data != null) {
        transactions.assignAll(transactionsResponse.data!);
      }

      final cashFlowResponse = await ApiErrorHandler.call(
        () => _cashFlowService.getEntriesSortedByDateDesc(),
        fallbackMessage: 'Failed to load cash in/cash out entries',
        showErrorSnackbar: false,
      );
      if (cashFlowResponse.isSuccess && cashFlowResponse.data != null) {
        cashFlowEntries.assignAll(cashFlowResponse.data!);
      }

      if (!isTripTransaction &&
          transactionTypes.isNotEmpty &&
          !transactionTypes.contains(editSelectedType.value)) {
        editSelectedType.value = transactionTypes.first;
      }

      _updateFundPreview();
    } finally {
      if (showLoader) {
        isEditLoading.value = false;
      }
    }
  }

  void _seedEditFields() {
    final current = transaction;
    if (current == null) return;

    editAmountController.text = current.amount.trim();
    editDateController.text = current.date.trim();
    editDescriptionController.text = (current.description ?? '').trim();

    final currentType = current.type.trim().toLowerCase();
    editSelectedType.value = currentType.isEmpty ? null : currentType;

    editSelectedExpenseSource.value = current.expenseSource
        .trim()
        .toLowerCase();

    final companyName = (current.companyAndShipInfo.companyName ?? '').trim();
    editSelectedCompanyName.value = companyName.isEmpty ? null : companyName;

    final shipName = (current.companyAndShipInfo.shipName ?? '').trim();
    editSelectedShipName.value = shipName.isEmpty ? null : shipName;

    _updateFundPreview();
  }

  void _updateFundPreview() {
    final current = transaction;
    if (current == null) {
      currentCompanyDueDisplay.value = '--';
      updatedCompanyDueDisplay.value = '--';
      currentMainBalanceDisplay.value = '--';
      updatedMainBalanceDisplay.value = '--';
      return;
    }

    final editedAmount = _toDouble(editAmountController.text);
    final originalAmount = _toDouble(current.amount);
    final companyName = (editSelectedCompanyName.value ?? '').trim();
    final category = current.transactionType.trim().toLowerCase();
    final source = category == 'expenses'
        ? editSelectedExpenseSource.value.trim().toLowerCase()
        : current.expenseSource.trim().toLowerCase();

    final selectedCompany = companies.firstWhereOrNull(
      (item) => _normalize(item.name) == _normalize(companyName),
    );

    if (selectedCompany == null ||
        !(category == 'payment' ||
            (category == 'expenses' && source == 'company'))) {
      currentCompanyDueDisplay.value = '--';
      updatedCompanyDueDisplay.value = '--';
    } else {
      final currentDue = _toDouble(selectedCompany.totalAmountDue);
      double dueWithoutCurrent = currentDue;

      final originalCategory = current.transactionType.trim().toLowerCase();
      final originalSource = current.expenseSource.trim().toLowerCase();
      final sameCompany =
          _normalize(current.companyAndShipInfo.companyName ?? '') ==
          _normalize(companyName);

      if (sameCompany &&
          (originalCategory == 'payment' ||
              (originalCategory == 'expenses' &&
                  originalSource == 'company'))) {
        dueWithoutCurrent = currentDue + originalAmount;
      }

      final updatedDue = dueWithoutCurrent - editedAmount;
      currentCompanyDueDisplay.value = _formatAmount(dueWithoutCurrent);
      updatedCompanyDueDisplay.value = _formatAmount(updatedDue);
    }

    final baseMainBalance = _mainBalanceExcludingCurrentTransaction(current);
    final updatedMainBalance =
        baseMainBalance +
        _editedContributionToMainBalance(category, source, editedAmount);

    currentMainBalanceDisplay.value = _formatAmount(baseMainBalance);
    updatedMainBalanceDisplay.value = _formatAmount(updatedMainBalance);
  }

  double _mainBalanceExcludingCurrentTransaction(TransactionModel current) {
    double total = 0;

    for (final item in transactions) {
      if (item.transactionId == current.transactionId) {
        continue;
      }

      total += _editedContributionToMainBalance(
        item.transactionType.trim().toLowerCase(),
        item.expenseSource.trim().toLowerCase(),
        _toDouble(item.amount),
      );
    }

    for (final entry in cashFlowEntries) {
      final amount = _toDouble(entry.amount);
      if (amount <= 0) continue;
      total += entry.isCashOut ? -amount : amount;
    }

    return total;
  }

  double _editedContributionToMainBalance(
    String category,
    String source,
    double amount,
  ) {
    if (category == 'payment') {
      return amount;
    }
    if (category == 'expenses' && source == 'main-balance') {
      return -amount;
    }
    return 0;
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

  String _normalize(String value) {
    return value.trim().toLowerCase();
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    final sanitized = value.toString().replaceAll(',', '').trim();
    return double.tryParse(sanitized) ?? 0;
  }

  String _formatAmount(double value) {
    return value.toInt().toString();
  }

  @override
  void onClose() {
    editAmountController.removeListener(_updateFundPreview);
    editAmountController.dispose();
    editDateController.dispose();
    editDescriptionController.dispose();
    super.onClose();
  }
}
