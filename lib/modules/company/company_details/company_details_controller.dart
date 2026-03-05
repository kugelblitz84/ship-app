import 'package:flutter/material.dart';
import 'package:get/get.dart';

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

  double get totalAmountExpenses {
    return transactions.fold<double>(
      0,
      (sum, transaction) => transaction.transactionType == 'expenses'
          ? sum + _toDouble(transaction.amount)
          : sum,
    );
  }

  double get totalAmountDue {
    final companyValue = _toDouble(company?.totalAmountDue);
    if (companyValue != 0) return companyValue;

    return totalAmountBilled - totalAmountReceived + totalAmountExpenses;
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
              _normalize(transaction.companyAndShipInfo.companyName) ==
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
    await CompanyStatementUtil.generateAndSavePdf(
      company: company!,
      trips: trips.toList(),
      transactions: transactions.toList(),
    );
  }

  Future<void> onShowPreviewPressed() async {
    Get.to(
      () => CompanyStatementPreviewPage(
        company: company!,
        trips: trips.toList(),
        transactions: transactions.toList(),
      ),
    );
  }

  Future<void> onRefresh() => loadCompanyDetails();

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
}
