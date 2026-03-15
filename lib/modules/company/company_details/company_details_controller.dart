import 'package:flutter/material.dart';
import 'package:urgent/core/widgets/app_snackbar.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/services/api_error_handler.dart';
import '../../../core/services/firebase_auth_service.dart';
import '../../../core/services/firestore_services/companydata_service.dart';
import '../../../core/services/firestore_services/transactiondata_service.dart';
import '../../../core/services/firestore_services/tripdata_service.dart';
import '../../../core/widgets/widgets.dart';
import '../../../modules/home/home_controller.dart';
import '../../../routes/app_routes.dart';
import '../../Transactions/models/transaction_model.dart';
import '../../trip/models/trip_model.dart';
import '../models/company_model.dart';
import '../utils/utils.dart';
// import '../utils/utils_legacy.dart' as legacy_statement;

enum StatementTimeFilterType { all, selectedMonth, dateRange }

class CompanyDetailsController extends GetxController {
  static const int _pageSize = 10;

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

  final ScrollController tripsScrollController = ScrollController();
  final ScrollController transactionsScrollController = ScrollController();

  final RxBool _isLoadingMoreTrips = false.obs;
  bool get isLoadingMoreTrips => _isLoadingMoreTrips.value;
  final RxBool _isLoadingMoreTransactions = false.obs;
  bool get isLoadingMoreTransactions => _isLoadingMoreTransactions.value;

  final RxInt _visibleTripsCount = 0.obs;
  final RxInt _visibleTransactionsCount = 0.obs;

  bool get hasMoreTrips => _visibleTripsCount.value < trips.length;
  bool get hasMoreTransactions =>
      _visibleTransactionsCount.value < transactions.length;

  List<TripModel> get visibleTrips {
    final end = _visibleTripsCount.value.clamp(0, trips.length);
    return trips.take(end).toList();
  }

  List<TransactionModel> get visibleTransactions {
    final end = _visibleTransactionsCount.value.clamp(0, transactions.length);
    return transactions.take(end).toList();
  }

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
    // final companyValue = _toDouble(company?.totalAmountDue);
    // if (companyValue != 0) return companyValue;

    return (totalAmountBilled - totalAmountReceived) -
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

    tripsScrollController.addListener(_onTripsScroll);
    transactionsScrollController.addListener(_onTransactionsScroll);
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

      final companiesResponse = await ApiErrorHandler.call(
        () => _companyService.getCompanies(),
        fallbackMessage: 'Failed to load companies',
      );
      if (!companiesResponse.isSuccess || companiesResponse.data == null) {
        return;
      }
      final allCompanies = companiesResponse.data!;
      final updatedCompany = allCompanies.firstWhereOrNull(
        (item) => _normalize(item.name) == _normalize(companyName),
      );
      if (updatedCompany != null) {
        company = updatedCompany;
        _populateFields();
      }

      final tripsResponse = await ApiErrorHandler.call(
        () => _tripService.getTrips(),
        fallbackMessage: 'Failed to load company trips',
      );
      if (!tripsResponse.isSuccess || tripsResponse.data == null) {
        return;
      }
      final allTrips = tripsResponse.data!;
      trips.assignAll(
        allTrips.where(
          (trip) =>
              _normalize(trip.companyAndShipInfo.companyName) ==
              _normalize(companyName),
        ),
      );
      _resetTripsPagination();

      final transactionsResponse = await ApiErrorHandler.call(
        () => _transactionService.getTransactions(),
        fallbackMessage: 'Failed to load company transactions',
      );
      if (!transactionsResponse.isSuccess ||
          transactionsResponse.data == null) {
        return;
      }
      final allTransactions = transactionsResponse.data!;
      transactions.assignAll(
        allTransactions.where(
          (transaction) =>
              _normalize(transaction.companyAndShipInfo.companyName ?? 'N/A') ==
              _normalize(companyName),
        ),
      );
      _resetTransactionsPagination();
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> loadMoreTrips() async {
    if (_isLoadingMoreTrips.value || !hasMoreTrips) return;

    _isLoadingMoreTrips.value = true;
    try {
      _visibleTripsCount.value = (_visibleTripsCount.value + _pageSize).clamp(
        0,
        trips.length,
      );
    } finally {
      _isLoadingMoreTrips.value = false;
    }
  }

  Future<void> loadMoreTransactions() async {
    if (_isLoadingMoreTransactions.value || !hasMoreTransactions) return;

    _isLoadingMoreTransactions.value = true;
    try {
      _visibleTransactionsCount.value =
          (_visibleTransactionsCount.value + _pageSize).clamp(
            0,
            transactions.length,
          );
    } finally {
      _isLoadingMoreTransactions.value = false;
    }
  }

  Future<void> onGenerateStatementPressed() async {
    final filteredTrips = _filteredTrips();
    final filteredTransactions = _filteredTransactions();

    if (filteredTrips.isEmpty && filteredTransactions.isEmpty) {
      showAppSnackbar(
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

      final response = await ApiErrorHandler.call(
        () => _companyService.updateCompanyDetails(
          companyName: currentCompany.name,
          description: updatedDescription,
        ),
        fallbackMessage: 'Failed to update company details',
      );
      if (!response.isSuccess) return;

      currentCompany.description = updatedDescription;
      isEditing.value = false;
      showAppSnackbar('Success', 'Company details updated successfully.');
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> deleteCompanyWithPassword(String password) async {
    final currentCompany = company;
    if (currentCompany == null || isDeleting.value) return false;

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

  Future<void> onDeleteCompanyPressed(BuildContext context) async {
    final deleted = await showPasswordConfirmDeletionDialog(
      context: context,
      title: 'Delete Company',
      message: 'Enter your password to confirm deletion.',
      onConfirm: deleteCompanyWithPassword,
    );

    if (!deleted) return;
    Get.back(result: true);
  }

  Future<bool> deleteTransactionWithPassword({
    required TransactionModel transaction,
    required String password,
  }) async {
    if (isDeleting.value) return false;

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
          transactionId: transaction.transactionId,
        ),
        fallbackMessage: 'Failed to delete transaction',
      );

      if (!deleteResponse.isSuccess) return false;

      await loadCompanyDetails();
      if (Get.isRegistered<HomeController>()) {
        await Get.find<HomeController>().loadHomeData();
      }
      return true;
    } finally {
      isDeleting.value = false;
    }
  }

  Future<void> onDeleteTransactionPressed(
    BuildContext context,
    TransactionModel transaction,
  ) async {
    final deleted = await showPasswordConfirmDeletionDialog(
      context: context,
      title: 'Delete Transaction',
      message:
          'Enter your password to delete this transaction of ৳ ${_formatAmount(_toDouble(transaction.amount))}.',
      onConfirm: (password) => deleteTransactionWithPassword(
        transaction: transaction,
        password: password,
      ),
    );

    if (!deleted) return;

    showAppSnackbar('Success', 'Transaction deleted successfully.');
    await loadCompanyDetails();
  }

  Future<bool> deleteTripWithPassword({
    required TripModel trip,
    required String password,
  }) async {
    if (isDeleting.value) return false;

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
        () => _tripService.deleteTrip(trip: trip),
        fallbackMessage: 'Failed to delete trip',
      );
      if (!deleteResponse.isSuccess) return false;

      await loadCompanyDetails();
      if (Get.isRegistered<HomeController>()) {
        await Get.find<HomeController>().loadHomeData();
      }
      return true;
    } finally {
      isDeleting.value = false;
    }
  }

  Future<void> onDeleteTripPressed(BuildContext context, TripModel trip) async {
    final deleted = await showPasswordConfirmDeletionDialog(
      context: context,
      title: 'Delete Trip',
      message:
          'Enter your password to delete this trip bill of ৳ ${_formatAmount(_toDouble(trip.totalBill))}.',
      onConfirm: (password) =>
          deleteTripWithPassword(trip: trip, password: password),
    );

    if (!deleted) return;
    showAppSnackbar('Success', 'Trip deleted successfully.');
  }

  Future<void> openTripDetails(TripModel trip) async {
    final result = await Get.toNamed(AppRoutes.tripDetails, arguments: trip);
    if (result == true) {
      await loadCompanyDetails();
    }
  }

  Future<void> openTransactionDetails(TransactionModel transaction) async {
    final result = await Get.toNamed(
      AppRoutes.transactionDetails,
      arguments: transaction,
    );

    if (result == true) {
      await loadCompanyDetails();
    }
  }

  void _populateFields() {
    final currentCompany = company;
    if (currentCompany == null) return;
    descriptionController.text = currentCompany.description?.trim() ?? '';
  }

  @override
  void onClose() {
    tripsScrollController
      ..removeListener(_onTripsScroll)
      ..dispose();
    transactionsScrollController
      ..removeListener(_onTransactionsScroll)
      ..dispose();
    descriptionController.dispose();
    super.onClose();
  }

  void _resetTripsPagination() {
    _visibleTripsCount.value = trips.length < _pageSize
        ? trips.length
        : _pageSize;
    _isLoadingMoreTrips.value = false;
  }

  void _resetTransactionsPagination() {
    _visibleTransactionsCount.value = transactions.length < _pageSize
        ? transactions.length
        : _pageSize;
    _isLoadingMoreTransactions.value = false;
  }

  void _onTripsScroll() {
    if (!tripsScrollController.hasClients ||
        _isLoadingMoreTrips.value ||
        !hasMoreTrips) {
      return;
    }

    final position = tripsScrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      loadMoreTrips();
    }
  }

  void _onTransactionsScroll() {
    if (!transactionsScrollController.hasClients ||
        _isLoadingMoreTransactions.value ||
        !hasMoreTransactions) {
      return;
    }

    final position = transactionsScrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      loadMoreTransactions();
    }
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

  String _formatAmount(double value) {
    return value.toInt().toString();
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
