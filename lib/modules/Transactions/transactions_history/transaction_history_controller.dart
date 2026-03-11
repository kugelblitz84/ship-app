import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../core/services/api_error_handler.dart';
import '../../../core/services/firebase_auth_service.dart';
import '../../../core/services/firestore_services/transactiondata_service.dart';
import '../../../core/widgets/widgets.dart';
import '../../../modules/home/home_controller.dart';
import '../../../routes/app_routes.dart';
import '../models/transaction_model.dart';
import '../utils/expenses_hostory_util.dart';

enum TransactionSortOption {
  newest,
  oldest,
  amountHighToLow,
  amountLowToHigh,
  companyAZ,
  companyZA,
}

class TransactionHistoryController extends GetxController {
  static const int _pageSize = 10;

  final FirestoreTransactionService _transactionService =
      Get.find<FirestoreTransactionService>();
  final AuthService _authService = Get.find<AuthService>();
  final ScrollController scrollController = ScrollController();

  final RxBool _isLoading = false.obs;
  bool get isLoading => _isLoading.value;
  final RxBool _isLoadingMore = false.obs;
  bool get isLoadingMore => _isLoadingMore.value;
  final RxBool _hasMore = true.obs;
  bool get hasMore => _hasMore.value;

  final RxBool isDeleting = false.obs;

  final RxList<TransactionModel> transactions = <TransactionModel>[].obs;
  final TextEditingController searchController = TextEditingController();

  final RxString searchQuery = ''.obs;
  final RxInt selectedMonth = 0.obs;
  final RxInt selectedYear = 0.obs;
  final RxString selectedCompany = ''.obs;
  final Rxn<DateTime> selectedDate = Rxn<DateTime>();
  final Rx<TransactionSortOption> sortOption = TransactionSortOption.newest.obs;
  final RxBool showExpensesOnly = false.obs;
  final RxBool includeAddedToDueExpenses = true.obs;
  final RxBool includeMainBalanceExpenses = true.obs;
  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;

  @override
  void onInit() {
    super.onInit();
    searchController.addListener(() {
      searchQuery.value = searchController.text;
    });
    scrollController.addListener(_onScroll);
    loadTransactions(reset: true);
  }

  @override
  void onClose() {
    scrollController
      ..removeListener(_onScroll)
      ..dispose();
    searchController.dispose();
    super.onClose();
  }

  Future<void> loadTransactions({
    bool showLoader = true,
    bool reset = false,
  }) async {
    if (reset) {
      _lastDocument = null;
      _hasMore.value = true;
      transactions.clear();
    }

    if (!_hasMore.value && !reset) {
      return;
    }

    if (_isLoadingMore.value || (showLoader && _isLoading.value)) {
      return;
    }

    if (showLoader) {
      _isLoading.value = true;
    } else {
      _isLoadingMore.value = true;
    }

    final response = await ApiErrorHandler.call(
      () => _transactionService.getTransactionsPage(
        startAfter: _lastDocument,
        limit: _pageSize,
      ),
      fallbackMessage: 'Failed to load transactions',
      showErrorSnackbar: true,
    );

    if (response.isSuccess && response.data != null) {
      final page = response.data!;
      if (reset) {
        transactions.assignAll(page.items);
      } else {
        transactions.addAll(page.items);
      }
      _lastDocument = page.lastDocument;
      _hasMore.value = page.hasMore;
    }

    _isLoading.value = false;
    _isLoadingMore.value = false;
  }

  Future<void> onRefresh() {
    return loadTransactions(showLoader: false, reset: true);
  }

  Future<void> loadMoreTransactions() {
    return loadTransactions(showLoader: false, reset: false);
  }

  Future<bool> deleteTransactionWithPassword({
    required TransactionModel transaction,
    required String password,
  }) async {
    if (isDeleting.value) return false;

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
        () => _transactionService.deleteTransaction(
          transactionId: transaction.transactionId,
        ),
        fallbackMessage: 'Failed to delete transaction',
      );
      if (!deleteResponse.isSuccess) return false;

      transactions.removeWhere(
        (item) => item.transactionId == transaction.transactionId,
      );
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

    Get.snackbar('Success', 'Transaction deleted successfully.');
    await loadTransactions(showLoader: false, reset: true);
  }

  Future<void> openTransactionDetails(TransactionModel transaction) async {
    final result = await Get.toNamed(
      AppRoutes.transactionDetails,
      arguments: transaction,
    );

    if (result == true) {
      await loadTransactions(showLoader: false, reset: true);
    }
  }

  List<TransactionModel> get visibleTransactions {
    final query = searchQuery.value.trim().toLowerCase();
    final month = selectedMonth.value;
    final year = selectedYear.value;
    final selectedCompanyFilter = selectedCompany.value.trim().toLowerCase();
    final dateFilter = selectedDate.value;

    final filtered = transactions.where((transaction) {
      final date = _parseDate(transaction.date);

      final monthMatch = month == 0 || (date != null && date.month == month);
      final yearMatch = year == 0 || (date != null && date.year == year);
      final dateMatch =
          dateFilter == null ||
          (date != null &&
              date.year == dateFilter.year &&
              date.month == dateFilter.month &&
              date.day == dateFilter.day);

      final company = transaction.companyName.trim().toLowerCase();
      final companyFilterMatch =
          selectedCompanyFilter.isEmpty || company == selectedCompanyFilter;
      final expenseToggleMatch = _matchesExpenseToggleFilter(transaction);
      final paymentMethod = transaction.paymentMethodLabel.toLowerCase();
      final amount = transaction.amount.toLowerCase();
      final type = transaction.type.toLowerCase();
      final transactionType = transaction.transactionType.toLowerCase();
      final expenseSource = transaction.expenseSource.toLowerCase();
      final dateText = transaction.date.toLowerCase();

      final searchMatch =
          query.isEmpty ||
          company.contains(query) ||
          paymentMethod.contains(query) ||
          amount.contains(query) ||
          type.contains(query) ||
          transactionType.contains(query) ||
          expenseSource.contains(query) ||
          dateText.contains(query);

      return monthMatch &&
          yearMatch &&
          dateMatch &&
          companyFilterMatch &&
          expenseToggleMatch &&
          searchMatch;
    }).toList();

    filtered.sort((left, right) {
      switch (sortOption.value) {
        case TransactionSortOption.newest:
          return _safeDate(right.date).compareTo(_safeDate(left.date));
        case TransactionSortOption.oldest:
          return _safeDate(left.date).compareTo(_safeDate(right.date));
        case TransactionSortOption.amountHighToLow:
          return _toDouble(right.amount).compareTo(_toDouble(left.amount));
        case TransactionSortOption.amountLowToHigh:
          return _toDouble(left.amount).compareTo(_toDouble(right.amount));
        case TransactionSortOption.companyAZ:
          return left.companyName.toLowerCase().compareTo(
            right.companyName.toLowerCase(),
          );
        case TransactionSortOption.companyZA:
          return right.companyName.toLowerCase().compareTo(
            left.companyName.toLowerCase(),
          );
      }
    });

    return filtered;
  }

  List<TransactionModel> get visibleExpenseTransactions => visibleTransactions
      .where((transaction) => transaction.isExpense)
      .toList();

  bool get hasActiveFilters =>
      searchQuery.value.trim().isNotEmpty ||
      selectedMonth.value != 0 ||
      selectedYear.value != 0 ||
      selectedCompany.value.trim().isNotEmpty ||
      selectedDate.value != null ||
      showExpensesOnly.value ||
      !includeAddedToDueExpenses.value ||
      !includeMainBalanceExpenses.value;

  List<int> get availableYears {
    final years =
        transactions
            .map((transaction) => _parseDate(transaction.date)?.year)
            .whereType<int>()
            .toSet()
            .toList()
          ..sort((left, right) => right.compareTo(left));
    return years;
  }

  List<String> get availableCompanies {
    final companies =
        transactions
            .map((transaction) => transaction.companyName.trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort(
            (left, right) => left.toLowerCase().compareTo(right.toLowerCase()),
          );
    return companies;
  }

  void onSortChanged(TransactionSortOption? value) {
    if (value == null) return;
    sortOption.value = value;
  }

  void onMonthChanged(int? month) {
    selectedMonth.value = month ?? 0;
  }

  void onYearChanged(int? year) {
    selectedYear.value = year ?? 0;
  }

  void onCompanyChanged(String? company) {
    selectedCompany.value = (company ?? '').trim();
  }

  void setDateFilter(DateTime? date) {
    selectedDate.value = date;
  }

  void setShowExpensesOnly(bool value) {
    showExpensesOnly.value = value;

    // Keep UI and filter state aligned: expense-source filters are relevant
    // only while expense-only mode is active.
    if (!value) {
      includeAddedToDueExpenses.value = true;
      includeMainBalanceExpenses.value = true;
    }
  }

  void setIncludeAddedToDueExpenses(bool value) {
    includeAddedToDueExpenses.value = value;
  }

  void setIncludeMainBalanceExpenses(bool value) {
    includeMainBalanceExpenses.value = value;
  }

  void clearAllFilters() {
    searchController.clear();
    searchQuery.value = '';
    selectedMonth.value = 0;
    selectedYear.value = 0;
    selectedCompany.value = '';
    selectedDate.value = null;
    showExpensesOnly.value = false;
    includeAddedToDueExpenses.value = true;
    includeMainBalanceExpenses.value = true;
    sortOption.value = TransactionSortOption.newest;
  }

  Future<void> exportFilteredLedgerPdf() async {
    final ledgerTransactions = visibleTransactions;
    if (ledgerTransactions.isEmpty) {
      Get.snackbar(
        'No Transactions',
        'No filtered transactions found to export ledger.',
      );
      return;
    }

    await TransactionLedgerHistoryUtil.saveTransactionLedgerAndNotify(
      ledgerTransactions,
      dateFilterLabel: _activeDateFilterLabel(),
    );
  }

  String _activeDateFilterLabel() {
    final pickedDate = selectedDate.value;
    if (pickedDate != null) {
      return DateFormat('dd MMM yyyy').format(pickedDate);
    }

    final month = selectedMonth.value;
    final year = selectedYear.value;

    if (month != 0 && year != 0) {
      final monthLabel = DateFormat('MMMM').format(DateTime(2000, month));
      return '$monthLabel $year';
    }

    if (month != 0) {
      final monthLabel = DateFormat('MMMM').format(DateTime(2000, month));
      return '$monthLabel (All years)';
    }

    if (year != 0) {
      return 'Year $year';
    }

    return 'All dates';
  }

  DateTime get initialDateForPicker => selectedDate.value ?? DateTime.now();

  DateTime _safeDate(String value) {
    return _parseDate(value) ?? DateTime(1970);
  }

  DateTime? _parseDate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final direct = DateTime.tryParse(trimmed);
    if (direct != null) return direct;

    final slashParts = trimmed.split('/');
    if (slashParts.length == 3) {
      final first = int.tryParse(slashParts[0]);
      final second = int.tryParse(slashParts[1]);
      final third = int.tryParse(slashParts[2]);
      if (first != null && second != null && third != null) {
        if (first > 31) {
          return DateTime(first, second, third);
        }
        return DateTime(third, first, second);
      }
    }

    final dashParts = trimmed.split('-');
    if (dashParts.length == 3) {
      final first = int.tryParse(dashParts[0]);
      final second = int.tryParse(dashParts[1]);
      final third = int.tryParse(dashParts[2]);
      if (first != null && second != null && third != null) {
        if (first > 31) {
          return DateTime(first, second, third);
        }
        return DateTime(third, second, first);
      }
    }

    return null;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) {
      final sanitized = value.replaceAll(',', '').trim();
      return double.tryParse(sanitized) ?? 0;
    }
    return 0;
  }

  String _formatAmount(double value) {
    return value.toInt().toString();
  }

  bool _matchesExpenseToggleFilter(TransactionModel transaction) {
    final isExpense = transaction.isExpense;

    if (showExpensesOnly.value && !isExpense) {
      return false;
    }

    if (!isExpense) {
      return true;
    }

    final source = transaction.normalizedExpenseSource;
    final includeDueExpense =
        source == 'company' && includeAddedToDueExpenses.value;
    final includeMainBalanceExpense =
        source == 'main-balance' && includeMainBalanceExpenses.value;

    // Preserve unknown expense source entries unless explicitly narrowed.
    final includeUnknownExpenseSource =
        source != 'company' &&
        source != 'main-balance' &&
        includeAddedToDueExpenses.value &&
        includeMainBalanceExpenses.value;

    return includeDueExpense ||
        includeMainBalanceExpense ||
        includeUnknownExpenseSource;
  }

  void _onScroll() {
    if (!scrollController.hasClients ||
        _isLoadingMore.value ||
        !_hasMore.value) {
      return;
    }

    final position = scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      loadMoreTransactions();
    }
  }
}
