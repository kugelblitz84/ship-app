import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:urgent/core/services/api_error_handler.dart';
import 'package:urgent/core/services/firebase_auth_service.dart';
import 'package:urgent/core/services/firestore_services/companydata_service.dart';
import 'package:urgent/core/services/firestore_services/transactiondata_service.dart';
import 'package:urgent/core/services/firestore_services/tripdata_service.dart';
import 'package:urgent/modules/Transactions/models/transaction_model.dart';
import 'package:urgent/modules/company/models/company_model.dart';
import 'package:urgent/modules/trip/models/trip_model.dart';
import 'package:urgent/routes/app_routes.dart';

enum CompanySortOption { nameAZ, nameZA, tripsHighToLow, transactionsHighToLow }

enum CompanyActivityFilter { all, withTrips, withTransactions, withBoth }

class CompanyListController extends GetxController {
  final FirestoreCompanyService _companyService =
      Get.find<FirestoreCompanyService>();
  final AuthService _authService = Get.find<AuthService>();
  final FirestoreTripService _tripService = Get.find<FirestoreTripService>();
  final FirestoreTransactionService _transactionService =
      Get.find<FirestoreTransactionService>();

  final RxBool _isLoading = true.obs;
  bool get isLoading => _isLoading.value;

  final RxList<CompanyModel> companies = <CompanyModel>[].obs;
  final TextEditingController searchController = TextEditingController();
  final RxString searchQuery = ''.obs;
  final Rx<CompanySortOption> sortOption = CompanySortOption.nameAZ.obs;
  final Rx<CompanyActivityFilter> activityFilter =
      CompanyActivityFilter.all.obs;
  final RxBool isDeleting = false.obs;
  final Map<String, int> _tripCountsByCompany = <String, int>{};
  final Map<String, int> _transactionCountsByCompany = <String, int>{};

  @override
  void onInit() {
    super.onInit();
    searchController.addListener(() {
      searchQuery.value = searchController.text;
    });
    loadCompanies();
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  Future<void> loadCompanies({bool showLoader = true}) async {
    if (showLoader) {
      _isLoading.value = true;
    }

    final response = await ApiErrorHandler.call(
      () => _companyService.getCompanies(),
      fallbackMessage: 'Failed to load companies',
      showErrorSnackbar: !showLoader,
    );

    if (response.isSuccess && response.data != null) {
      companies.assignAll(response.data!);

      final tripsResponse = await ApiErrorHandler.call(
        () => _tripService.getTrips(),
        fallbackMessage: 'Failed to load trips',
        showErrorSnackbar: !showLoader,
      );
      final transactionsResponse = await ApiErrorHandler.call(
        () => _transactionService.getTransactions(),
        fallbackMessage: 'Failed to load transactions',
        showErrorSnackbar: !showLoader,
      );

      _tripCountsByCompany
        ..clear()
        ..addAll(_groupTripCounts(tripsResponse.data));
      _transactionCountsByCompany
        ..clear()
        ..addAll(_groupTransactionCounts(transactionsResponse.data));
      companies.refresh();
    }

    _isLoading.value = false;
  }

  Future<void> onRefresh() async {
    await loadCompanies(showLoader: false);
  }

  Future<void> onAddCompanyPressed() async {
    await Get.toNamed(AppRoutes.addCompany);
    await loadCompanies(showLoader: false);
  }

  Future<void> onCompanyPressed(CompanyModel company) async {
    final result = await Get.toNamed(
      AppRoutes.companyDetails,
      arguments: company,
    );
    await loadCompanies(showLoader: false);
    if (result == true) {
      Get.snackbar('Success', 'Company deleted successfully.');
    }
  }

  Future<bool> deleteCompanyWithPassword({
    required CompanyModel company,
    required String password,
  }) async {
    final trimmedPassword = password.trim();
    if (trimmedPassword.isEmpty) {
      Get.snackbar('Error', 'Password is required');
      return false;
    }

    if (isDeleting.value) return false;

    isDeleting.value = true;
    try {
      final reauthResponse = await ApiErrorHandler.call(
        () => _authService.reauthenticate(trimmedPassword),
        fallbackMessage: 'Failed to verify password',
      );
      if (!reauthResponse.isSuccess) return false;

      final deleteResponse = await ApiErrorHandler.call(
        () => _companyService.deleteCompany(companyName: company.name),
        fallbackMessage: 'Failed to delete company',
      );
      if (!deleteResponse.isSuccess) return false;

      await loadCompanies(showLoader: false);
      return true;
    } finally {
      isDeleting.value = false;
    }
  }

  List<CompanyModel> get visibleCompanies {
    final query = searchQuery.value.trim().toLowerCase();

    final filtered = companies.where((company) {
      final name = company.name.trim().toLowerCase();
      final description = (company.description ?? '').trim().toLowerCase();
      final tripsCount = _tripCountForCompany(company.name);
      final transactionsCount = _transactionCountForCompany(company.name);

      final activityMatch = switch (activityFilter.value) {
        CompanyActivityFilter.all => true,
        CompanyActivityFilter.withTrips => tripsCount > 0,
        CompanyActivityFilter.withTransactions => transactionsCount > 0,
        CompanyActivityFilter.withBoth =>
          tripsCount > 0 && transactionsCount > 0,
      };

      final searchMatch =
          query.isEmpty || name.contains(query) || description.contains(query);

      return activityMatch && searchMatch;
    }).toList();

    filtered.sort((left, right) {
      final leftName = left.name.trim().toLowerCase();
      final rightName = right.name.trim().toLowerCase();

      switch (sortOption.value) {
        case CompanySortOption.nameAZ:
          return leftName.compareTo(rightName);
        case CompanySortOption.nameZA:
          return rightName.compareTo(leftName);
        case CompanySortOption.tripsHighToLow:
          return _tripCountForCompany(
            right.name,
          ).compareTo(_tripCountForCompany(left.name));
        case CompanySortOption.transactionsHighToLow:
          return _transactionCountForCompany(
            right.name,
          ).compareTo(_transactionCountForCompany(left.name));
      }
    });

    return filtered;
  }

  bool get hasActiveFilters =>
      searchQuery.value.trim().isNotEmpty ||
      activityFilter.value != CompanyActivityFilter.all ||
      sortOption.value != CompanySortOption.nameAZ;

  void onSortChanged(CompanySortOption? value) {
    if (value == null) return;
    sortOption.value = value;
  }

  void onActivityFilterChanged(CompanyActivityFilter? value) {
    if (value == null) return;
    activityFilter.value = value;
  }

  void clearAllFilters() {
    searchController.clear();
    searchQuery.value = '';
    activityFilter.value = CompanyActivityFilter.all;
    sortOption.value = CompanySortOption.nameAZ;
  }

  Map<String, int> _groupTripCounts(List<TripModel>? trips) {
    final counts = <String, int>{};
    if (trips == null) return counts;

    for (final trip in trips) {
      final companyName = trip.companyAndShipInfo.companyName
          .toString()
          .trim()
          .toLowerCase();
      if (companyName.isEmpty) continue;
      counts[companyName] = (counts[companyName] ?? 0) + 1;
    }

    return counts;
  }

  Map<String, int> _groupTransactionCounts(
    List<TransactionModel>? transactions,
  ) {
    final counts = <String, int>{};
    if (transactions == null) return counts;

    for (final transaction in transactions) {
      final companyName = transaction.companyAndShipInfo.companyName
          .toString()
          .trim()
          .toLowerCase();
      if (companyName.isEmpty) continue;
      counts[companyName] = (counts[companyName] ?? 0) + 1;
    }

    return counts;
  }

  int _tripCountForCompany(String companyName) {
    return _tripCountsByCompany[_normalize(companyName)] ?? 0;
  }

  int _transactionCountForCompany(String companyName) {
    return _transactionCountsByCompany[_normalize(companyName)] ?? 0;
  }

  String _normalize(String value) {
    return value.trim().toLowerCase();
  }
}
