import 'package:get/get.dart';

import '../../../../core/services/firestore_services/tripdata_service.dart';
import '../../../../routes/app_routes.dart';
import '../../models/transaction_model.dart';

class TransactionDetailsController extends GetxController {
  final FirestoreTripService _tripService = Get.find<FirestoreTripService>();

  TransactionModel? transaction;

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
      Get.snackbar('Trip Unavailable', 'This transaction has no linked trip.');
      return;
    }

    final trips = await _tripService.getTrips();
    final linkedTrip = trips.firstWhereOrNull(
      (trip) => trip.tripId == linkedTripId,
    );

    if (linkedTrip == null) {
      Get.snackbar('Trip Not Found', 'Linked trip could not be loaded.');
      return;
    }

    Get.toNamed(AppRoutes.tripDetails, arguments: linkedTrip);
  }
}
