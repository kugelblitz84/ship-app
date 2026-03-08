import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/bootstrap/bootstrap_controller.dart';
import '../../core/services/api_error_handler.dart';
import '../../core/services/firebase_auth_service.dart';
import '../../core/services/firestore_services/admin_access_service.dart';
import '../../core/services/firestore_services/companydata_service.dart';
import '../../core/services/firestore_services/shipdata_service.dart';
import '../../core/services/firestore_services/transactiondata_service.dart';
import '../../core/services/firestore_services/tripdata_service.dart';
import '../../core/services/firestore_services/user_access_service.dart';
import '../../core/services/firestore_services/userdata_service.dart';
import '../../routes/app_routes.dart';
import '../company/models/company_model.dart';
import '../trip/models/trip_model.dart';
import '../Transactions/models/transaction_model.dart';
import 'model/home_model.dart';

class HomeController extends GetxController {
  final RxBool isLoading = false.obs;
  final RxBool isAdmin = false.obs;
  final Rxn<HomeModel> homeModel = Rxn<HomeModel>();
  final AuthService _auth = Get.find<AuthService>();
  final AdminAccessService _adminAccessService = Get.find<AdminAccessService>();
  final UserAccessService _userAccessService = Get.find<UserAccessService>();
  final FirestoreUserService _firestore = Get.find<FirestoreUserService>();
  final FirestoreShipService _shipService = Get.find<FirestoreShipService>();
  final FirestoreCompanyService _companyService =
      Get.find<FirestoreCompanyService>();
  final FirestoreTripService _tripService = Get.find<FirestoreTripService>();
  final FirestoreTransactionService _transactionService =
      Get.find<FirestoreTransactionService>();

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
  final RxList<TransactionModel> allTransactions = <TransactionModel>[].obs;
  final RxList<TripModel> allTrips = <TripModel>[].obs;
  List<CompanyModel> companies = [];

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
      // final blocked = await _userAccessService.isCurrentUserBlocked();
      // if (blocked) {
      //   _adminAccessService.clear();
      //   isAdmin.value = false;
      //   Get.offAllNamed(AppRoutes.lockedAccount);
      //   return;
      // }

      isAdmin.value = await _adminAccessService.refreshCurrentUserRole();

      // ── Load user profile ──────────────────────────────────────────
      if (homeModel.value == null || _loadedUserId != currentUser.uid) {
        final userData = <String, dynamic>{};
        final response = await ApiErrorHandler.call(
          () => _firestore.getUserDetails(),
          fallbackMessage: 'Failed to load user details',
          showErrorSnackbar: true,
        );
        if (response.isSuccess && response.data != null) {
          userData.addAll(response.data!);
        }
        userData['email'] = currentUser.email;
        homeModel.value = HomeModel.fromMap(userData);
        _loadedUserId = currentUser.uid;
      }

      // ── Load dashboard stats in parallel ───────────────────────────
      await Future.wait([
        _loadShipCount(),
        _loadCompanyCount(),
        _loadTripData(),
        _loadTransactionData(),
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
      companies = response.data!;
      _updateHomeModel(companyCount: companies.length);
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
      allTrips.assignAll(trips);
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
      allTransactions.assignAll(transactions);
      _updateHomeModel(recentTransactions: transactions.take(5).toList());
    }
  }

  Future<void> _loadBalanceData() async {
    // ── Lifetime totals from company summaries (source of truth) ─────
    final totalFundOwedValue = _sumCompanyField((c) => c.totalAmountBilled);
    final totalDueValue = _sumCompanyField((c) => c.totalAmountDue);

    // ── Lifetime balance (cash-in-hand): payments − main-balance expenses
    final totalFundReceivedValue = _sumTransactions(
      allTransactions,
      payments: true,
      mainBalanceExpenses: true,
    );

    // ── Monthly totals ─────────────────────────────────────────────────
    final now = DateTime.now();

    // Monthly billed = sum of trip bills this month
    final monthlyFundOwedValue = allTrips
        .where((t) => _isCurrentMonth(t.date, now))
        .fold(0, (sum, t) => sum + _toInt(t.totalBill));

    // Filter transactions to current month
    final monthlyTx = allTransactions
        .where((t) => _isCurrentMonth(t.date, now))
        .toList();

    // Monthly balance (cash-in-hand): payments − main-balance expenses
    final monthlyFundReceivedValue = _sumTransactions(
      monthlyTx,
      payments: true,
      mainBalanceExpenses: true,
    );

    // Monthly due = billed + company expenses − payments
    final monthlyPayments = _sumByCategory(monthlyTx, 'payment');
    final monthlyCompanyExpenses = _sumByCategory(
      monthlyTx,
      'expenses',
      source: 'company',
    );
    final monthlyTotalDueValue =
        monthlyFundOwedValue + monthlyCompanyExpenses - monthlyPayments;

    _updateHomeModel(
      totalFundOwed: totalFundOwedValue,
      totalFundReceived: totalFundReceivedValue,
      totalDue: totalDueValue,
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

  /// Sum a numeric string field across all loaded companies.
  int _sumCompanyField(String Function(CompanyModel) selector) {
    return companies.fold(0, (sum, c) => sum + _toInt(selector(c)));
  }

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
}
