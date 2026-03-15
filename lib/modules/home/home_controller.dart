import 'package:get/get.dart';
import 'package:urgent/core/widgets/app_snackbar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../../core/bootstrap/bootstrap_controller.dart';
import '../../core/services/api_error_handler.dart';
import '../../core/services/firebase_auth_service.dart';
import '../../core/services/firestore_services/admin_access_service.dart';
import '../../core/services/firestore_services/cash_in_cash_out_service.dart';
import '../../core/services/firestore_services/companydata_service.dart';
import '../../core/services/firestore_services/shipdata_service.dart';
import '../../core/services/firestore_services/transactiondata_service.dart';
import '../../core/services/firestore_services/tripdata_service.dart';
import '../../core/services/firestore_services/userdata_service.dart';
import '../../core/widgets/widgets.dart';
import '../../routes/app_routes.dart';
import '../cashin_cashout/models/cash_in_cash_out_model.dart';
import '../company/models/company_model.dart';
import '../trip/models/trip_model.dart';
import '../Transactions/models/transaction_model.dart';
import 'model/home_model.dart';
import 'model/user_profile_model.dart';

class HomeController extends GetxController {
  final RxBool isLoading = false.obs;
  final RxBool isAdmin = false.obs;
  final Rxn<HomeModel> homeModel = Rxn<HomeModel>();
  final AuthService _auth = Get.find<AuthService>();
  final AdminAccessService _adminAccessService = Get.find<AdminAccessService>();
  final FirestoreUserService _firestore = Get.find<FirestoreUserService>();
  final FirestoreShipService _shipService = Get.find<FirestoreShipService>();
  final FirestoreCompanyService _companyService =
      Get.find<FirestoreCompanyService>();
  final FirestoreTripService _tripService = Get.find<FirestoreTripService>();
  final FirestoreTransactionService _transactionService =
      Get.find<FirestoreTransactionService>();
  final FirestoreCashInCashOutService _cashInCashOutService =
      Get.find<FirestoreCashInCashOutService>();

  String? _loadedUserId;

  // Dashboard and financial values are now owned by HomeModel.
  int get shipCount => homeModel.value?.shipCount ?? 0;
  int get companyCount => homeModel.value?.companyCount ?? 0;
  int get tripCount => homeModel.value?.tripCount ?? 0;
  int get transactionCount => homeModel.value?.transactionCount ?? 0;
  int get totalFundOwed => homeModel.value?.totalFundOwed ?? 0;
  int get totalFundReceived => homeModel.value?.totalFundReceived ?? 0;
  int get totalDue => homeModel.value?.totalDue ?? 0;
  int get monthlyFundOwed => homeModel.value?.monthlyFundOwed ?? 0;
  int get monthlyFundReceived => homeModel.value?.monthlyFundReceived ?? 0;
  int get monthlyTotalDue => homeModel.value?.monthlyTotalDue ?? 0;
  List<TripModel> get recentTrips => homeModel.value?.recentTrips ?? const [];
  List<TransactionModel> get recentTransactions =>
      homeModel.value?.recentTransactions ?? const [];

  // ── Recent Items ─────────────────────────────────────────────────────
  final RxList<TransactionModel> _allTransactions = <TransactionModel>[].obs;
  final RxList<TripModel> _allTrips = <TripModel>[].obs;
  final RxList<CashInCashOutModel> _allCashFlowEntries =
      <CashInCashOutModel>[].obs;
  List<CompanyModel> _companies = [];

  List<TransactionModel> get allTransactions => _allTransactions;
  List<TripModel> get allTrips => _allTrips;
  List<CompanyModel> get companies => _companies;

  @override
  void onInit() {
    super.onInit();
    loadHomeData();
  }

  Future<void> loadHomeData() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      Get.offAllNamed(AppRoutes.login);
      return;
    }

    isLoading.value = true;
    try {
      final adminResponse = await ApiErrorHandler.call(
        () => _adminAccessService.refreshCurrentUserRole(),
        fallbackMessage: 'Failed to verify admin role',
      );
      if (adminResponse.isSuccess && adminResponse.data != null) {
        isAdmin.value = adminResponse.data!;
      }

      // ── Load user profile ──────────────────────────────────────────
      if (homeModel.value == null || _loadedUserId != currentUser.uid) {
        final response = await ApiErrorHandler.call(
          () => _firestore.getUserDetails(),
          fallbackMessage: 'Failed to load user details',
          showErrorSnackbar: true,
        );
        UserProfileModel profile = response.data ?? const UserProfileModel();
        final currentEmail = (currentUser.email ?? '').trim();
        if (currentEmail.isNotEmpty) {
          profile = profile.copyWith(email: currentEmail);
        }

        homeModel.value = HomeModel(profile: profile);
        _loadedUserId = currentUser.uid;
      }

      // ── Load dashboard stats in parallel ───────────────────────────
      await Future.wait([
        _loadShipCount(),
        _loadCompanyCount(),
        _loadTripData(),
        _loadTransactionData(),
        _loadCashInCashOutData(),
      ]);
      await _loadBalanceData();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadShipCount() async {
    final response = await ApiErrorHandler.call(
      () => _shipService.getShips(),
      fallbackMessage: 'Failed to load ships',
      showErrorSnackbar: false,
    );
    if (response.isSuccess && response.data != null) {
      _updateHomeModel(shipCount: response.data!.length);
    }
  }

  Future<void> _loadCompanyCount() async {
    final response = await ApiErrorHandler.call(
      () => _companyService.getCompanies(),
      fallbackMessage: 'Failed to load companies',
      showErrorSnackbar: false,
    );
    if (response.isSuccess && response.data != null) {
      _companies = response.data!;
      _updateHomeModel(companyCount: _companies.length);
    }
  }

  Future<void> _loadTripData() async {
    final response = await ApiErrorHandler.call(
      () => _tripService.getTripsSortedByDateDesc(),
      fallbackMessage: 'Failed to load trips',
      showErrorSnackbar: false,
    );
    if (response.isSuccess && response.data != null) {
      final trips = response.data!;
      _updateHomeModel(tripCount: trips.length);
      _allTrips.assignAll(trips);
      _updateHomeModel(recentTrips: trips.take(5).toList());
    }
  }

  Future<void> _loadTransactionData() async {
    final response = await ApiErrorHandler.call(
      () => _transactionService.getTransactions(),
      fallbackMessage: 'Failed to load transactions',
      showErrorSnackbar: false,
    );
    if (response.isSuccess && response.data != null) {
      final transactions = response.data!;
      _updateHomeModel(transactionCount: transactions.length);
      _allTransactions.assignAll(transactions);
      _updateHomeModel(recentTransactions: transactions.take(5).toList());
    }
  }

  Future<void> _loadCashInCashOutData() async {
    final response = await ApiErrorHandler.call(
      () => _cashInCashOutService.getEntriesSortedByDateDesc(),
      fallbackMessage: 'Failed to load cash in/cash out data',
      showErrorSnackbar: false,
    );

    if (response.isSuccess && response.data != null) {
      _allCashFlowEntries.assignAll(response.data!);
    }
  }

  Future<void> _loadBalanceData() async {
    // ── Lifetime totals from trips/transactions (single calc pipeline) ──
    final totalFundOwedValue = _allTrips.fold(
      0,
      (sum, trip) => sum + _toInt(trip.totalBill),
    );
    final totalPayments = _sumByCategory(_allTransactions, 'payment');
    final totalCompanyExpenses = _sumByCategory(
      _allTransactions,
      'expenses',
      source: 'company',
    );
    final totalDueValue =
        totalFundOwedValue - totalPayments - totalCompanyExpenses;

    // ── Lifetime balance (cash-in-hand): payments − main-balance expenses
    final totalFundReceivedFromTransactions = _sumTransactions(
      _allTransactions,
      payments: true,
      mainBalanceExpenses: true,
    );
    final totalFundReceivedValue =
        totalFundReceivedFromTransactions +
        _sumCashInCashOut(_allCashFlowEntries);

    // ── Monthly totals ─────────────────────────────────────────────────
    final now = DateTime.now();

    // Monthly billed = sum of trip bills this month
    final monthlyFundOwedValue = _allTrips
        .where((t) => _isCurrentMonth(t.date, now))
        .fold(0, (sum, t) => sum + _toInt(t.totalBill));

    // Filter transactions to current month
    final monthlyTx = _allTransactions
        .where((t) => _isCurrentMonth(t.date, now))
        .toList();

    // Monthly balance (cash-in-hand): payments − main-balance expenses
    final monthlyFundReceivedFromTransactions = _sumTransactions(
      monthlyTx,
      payments: true,
      mainBalanceExpenses: true,
    );
    final monthlyCashFlowEntries = _allCashFlowEntries
        .where((entry) => _isCurrentMonth(entry.date, now))
        .toList();
    final monthlyFundReceivedValue =
        monthlyFundReceivedFromTransactions +
        _sumCashInCashOut(monthlyCashFlowEntries);

    // Monthly due = billed − payments − company expenses
    final monthlyPayments = _sumByCategory(monthlyTx, 'payment');
    final monthlyCompanyExpenses = _sumByCategory(
      monthlyTx,
      'expenses',
      source: 'company',
    );
    final monthlyTotalDueValue =
        monthlyFundOwedValue - monthlyPayments - monthlyCompanyExpenses;

    _updateHomeModel(
      totalFundOwed: totalFundOwedValue,
      totalFundReceived: totalFundReceivedValue,
      totalDue: totalDueValue < 0 ? 0 : totalDueValue,
      monthlyFundOwed: monthlyFundOwedValue,
      monthlyFundReceived: monthlyFundReceivedValue,
      monthlyTotalDue: monthlyTotalDueValue < 0 ? 0 : monthlyTotalDueValue,
    );
  }

  void _updateHomeModel({
    int? shipCount,
    int? companyCount,
    int? tripCount,
    int? transactionCount,
    int? totalFundOwed,
    int? totalFundReceived,
    int? totalDue,
    int? monthlyFundOwed,
    int? monthlyFundReceived,
    int? monthlyTotalDue,
    List<TripModel>? recentTrips,
    List<TransactionModel>? recentTransactions,
  }) {
    final current = homeModel.value ?? HomeModel();
    homeModel.value = current.copyWith(
      shipCount: shipCount,
      companyCount: companyCount,
      tripCount: tripCount,
      transactionCount: transactionCount,
      totalFundOwed: totalFundOwed,
      totalFundReceived: totalFundReceived,
      totalDue: totalDue,
      monthlyFundOwed: monthlyFundOwed,
      monthlyFundReceived: monthlyFundReceived,
      monthlyTotalDue: monthlyTotalDue,
      recentTrips: recentTrips,
      recentTransactions: recentTransactions,
    );
  }

  // ── Reusable helpers ─────────────────────────────────────────────────

  /// Compute cash-in-hand from a list of transactions:
  /// + payment amounts, − main-balance expense amounts.
  int _sumTransactions(
    List<TransactionModel> txns, {
    required bool payments,
    required bool mainBalanceExpenses,
  }) {
    int total = 0;
    for (final t in txns) {
      final amount = _toInt(t.amount);
      if (amount <= 0) continue;
      final category = t.transactionType.trim().toLowerCase();
      final source = t.expenseSource.trim().toLowerCase();

      if (payments && category == 'payment') {
        total += amount;
      } else if (mainBalanceExpenses &&
          category == 'expenses' &&
          source == 'main-balance') {
        total -= amount;
      }
    }
    return total;
  }

  /// Sum amounts for a specific transaction category (and optional source).
  int _sumByCategory(
    List<TransactionModel> txns,
    String category, {
    String? source,
  }) {
    int total = 0;
    for (final t in txns) {
      final amount = _toInt(t.amount);
      if (amount <= 0) continue;
      if (t.transactionType.trim().toLowerCase() != category) continue;
      if (source != null && t.expenseSource.trim().toLowerCase() != source) {
        continue;
      }
      total += amount;
    }
    return total;
  }

  /// Compute main-balance adjustments from dedicated cash in/cash out entries.
  int _sumCashInCashOut(List<CashInCashOutModel> entries) {
    int total = 0;
    for (final entry in entries) {
      final amount = _toInt(entry.amount);
      if (amount <= 0) continue;
      total += entry.isCashOut ? -amount : amount;
    }
    return total;
  }

  bool _isCurrentMonth(String dateStr, DateTime now) {
    final date = _parseDate(dateStr);
    return date != null && date.year == now.year && date.month == now.month;
  }

  DateTime? _parseDate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    return DateTime.tryParse(trimmed);
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    if (value is String) {
      final sanitized = value.replaceAll(',', '').trim();
      if (sanitized.isEmpty) return 0;
      return int.tryParse(sanitized) ?? 0;
    }
    return 0;
  }

  Future<void> onRefresh() async {
    _loadedUserId = null;
    homeModel.value = null;
    await loadHomeData();
  }

  Future<void> onLogoutPressed() async {
    final response = await ApiErrorHandler.call(
      () => _auth.signOut(),
      fallbackMessage: 'Failed to sign out',
    );
    if (!response.isSuccess) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(BootstrapController.loginStatusKey);
    _adminAccessService.clear();
    isAdmin.value = false;
    homeModel.value = null;
    _loadedUserId = null;

    Get.offAllNamed(AppRoutes.login);
  }

  Future<bool> deleteTransactionWithPassword({
    required TransactionModel transaction,
    required String password,
  }) async {
    final trimmedPassword = password.trim();
    if (trimmedPassword.isEmpty) {
      showAppSnackbar('Error', 'Password is required');
      return false;
    }

    final reauthResponse = await ApiErrorHandler.call(
      () => _auth.reauthenticate(trimmedPassword),
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

    await loadHomeData();
    return true;
  }

  Future<void> onDeleteTransactionPressed(
    BuildContext context,
    TransactionModel transaction,
  ) async {
    final deleted = await showPasswordConfirmDeletionDialog(
      context: context,
      title: 'Delete Transaction',
      message:
          'Enter your password to delete this transaction of ৳ ${transaction.amount}.',
      onConfirm: (password) => deleteTransactionWithPassword(
        transaction: transaction,
        password: password,
      ),
    );

    if (!deleted) return;
    showAppSnackbar('Success', 'Transaction deleted successfully.');
  }

  Future<bool> deleteTripWithPassword({
    required TripModel trip,
    required String password,
  }) async {
    final trimmedPassword = password.trim();
    if (trimmedPassword.isEmpty) {
      showAppSnackbar('Error', 'Password is required');
      return false;
    }

    final reauthResponse = await ApiErrorHandler.call(
      () => _auth.reauthenticate(trimmedPassword),
      fallbackMessage: 'Failed to verify password',
    );
    if (!reauthResponse.isSuccess) return false;

    final deleteResponse = await ApiErrorHandler.call(
      () => _tripService.deleteTrip(trip: trip),
      fallbackMessage: 'Failed to delete trip',
    );
    if (!deleteResponse.isSuccess) return false;

    await loadHomeData();
    return true;
  }

  Future<void> onDeleteTripPressed(BuildContext context, TripModel trip) async {
    final deleted = await showPasswordConfirmDeletionDialog(
      context: context,
      title: 'Delete Trip',
      message:
          'Enter your password to delete this trip bill of ৳ ${trip.totalBill}.',
      onConfirm: (password) =>
          deleteTripWithPassword(trip: trip, password: password),
    );

    if (!deleted) return;
    showAppSnackbar('Success', 'Trip deleted successfully.');
  }
}
