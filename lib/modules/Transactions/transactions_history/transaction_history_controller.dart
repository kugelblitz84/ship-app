import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/services/api_error_handler.dart';
import '../../../core/services/firestore_services/transactiondata_service.dart';
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
  final FirestoreTransactionService _transactionService =
      Get.find<FirestoreTransactionService>();

  final RxBool _isLoading = false.obs;
  bool get isLoading => _isLoading.value;

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

  @override
  void onInit() {
    super.onInit();
    searchController.addListener(() {
      searchQuery.value = searchController.text;
    });
    loadTransactions();
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  Future<void> loadTransactions({bool showLoader = true}) async {
    if (showLoader) {
      _isLoading.value = true;
    }

    final response = await ApiErrorHandler.call(
      () => _transactionService.getTransactions(),
      fallbackMessage: 'Failed to load transactions',
      showErrorSnackbar: true,
    );

    if (response.isSuccess && response.data != null) {
      transactions.assignAll(response.data!);
    }

    _isLoading.value = false;
  }

  Future<void> onRefresh() {
    return loadTransactions(showLoader: false);
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
      final route = transaction.routeLabel.toLowerCase();
      final amount = transaction.amount.toLowerCase();
      final type = transaction.type.toLowerCase();
      final transactionType = transaction.transactionType.toLowerCase();
      final expenseSource = transaction.expenseSource.toLowerCase();
      final dateText = transaction.date.toLowerCase();

      final searchMatch =
          query.isEmpty ||
          company.contains(query) ||
          route.contains(query) ||
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

  Future<void> exportFilteredExpensesPdf() async {
    if (!showExpensesOnly.value) {
      Get.snackbar(
        'Enable Expense Filter',
        'Turn on Only expenses before exporting PDF.',
      );
      return;
    }

    final expenses = visibleExpenseTransactions;
    if (expenses.isEmpty) {
      Get.snackbar('No Expenses', 'No filtered expenses found to export.');
      return;
    }

    await ExpensesHistoryUtil.saveExpensesHistoryAndNotify(
      expenses,
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
}
