import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:urgent/core/widgets/app_snackbar.dart';

import '../../core/services/api_error_handler.dart';
import '../../core/services/firebase_auth_service.dart';
import '../../core/services/firestore_services/cash_in_cash_out_service.dart';
import '../../core/services/firestore_services/transactiondata_service.dart';
import '../../core/widgets/widgets.dart';
import '../Transactions/models/transaction_model.dart';
import '../home/home_controller.dart';
import 'models/cash_in_cash_out_model.dart';
import 'utils/cash_in_cash_out_history_util.dart';

class CashInCashOutController extends GetxController {
  static const int _pageSize = 10;

  final formKey = GlobalKey<FormState>();

  final TextEditingController amountController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController noteController = TextEditingController();
  final TextEditingController searchController = TextEditingController();

  final FirestoreCashInCashOutService _cashService =
      Get.find<FirestoreCashInCashOutService>();
  final FirestoreTransactionService _transactionService =
      Get.find<FirestoreTransactionService>();
  final AuthService _authService = Get.find<AuthService>();

  final RxBool _isLoading = false.obs;
  bool get isLoading => _isLoading.value;

  final RxBool _isSubmitting = false.obs;
  bool get isSubmitting => _isSubmitting.value;
  final RxBool _isUpdatingEntry = false.obs;
  bool get isUpdatingEntry => _isUpdatingEntry.value;

  final ScrollController historyScrollController = ScrollController();
  final RxBool _isLoadingMoreEntries = false.obs;
  bool get isLoadingMoreEntries => _isLoadingMoreEntries.value;
  final RxInt _visibleEntriesCount = 0.obs;

  final RxList<CashInCashOutModel> entries = <CashInCashOutModel>[].obs;
  final RxList<TransactionModel> transactions = <TransactionModel>[].obs;
  final RxList<String> transactionTypes = <String>[].obs;

  final RxString selectedFlowType = 'cash-in'.obs;
  final RxString selectedTransactionType = 'cash'.obs;
  final RxString searchQuery = ''.obs;
  final RxString selectedFilterType = ''.obs;
  final Rxn<DateTime> selectedStartDate = Rxn<DateTime>();
  final Rxn<DateTime> selectedEndDate = Rxn<DateTime>();
  final RxBool isDeletingType = false.obs;
  final RxBool isDeletingEntry = false.obs;

  static const List<String> flowTypes = <String>['cash-in', 'cash-out'];

  bool get hasMoreEntries =>
      _visibleEntriesCount.value < filteredEntries.length;

  bool get hasActiveFilters =>
      searchQuery.value.trim().isNotEmpty ||
      selectedFilterType.value.trim().isNotEmpty ||
      selectedStartDate.value != null ||
      selectedEndDate.value != null;

  List<String> get availableFilterTypes {
    final unique =
        {
          ...transactionTypes
              .map((type) => type.trim())
              .where((t) => t.isNotEmpty),
          ...entries
              .map((entry) => entry.transactionType.trim())
              .where((type) => type.isNotEmpty),
        }.toList()..sort(
          (left, right) => left.toLowerCase().compareTo(right.toLowerCase()),
        );
    return unique;
  }

  List<CashInCashOutModel> get filteredEntries {
    final query = searchQuery.value.trim().toLowerCase();
    final typeFilter = selectedFilterType.value.trim().toLowerCase();
    final startDate = selectedStartDate.value;
    final endDate = selectedEndDate.value;

    return entries
        .where((entry) {
          final entryDate = _tryParseDate(entry.date.trim());
          final entryType = entry.transactionType.trim().toLowerCase();
          final flowType = entry.flowType.trim().toLowerCase();
          final note = (entry.note ?? '').trim().toLowerCase();
          final amount = entry.amount.trim().toLowerCase();
          final dateText = entry.date.trim().toLowerCase();

          final queryMatch =
              query.isEmpty ||
              entryType.contains(query) ||
              flowType.contains(query) ||
              note.contains(query) ||
              amount.contains(query) ||
              dateText.contains(query);

          final typeMatch = typeFilter.isEmpty || entryType == typeFilter;

          final startMatch =
              startDate == null ||
              (entryDate != null &&
                  !_dateOnly(entryDate).isBefore(_dateOnly(startDate)));

          final endMatch =
              endDate == null ||
              (entryDate != null &&
                  !_dateOnly(entryDate).isAfter(_dateOnly(endDate)));

          return queryMatch && typeMatch && startMatch && endMatch;
        })
        .toList(growable: false);
  }

  List<CashInCashOutModel> get visibleEntries {
    final filtered = filteredEntries;
    final end = _visibleEntriesCount.value.clamp(0, filtered.length);
    return filtered.take(end).toList(growable: false);
  }

  @override
  void onInit() {
    super.onInit();
    _setTodayDate();
    searchController.addListener(_onSearchChanged);
    historyScrollController.addListener(_onHistoryScroll);
    loadData();
  }

  Future<void> loadData() async {
    _isLoading.value = true;
    try {
      final typeResponse = await ApiErrorHandler.call(
        () => _cashService.setCashFlowTransactionTypes(),
        fallbackMessage: 'Failed to load cash flow transaction types',
        showErrorSnackbar: true,
      );
      final cashResponse = await ApiErrorHandler.call(
        () => _cashService.getEntriesSortedByDateDesc(),
        fallbackMessage: 'Failed to load cash flow history',
        showErrorSnackbar: true,
      );
      final txResponse = await ApiErrorHandler.call(
        () => _transactionService.getTransactions(),
        fallbackMessage: 'Failed to load transactions',
        showErrorSnackbar: false,
      );

      if (typeResponse.isSuccess) {
        transactionTypes.assignAll(_cashService.allowedTransactionTypes);
        transactionTypes.sort((left, right) {
          return left.toLowerCase().compareTo(right.toLowerCase());
        });
        if (!transactionTypes.contains(selectedTransactionType.value)) {
          selectedTransactionType.value = transactionTypes.isEmpty
              ? 'cash'
              : transactionTypes.first;
        }
      }

      if (cashResponse.isSuccess && cashResponse.data != null) {
        entries.assignAll(cashResponse.data!);
        _resetEntriesPagination();
      } else {
        entries.clear();
        _resetEntriesPagination();
      }

      if (txResponse.isSuccess && txResponse.data != null) {
        transactions.assignAll(txResponse.data!);
      }
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> onRefresh() => loadData();

  Future<void> loadMoreEntries() async {
    if (_isLoading.value || _isLoadingMoreEntries.value || !hasMoreEntries) {
      return;
    }

    _isLoadingMoreEntries.value = true;
    try {
      _visibleEntriesCount.value = (_visibleEntriesCount.value + _pageSize)
          .clamp(0, filteredEntries.length);
    } finally {
      _isLoadingMoreEntries.value = false;
    }
  }

  String? transactionTypeValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Transaction type is required';
    }
    return null;
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

  String? dateValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Date is required';
    }

    if (DateTime.tryParse(value.trim()) == null) {
      return 'Date must be in YYYY-MM-DD format';
    }

    return null;
  }

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

  Future<void> onSavePressed() async {
    if (_isSubmitting.value) return;

    await _ensureTransactionTypesLoaded();

    if (!(formKey.currentState?.validate() ?? false)) {
      showAppSnackbar(
        'Missing Information',
        'Please complete amount and date before submitting.',
      );
      return;
    }

    _isSubmitting.value = true;
    try {
      final entry = CashInCashOutModel(
        entryId: _cashService.createEntryId(),
        flowType: selectedFlowType.value,
        transactionType: selectedTransactionType.value,
        amount: amountController.text.trim(),
        date: dateController.text.trim(),
        note: noteController.text.trim(),
      );

      final response = await ApiErrorHandler.call(
        () => _cashService.addEntry(entry: entry),
        fallbackMessage: 'Failed to save cash flow entry',
        showErrorSnackbar: true,
      );

      if (!response.isSuccess) return;

      clearForm();
      await loadData();
      if (Get.isRegistered<HomeController>()) {
        await Get.find<HomeController>().loadHomeData();
      }

      showAppSnackbar(
        'Entry Saved',
        entry.isCashOut
            ? 'Cash out deducted from main balance successfully.'
            : 'Cash in added to main balance successfully.',
      );
    } finally {
      _isSubmitting.value = false;
    }
  }

  Future<bool> deleteEntryWithPassword({
    required CashInCashOutModel entry,
    required String password,
  }) async {
    final trimmedPassword = password.trim();

    if (trimmedPassword.isEmpty) {
      showAppSnackbar('Error', 'Password is required');
      return false;
    }

    if (isDeletingEntry.value) return false;

    isDeletingEntry.value = true;
    try {
      final reauthResponse = await ApiErrorHandler.call(
        () => _authService.reauthenticate(trimmedPassword),
        fallbackMessage: 'Failed to verify password',
      );
      if (!reauthResponse.isSuccess) return false;

      final deleteResponse = await ApiErrorHandler.call(
        () => _cashService.deleteEntry(entryId: entry.entryId),
        fallbackMessage: 'Failed to delete cash flow entry',
        showErrorSnackbar: true,
      );
      if (!deleteResponse.isSuccess) return false;

      entries.removeWhere((item) => item.entryId == entry.entryId);
      _visibleEntriesCount.value = _visibleEntriesCount.value.clamp(
        0,
        filteredEntries.length,
      );
      if (Get.isRegistered<HomeController>()) {
        await Get.find<HomeController>().loadHomeData();
      }

      return true;
    } finally {
      isDeletingEntry.value = false;
    }
  }

  Future<void> onDeleteEntryPressed(
    BuildContext context,
    CashInCashOutModel entry,
  ) async {
    final deleted = await showPasswordConfirmDeletionDialog(
      context: context,
      title: 'Delete Entry',
      message:
          'Enter your password to delete this ${entry.flowTypeLabel.toLowerCase()} entry of ৳ ${formatAmount(_toDouble(entry.amount))}.',
      onConfirm: (password) =>
          deleteEntryWithPassword(entry: entry, password: password),
    );

    if (!deleted) return;

    showAppSnackbar('Entry Deleted', 'Cash flow entry removed successfully.');
  }

  Future<bool> onEditEntrySavePressed({
    required CashInCashOutModel entry,
    required String flowType,
    required String transactionType,
    required String amount,
    required String note,
  }) async {
    if (_isUpdatingEntry.value) return false;

    await _ensureTransactionTypesLoaded();

    final normalizedFlowType = flowType.trim().toLowerCase();
    final normalizedType = transactionType.trim().toLowerCase();
    final amountValue = _toDouble(amount);

    if (normalizedFlowType != 'cash-in' && normalizedFlowType != 'cash-out') {
      showAppSnackbar('Error', 'Flow type is invalid.');
      return false;
    }

    if (normalizedType.isEmpty) {
      showAppSnackbar('Error', 'Transaction type is required.');
      return false;
    }

    if (!transactionTypes.contains(normalizedType)) {
      showAppSnackbar('Error', 'Please select a valid transaction type.');
      return false;
    }

    if (amountValue <= 0) {
      showAppSnackbar('Error', 'Amount must be greater than zero.');
      return false;
    }

    _isUpdatingEntry.value = true;
    try {
      final updatedEntry = CashInCashOutModel(
        entryId: entry.entryId,
        flowType: normalizedFlowType,
        transactionType: normalizedType,
        amount: amountValue.toInt().toString(),
        date: entry.date,
        note: note.trim(),
        createdAt: entry.createdAt,
      );

      final response = await ApiErrorHandler.call(
        () => _cashService.updateEntry(entry: updatedEntry),
        fallbackMessage: 'Failed to update cash flow entry',
        showErrorSnackbar: true,
      );
      if (!response.isSuccess) return false;

      await loadData();
      if (Get.isRegistered<HomeController>()) {
        await Get.find<HomeController>().loadHomeData();
      }
      return true;
    } finally {
      _isUpdatingEntry.value = false;
    }
  }

  Future<void> exportHistory() async {
    // Always fetch full history for PDF export, not only currently visible rows.
    final response = await ApiErrorHandler.call<List<CashInCashOutModel>>(
      () => _cashService.getEntriesSortedByDateDesc(),
      fallbackMessage: 'Failed to load full cash flow history for export',
      showErrorSnackbar: true,
    );

    if (!response.isSuccess || response.data == null) {
      return;
    }

    await CashInCashOutHistoryUtil.saveCashInCashOutHistoryAndNotify(
      response.data!,
    );
  }

  double get cashFlowBalance => _cashService.computeNetCashFlow(entries);

  double get transactionMainBalance {
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

  double get combinedMainBalance => transactionMainBalance + cashFlowBalance;

  void onFlowTypeChanged(String? value) {
    if (value == null || value.trim().isEmpty) return;
    selectedFlowType.value = value;
  }

  void onTransactionTypeChanged(String? value) {
    if (value == null || value.trim().isEmpty) return;
    selectedTransactionType.value = value;
  }

  void onFilterTypeChanged(String? value) {
    selectedFilterType.value = (value ?? '').trim();
    _resetEntriesPagination();
  }

  void clearAllFilters() {
    searchController.clear();
    searchQuery.value = '';
    selectedFilterType.value = '';
    selectedStartDate.value = null;
    selectedEndDate.value = null;
    _resetEntriesPagination();
  }

  Future<void> onPickFilterStartDatePressed(BuildContext context) async {
    final now = DateTime.now();
    final initial = selectedStartDate.value ?? selectedEndDate.value ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 10),
    );

    if (picked == null) return;
    selectedStartDate.value = _dateOnly(picked);
    final end = selectedEndDate.value;
    if (end != null && _dateOnly(picked).isAfter(_dateOnly(end))) {
      selectedEndDate.value = _dateOnly(picked);
    }
    _resetEntriesPagination();
  }

  Future<void> onPickFilterEndDatePressed(BuildContext context) async {
    final now = DateTime.now();
    final initial = selectedEndDate.value ?? selectedStartDate.value ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 10),
    );

    if (picked == null) return;
    selectedEndDate.value = _dateOnly(picked);
    final start = selectedStartDate.value;
    if (start != null && _dateOnly(picked).isBefore(_dateOnly(start))) {
      selectedStartDate.value = _dateOnly(picked);
    }
    _resetEntriesPagination();
  }

  String formatFilterDate(DateTime? date) {
    if (date == null) return '--';
    return _formatDate(date);
  }

  Future<String?> saveCashFlowTransactionType(String type) async {
    final normalizedType = _normalize(type);

    if (normalizedType.isEmpty) {
      showAppSnackbar('Error', 'Transaction type is required');
      return null;
    }

    final response = await ApiErrorHandler.call(
      () => _cashService.addCashFlowTransactionType(normalizedType),
      fallbackMessage: 'Failed to add transaction type',
      showErrorSnackbar: true,
    );

    if (!response.isSuccess) return null;
    return normalizedType;
  }

  void applyCashFlowTransactionType(String normalizedType) {
    if (!transactionTypes.contains(normalizedType)) {
      transactionTypes.add(normalizedType);
      transactionTypes.sort((left, right) {
        return left.toLowerCase().compareTo(right.toLowerCase());
      });
    }
    selectedTransactionType.value = normalizedType;
    _resetEntriesPagination();
  }

  Future<bool> deleteCashFlowTransactionTypeWithPassword({
    required String type,
    required String password,
  }) async {
    final normalizedType = _normalize(type);
    final trimmedPassword = password.trim();

    if (normalizedType.isEmpty) {
      showAppSnackbar('Error', 'Transaction type is required');
      return false;
    }

    if (trimmedPassword.isEmpty) {
      showAppSnackbar('Error', 'Password is required');
      return false;
    }

    if (isDeletingType.value) return false;

    isDeletingType.value = true;
    try {
      final reauthResponse = await ApiErrorHandler.call(
        () => _authService.reauthenticate(trimmedPassword),
        fallbackMessage: 'Failed to verify password',
      );
      if (!reauthResponse.isSuccess) return false;

      final deleteResponse = await ApiErrorHandler.call(
        () => _cashService.deleteCashFlowTransactionType(normalizedType),
        fallbackMessage: 'Failed to delete transaction type',
      );
      if (!deleteResponse.isSuccess) return false;

      transactionTypes.removeWhere(
        (item) => _normalize(item) == normalizedType,
      );
      if (_normalize(selectedTransactionType.value) == normalizedType) {
        selectedTransactionType.value = transactionTypes.isEmpty
            ? 'cash'
            : transactionTypes.first;
      }
      if (_normalize(selectedFilterType.value) == normalizedType) {
        selectedFilterType.value = '';
      }
      _resetEntriesPagination();
      return true;
    } finally {
      isDeletingType.value = false;
    }
  }

  Future<void> onDeleteCashFlowTransactionTypePressed(
    BuildContext context,
    String type,
  ) async {
    final deleted = await showPasswordConfirmDeletionDialog(
      context: context,
      title: 'Delete Transaction Type',
      message: 'Enter your password to delete "$type".',
      onConfirm: (password) => deleteCashFlowTransactionTypeWithPassword(
        type: type,
        password: password,
      ),
    );

    if (!deleted) return;

    showAppSnackbar('Type Deleted', 'Cash flow transaction type deleted.');
  }

  String formatAmount(double value) => value.toInt().toString();

  void clearForm() {
    amountController.clear();
    noteController.clear();
    selectedFlowType.value = 'cash-in';
    if (transactionTypes.isNotEmpty) {
      selectedTransactionType.value = transactionTypes.first;
    }
    _setTodayDate();
  }

  void _setTodayDate() {
    dateController.text = _formatDate(DateTime.now());
  }

  void _resetEntriesPagination() {
    final total = filteredEntries.length;
    _visibleEntriesCount.value = total < _pageSize ? total : _pageSize;
    _isLoadingMoreEntries.value = false;
  }

  void _onSearchChanged() {
    searchQuery.value = searchController.text;
    _resetEntriesPagination();
  }

  void _onHistoryScroll() {
    if (!historyScrollController.hasClients ||
        _isLoading.value ||
        _isLoadingMoreEntries.value ||
        !hasMoreEntries) {
      return;
    }

    final position = historyScrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      loadMoreEntries();
    }
  }

  DateTime? _tryParseDate(String value) {
    if (value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
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

  String _normalize(String value) {
    return value.trim().toLowerCase();
  }

  Future<void> _ensureTransactionTypesLoaded() async {
    if (transactionTypes.isNotEmpty) return;

    final typeResponse = await ApiErrorHandler.call(
      () => _cashService.setCashFlowTransactionTypes(),
      fallbackMessage: 'Failed to load cash flow transaction types',
      showErrorSnackbar: true,
    );

    if (!typeResponse.isSuccess) return;

    transactionTypes.assignAll(_cashService.allowedTransactionTypes);
    transactionTypes.sort((left, right) {
      return left.toLowerCase().compareTo(right.toLowerCase());
    });
    if (transactionTypes.isNotEmpty &&
        !transactionTypes.contains(selectedTransactionType.value)) {
      selectedTransactionType.value = transactionTypes.first;
    }
  }

  @override
  void onClose() {
    historyScrollController
      ..removeListener(_onHistoryScroll)
      ..dispose();
    searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    amountController.dispose();
    dateController.dispose();
    noteController.dispose();
    super.onClose();
  }
}
