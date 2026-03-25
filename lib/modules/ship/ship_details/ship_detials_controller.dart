import 'package:flutter/material.dart';
import 'package:urgent/core/widgets/app_snackbar.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/services/api_error_handler.dart';
import '../../../core/services/firebase_auth_service.dart';
import '../../../core/services/firestore_services/shipdata_service.dart';
import '../../../core/services/firestore_services/transactiondata_service.dart';
import '../../../core/services/firestore_services/tripdata_service.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routes/app_routes.dart';
import '../../Transactions/models/transaction_model.dart';
import '../../home/home_controller.dart';
import '../../trip/models/trip_model.dart';
import '../models/ship_model.dart';
import '../utils/utils.dart';

enum ShipStatementTimeFilterType { all, selectedMonth, dateRange }

class ShipDetailsController extends GetxController {
  static const int _pageSize = 10;

  final FirestoreTripService _tripService = Get.find<FirestoreTripService>();
  final FirestoreShipService _shipService = Get.find<FirestoreShipService>();
  final FirestoreTransactionService _transactionService =
      Get.find<FirestoreTransactionService>();
  final AuthService _authService = Get.find<AuthService>();

  ShipModel? ship;

  final licenseController = TextEditingController();

  final RxBool _isLoading = false.obs;
  bool get isLoading => _isLoading.value;

  final RxBool isEditing = false.obs;
  final RxBool isSaving = false.obs;
  final RxBool isDeleting = false.obs;

  final Rx<ShipStatementTimeFilterType> statementFilterType =
      ShipStatementTimeFilterType.all.obs;
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
    return trips.fold<double>(
      0,
      (sum, trip) => sum + _toDouble(trip.totalBill),
    );
  }

  double get totalAmountReceived {
    return transactions.fold<double>(
      0,
      (sum, transaction) => transaction.transactionType == 'payment'
          ? sum + _toDouble(transaction.amount)
          : sum,
    );
  }

  double get totalAmountShipAddedExpenses {
    return transactions.fold<double>(
      0,
      (sum, transaction) => _isShipAddedToDueExpense(transaction)
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

  double get totalAmountExpenses {
    return totalAmountShipAddedExpenses + totalAmountMainBalanceExpenses;
  }

  double get totalAmountDue {
    return (totalAmountBilled - totalAmountReceived) -
        totalAmountShipAddedExpenses;
  }

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;

    if (args is ShipModel) {
      ship = args;
    } else if (args is Map<String, dynamic>) {
      ship = ShipModel.fromMap(args);
    }

    _populateFields();

    tripsScrollController.addListener(_onTripsScroll);
    transactionsScrollController.addListener(_onTransactionsScroll);
  }

  @override
  void onReady() {
    super.onReady();
    loadShipDetails();
  }

  Future<void> loadShipDetails() async {
    if (ship == null) {
      return;
    }

    _isLoading.value = true;
    try {
      final shipName = ship!.name;

      final shipsResponse = await ApiErrorHandler.call(
        () => _shipService.getShips(),
        fallbackMessage: 'Failed to load ships',
      );
      if (!shipsResponse.isSuccess || shipsResponse.data == null) {
        return;
      }

      final updatedShip = shipsResponse.data!.firstWhereOrNull(
        (item) => _normalize(item.name) == _normalize(shipName),
      );
      if (updatedShip != null) {
        ship = updatedShip;
        _populateFields();
      }

      final response = await ApiErrorHandler.call(
        () => _tripService.getTrips(),
        fallbackMessage: 'Failed to load ship trips',
      );
      if (!response.isSuccess || response.data == null) return;

      final allTrips = response.data!;
      trips.assignAll(
        allTrips.where(
          (trip) =>
              _normalize(trip.companyAndShipInfo.shipName) ==
              _normalize(shipName),
        ),
      );
      _resetTripsPagination();

      final transactionsResponse = await ApiErrorHandler.call(
        () => _transactionService.getTransactions(),
        fallbackMessage: 'Failed to load ship transactions',
      );
      if (!transactionsResponse.isSuccess ||
          transactionsResponse.data == null) {
        return;
      }

      transactions.assignAll(
        transactionsResponse.data!.where(
          (transaction) =>
              _normalize(transaction.companyAndShipInfo.shipName ?? '') ==
              _normalize(shipName),
        ),
      );
      _resetTransactionsPagination();
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> onRefresh() => loadShipDetails();

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
    final currentShip = ship;
    if (currentShip == null) return;

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

    await ShipStatementUtil.generateAndSavePdf(
      ship: currentShip,
      trips: filteredTrips,
      transactions: filteredTransactions,
    );
  }

  void setStatementSelectedMonth(DateTime month) {
    statementFilterType.value = ShipStatementTimeFilterType.selectedMonth;
    statementSelectedMonth.value = DateTime(month.year, month.month, 1);
    statementRangeStart.value = null;
    statementRangeEnd.value = null;
  }

  void setStatementDateRange(DateTimeRange range) {
    statementFilterType.value = ShipStatementTimeFilterType.dateRange;
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
    statementFilterType.value = ShipStatementTimeFilterType.all;
    statementSelectedMonth.value = null;
    statementRangeStart.value = null;
    statementRangeEnd.value = null;
  }

  String get statementFilterLabel {
    if (statementFilterType.value ==
        ShipStatementTimeFilterType.selectedMonth) {
      final month = statementSelectedMonth.value;
      if (month == null) return 'Month filter: not set';
      final fmt = DateFormat('MMM yyyy');
      return 'Month: ${fmt.format(month)}';
    }

    if (statementFilterType.value == ShipStatementTimeFilterType.dateRange) {
      final start = statementRangeStart.value;
      final end = statementRangeEnd.value;
      if (start == null || end == null) return 'Date range: not set';
      final fmt = DateFormat('dd MMM yyyy');
      return 'Range: ${fmt.format(start)} to ${fmt.format(end)}';
    }

    return 'All time';
  }

  void startEditing() {
    if (ship == null) return;
    _populateFields();
    isEditing.value = true;
  }

  void cancelEditing() {
    _populateFields();
    isEditing.value = false;
  }

  Future<void> saveChanges() async {
    final currentShip = ship;
    if (currentShip == null || isSaving.value) return;

    isSaving.value = true;
    try {
      final updatedLicense = licenseController.text.trim();

      final response = await ApiErrorHandler.call(
        () => _shipService.updateShipDetails(
          shipName: currentShip.name,
          licenseNumber: updatedLicense,
        ),
        fallbackMessage: 'Failed to update ship details',
      );
      if (!response.isSuccess) return;

      currentShip.licenseNumber = updatedLicense;
      isEditing.value = false;
      showAppSnackbar('Success', 'Ship details updated successfully.');
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> deleteShipWithPassword(String password) async {
    final currentShip = ship;
    if (currentShip == null || isDeleting.value) return false;

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
        () => _shipService.deleteShip(shipName: currentShip.name),
        fallbackMessage: 'Failed to delete ship',
      );

      if (!deleteResponse.isSuccess) return false;
      return true;
    } finally {
      isDeleting.value = false;
    }
  }

  Future<void> onDeleteShipPressed(BuildContext context) async {
    final deleted = await showPasswordConfirmDeletionDialog(
      context: context,
      title: 'Delete Ship',
      message: 'Enter your password to confirm deletion.',
      onConfirm: deleteShipWithPassword,
    );

    if (!deleted) return;
    Get.back(result: true);
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

      await loadShipDetails();
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

      await loadShipDetails();
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
    await loadShipDetails();
  }

  Future<void> openTripDetails(TripModel trip) async {
    final result = await Get.toNamed(AppRoutes.tripDetails, arguments: trip);
    if (result == true) {
      await loadShipDetails();
    }
  }

  Future<void> openTransactionDetails(TransactionModel transaction) async {
    final result = await Get.toNamed(
      AppRoutes.transactionDetails,
      arguments: transaction,
    );

    if (result == true) {
      await loadShipDetails();
    }
  }

  void _populateFields() {
    final currentShip = ship;
    if (currentShip == null) return;
    licenseController.text = currentShip.licenseNumber?.trim() ?? '';
  }

  @override
  void onClose() {
    tripsScrollController
      ..removeListener(_onTripsScroll)
      ..dispose();
    transactionsScrollController
      ..removeListener(_onTransactionsScroll)
      ..dispose();
    licenseController.dispose();
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

  bool _isShipAddedToDueExpense(TransactionModel transaction) {
    return _isExpense(transaction) && !_isMainBalanceExpense(transaction);
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    final sanitized = value.toString().replaceAll(',', '').trim();
    if (sanitized.isEmpty) return 0;
    return double.tryParse(sanitized) ?? 0;
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
    if (statementFilterType.value == ShipStatementTimeFilterType.all) {
      return true;
    }

    if (date == null) {
      return false;
    }

    if (statementFilterType.value ==
        ShipStatementTimeFilterType.selectedMonth) {
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
