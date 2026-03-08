import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/services/api_error_handler.dart';
import '../../../core/services/firebase_auth_service.dart';
import '../../../core/services/firestore_services/companydata_service.dart';
import '../../../core/services/firestore_services/transactiondata_service.dart';
import '../../../core/services/firestore_services/tripdata_service.dart';
import '../../../routes/app_routes.dart';
import '../../Transactions/models/transaction_model.dart';
import '../../trip/models/trip_model.dart';
import '../models/company_model.dart';
import '../utils/utils.dart';
// import '../utils/utils_legacy.dart' as legacy_statement;

enum StatementTimeFilterType { all, selectedMonth, dateRange }

class CompanyDetailsController extends GetxController {
  final FirestoreCompanyService _companyService =
      Get.find<FirestoreCompanyService>();
  final FirestoreTripService _tripService = Get.find<FirestoreTripService>();
  final FirestoreTransactionService _transactionService =
      Get.find<FirestoreTransactionService>();
  final AuthService _authService = Get.find<AuthService>();

  CompanyModel? company;

  final descriptionController = TextEditingController();

  final RxBool _isLoading = false.obs;
  bool get isLoading => _isLoading.value;

  final RxBool isEditing = false.obs;
  final RxBool isSaving = false.obs;
  final RxBool isDeleting = false.obs;

  final Rx<StatementTimeFilterType> statementFilterType =
      StatementTimeFilterType.all.obs;
  final Rxn<DateTime> statementSelectedMonth = Rxn<DateTime>();
  final Rxn<DateTime> statementRangeStart = Rxn<DateTime>();
  final Rxn<DateTime> statementRangeEnd = Rxn<DateTime>();

  final RxList<TripModel> trips = <TripModel>[].obs;
  final RxList<TransactionModel> transactions = <TransactionModel>[].obs;

  double get totalAmountBilled {
    final companyValue = _toDouble(company?.totalAmountBilled);
    if (companyValue > 0) return companyValue;

    return trips.fold<double>(
      0,
      (sum, trip) => sum + _toDouble(trip.totalBill),
    );
  }

  double get totalAmountReceived {
    final companyValue = _toDouble(company?.totalAmountReceived);
    if (companyValue > 0) return companyValue;

    return transactions.fold<double>(
      0,
      (sum, transaction) => transaction.transactionType == 'payment'
          ? sum + _toDouble(transaction.amount)
          : sum,
    );
  }

  double get totalAmountCompanyAddedExpenses {
    return transactions.fold<double>(
      0,
      (sum, transaction) => _isCompanyAddedToDueExpense(transaction)
          ? sum + _toDouble(transaction.amount)
          : sum,
    );
  }

  double get totalAmountMainBalanceExpenses {
    return transactions.fold<double>(
      0,
      (sum, transaction) => _isMainBalanceExpense(transaction)
          ? sum + _toDouble(transaction.amount)
          : sum,
    );
  }

  // Backward-compatible aggregate (used by older UI paths if any).
  double get totalAmountExpenses {
    return totalAmountCompanyAddedExpenses + totalAmountMainBalanceExpenses;
  }

  double get totalAmountDue {
    final companyValue = _toDouble(company?.totalAmountDue);
    if (companyValue != 0) return companyValue;

    return totalAmountBilled -
        totalAmountReceived +
        totalAmountCompanyAddedExpenses;
  }

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is CompanyModel) {
      company = args;
    } else if (args is Map<String, dynamic>) {
      company = CompanyModel.fromMap(args);
    }

    _populateFields();
  }

  @override
  void onReady() {
    super.onReady();
    loadCompanyDetails();
  }

  Future<void> loadCompanyDetails() async {
    if (company == null) {
      return;
    }

    _isLoading.value = true;
    try {
      final companyName = company!.name;

      final allCompanies = await _companyService.getCompanies();
      final updatedCompany = allCompanies.firstWhereOrNull(
        (item) => _normalize(item.name) == _normalize(companyName),
      );
      if (updatedCompany != null) {
        company = updatedCompany;
        _populateFields();
      }

      final allTrips = await _tripService.getTrips();
      trips.assignAll(
        allTrips.where(
          (trip) =>
              _normalize(trip.companyAndShipInfo.companyName) ==
              _normalize(companyName),
        ),
      );

      final allTransactions = await _transactionService.getTransactions();
      transactions.assignAll(
        allTransactions.where(
          (transaction) =>
              _normalize(transaction.companyAndShipInfo.companyName ?? 'N/A') ==
              _normalize(companyName),
        ),
      );
    } catch (error) {
      Get.snackbar('Error', 'Failed to load company details: $error');
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> onGenerateStatementPressed() async {
    final filteredTrips = _filteredTrips();
    final filteredTransactions = _filteredTransactions();

    if (filteredTrips.isEmpty && filteredTransactions.isEmpty) {
      Get.snackbar(
        'No data in selected period',
        'No statement records found for the selected filter.',
        colorText: Colors.white,
        backgroundColor: const Color.fromARGB(172, 239, 83, 80),
      );
      return;
    }

    await CompanyStatementUtil.generateAndSavePdf(
      company: company!,
      trips: filteredTrips,
      transactions: filteredTransactions,
    );
    // Old utils:
    // await legacy_statement.CompanyStatementUtil.generateAndSavePdf(
    //   company: company!,
    //   trips: trips.toList(),
    //   transactions: transactions.toList(),
    // );
  }

  // Future<void> onShowPreviewPressed() async {
  //   Get.to(
  //     () => CompanyStatementPreviewPage(
  //       company: company!,
  //       trips: trips.toList(),
  //       transactions: transactions.toList(),
  //     ),
  //   );
  //   // Old utils:
  //   // Get.to(
  //   //   () => legacy_statement.CompanyStatementPreviewPage(
  //   //     company: company!,
  //   //     trips: trips.toList(),
  //   //     transactions: transactions.toList(),
  //   //   ),
  //   // );
  // }

  Future<void> onRefresh() => loadCompanyDetails();

  void setStatementSelectedMonth(DateTime month) {
    statementFilterType.value = StatementTimeFilterType.selectedMonth;
    statementSelectedMonth.value = DateTime(month.year, month.month, 1);
    statementRangeStart.value = null;
    statementRangeEnd.value = null;
  }

  void setStatementDateRange(DateTimeRange range) {
    statementFilterType.value = StatementTimeFilterType.dateRange;
    statementRangeStart.value = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    statementRangeEnd.value = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
    );
    statementSelectedMonth.value = null;
  }

  void clearStatementFilter() {
    statementFilterType.value = StatementTimeFilterType.all;
    statementSelectedMonth.value = null;
    statementRangeStart.value = null;
    statementRangeEnd.value = null;
  }

  String get statementFilterLabel {
    if (statementFilterType.value == StatementTimeFilterType.selectedMonth) {
      final month = statementSelectedMonth.value;
      if (month == null) return 'Month filter: not set';
      final fmt = DateFormat('MMM yyyy');
      return 'Month: ${fmt.format(month)}';
    }

    if (statementFilterType.value == StatementTimeFilterType.dateRange) {
      final start = statementRangeStart.value;
      final end = statementRangeEnd.value;
      if (start == null || end == null) return 'Date range: not set';
      final fmt = DateFormat('dd MMM yyyy');
      return 'Range: ${fmt.format(start)} to ${fmt.format(end)}';
    }

    return 'All time';
  }

  void startEditing() {
    if (company == null) return;
    _populateFields();
    isEditing.value = true;
  }

  void cancelEditing() {
    _populateFields();
    isEditing.value = false;
  }

  Future<void> saveChanges() async {
    final currentCompany = company;
    if (currentCompany == null || isSaving.value) return;

    isSaving.value = true;
    try {
      final updatedDescription = descriptionController.text.trim();

      await _companyService.updateCompanyDetails(
        companyName: currentCompany.name,
        description: updatedDescription,
      );

      currentCompany.description = updatedDescription;
      isEditing.value = false;
      Get.snackbar('Success', 'Company details updated successfully.');
    } catch (error) {
      Get.snackbar('Error', 'Failed to update company details: $error');
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> deleteCompanyWithPassword(String password) async {
    final currentCompany = company;
    if (currentCompany == null || isDeleting.value) return false;

    final trimmedPassword = password.trim();
    if (trimmedPassword.isEmpty) {
      Get.snackbar('Error', 'Password is required');
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
        () => _companyService.deleteCompany(companyName: currentCompany.name),
        fallbackMessage: 'Failed to delete company',
      );

      if (!deleteResponse.isSuccess) return false;
      return true;
    } finally {
      isDeleting.value = false;
    }
  }

  Future<void> extractCompanyData() async {}

  void openTripDetails(TripModel trip) {
    Get.toNamed(AppRoutes.tripDetails, arguments: trip);
  }

  void openTransactionDetails(TransactionModel transaction) {
    Get.toNamed(AppRoutes.transactionDetails, arguments: transaction);
  }

  void _populateFields() {
    final currentCompany = company;
    if (currentCompany == null) return;
    descriptionController.text = currentCompany.description?.trim() ?? '';
  }

  @override
  void onClose() {
    descriptionController.dispose();
    super.onClose();
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    final sanitized = value.toString().replaceAll(',', '').trim();
    if (sanitized.isEmpty) return 0;
    return double.tryParse(sanitized) ?? 0;
  }

  String _normalize(String value) {
    return value.trim().toLowerCase();
  }

  bool _isExpense(TransactionModel transaction) {
    return transaction.transactionType.trim().toLowerCase() == 'expenses';
  }

  bool _isMainBalanceExpense(TransactionModel transaction) {
    if (!_isExpense(transaction)) return false;
    final normalizedSource = transaction.expenseSource
        .trim()
        .toLowerCase()
        .replaceAll('_', '-')
        .replaceAll(' ', '-');
    return normalizedSource == 'main-balance';
  }

  bool _isCompanyAddedToDueExpense(TransactionModel transaction) {
    return _isExpense(transaction) && !_isMainBalanceExpense(transaction);
  }

  List<TripModel> _filteredTrips() {
    return trips
        .where((trip) => _isWithinSelectedWindow(_parseDate(trip.date)))
        .toList();
  }

  List<TransactionModel> _filteredTransactions() {
    return transactions
        .where((tx) => _isWithinSelectedWindow(_parseDate(tx.date)))
        .toList();
  }

  bool _isWithinSelectedWindow(DateTime? date) {
    if (statementFilterType.value == StatementTimeFilterType.all) {
      return true;
    }

    if (date == null) {
      return false;
    }

    if (statementFilterType.value == StatementTimeFilterType.selectedMonth) {
      final selectedMonth = statementSelectedMonth.value;
      if (selectedMonth == null) return true;

      return date.year == selectedMonth.year &&
          date.month == selectedMonth.month;
    }

    final start = statementRangeStart.value;
    final end = statementRangeEnd.value;
    if (start == null || end == null) return true;

    return !date.isBefore(start) && !date.isAfter(end);
  }

  DateTime? _parseDate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final direct = DateTime.tryParse(trimmed);
    if (direct != null) {
      return DateTime(direct.year, direct.month, direct.day);
    }

    const patterns = [
      'dd MMM yyyy',
      'dd-MM-yyyy',
      'dd/MM/yyyy',
      'yyyy-MM-dd',
      'yyyy/MM/dd',
      'MM/dd/yyyy',
    ];

    for (final pattern in patterns) {
      try {
        final parsed = DateFormat(pattern).parseStrict(trimmed);
        return DateTime(parsed.year, parsed.month, parsed.day);
      } catch (_) {}
    }

    return null;
  }
}
