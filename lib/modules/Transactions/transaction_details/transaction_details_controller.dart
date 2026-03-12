import 'package:get/get.dart';
import 'package:urgent/core/widgets/app_snackbar.dart';
import 'package:flutter/material.dart';

import '../../../core/services/api_error_handler.dart';
import '../../../core/services/firebase_auth_service.dart';
import '../../../core/services/firestore_services/transactiondata_service.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/services/firestore_services/tripdata_service.dart';
import '../../home/home_controller.dart';
import '../transactions_history/transaction_history_controller.dart';
import '../../../routes/app_routes.dart';
import '../models/transaction_model.dart';

class TransactionDetailsController extends GetxController {
  final FirestoreTripService _tripService = Get.find<FirestoreTripService>();
  final FirestoreTransactionService _transactionService =
      Get.find<FirestoreTransactionService>();
  final AuthService _authService = Get.find<AuthService>();

  TransactionModel? transaction;
  final RxBool isDeleting = false.obs;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is TransactionModel) {
      transaction = args;
      return;
    }

    if (args is Map<String, dynamic>) {
      transaction = TransactionModel.fromMap(args);
    }
  }

  Future<void> openLinkedTrip() async {
    final current = transaction;
    if (current == null) return;

    final linkedTripId = current.tripId.trim();
    if (linkedTripId.isEmpty) {
      showAppSnackbar('Trip Unavailable', 'This transaction has no linked trip.');
      return;
    }

    final response = await ApiErrorHandler.call(
      () => _tripService.getTrips(),
      fallbackMessage: 'Failed to load linked trip',
    );
    if (!response.isSuccess || response.data == null) return;

    final trips = response.data!;
    final linkedTrip = trips.firstWhereOrNull(
      (trip) => trip.tripId == linkedTripId,
    );

    if (linkedTrip == null) {
      showAppSnackbar('Trip Not Found', 'Linked trip could not be loaded.');
      return;
    }

    Get.toNamed(AppRoutes.tripDetails, arguments: linkedTrip);
  }

  Future<bool> deleteTransactionWithPassword(String password) async {
    final current = transaction;
    if (current == null || isDeleting.value) return false;

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
          transactionId: current.transactionId,
        ),
        fallbackMessage: 'Failed to delete transaction',
      );
      if (!deleteResponse.isSuccess) return false;

      if (Get.isRegistered<TransactionHistoryController>()) {
        final historyController = Get.find<TransactionHistoryController>();
        historyController.transactions.removeWhere(
          (item) => item.transactionId == current.transactionId,
        );
      }
      if (Get.isRegistered<HomeController>()) {
        await Get.find<HomeController>().loadHomeData();
      }

      return true;
    } finally {
      isDeleting.value = false;
    }
  }

  Future<void> onDeleteTransactionPressed(BuildContext context) async {
    final current = transaction;
    if (current == null) return;

    final deleted = await showPasswordConfirmDeletionDialog(
      context: context,
      title: 'Delete Transaction',
      message:
          'Enter your password to delete this transaction of ৳ ${_formatAmount(_toDouble(current.amount))}.',
      onConfirm: deleteTransactionWithPassword,
    );

    if (!deleted) return;

    showAppSnackbar('Success', 'Transaction deleted successfully.');
    Get.back(result: true);
  }

  double _toDouble(String value) {
    final sanitized = value.replaceAll(',', '').trim();
    return double.tryParse(sanitized) ?? 0;
  }

  String _formatAmount(double value) {
    return value.toInt().toString();
  }
}

