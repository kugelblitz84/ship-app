import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/api_error_handler.dart';
import '../../../core/services/firestore_services/tripdata_service.dart';
import '../models/trip_model.dart';

enum TripSortOption { newest, oldest, fromAZ, toAZ }

class TripHistoryController extends GetxController {
  static const int _pageSize = 10;

  final FirestoreTripService _tripService = Get.find<FirestoreTripService>();
  final ScrollController scrollController = ScrollController();

  RxList<TripModel> trips = <TripModel>[].obs;
  RxBool isLoading = false.obs;
  RxBool isLoadingMore = false.obs;
  RxBool hasMore = true.obs;
  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;

  final TextEditingController fromFilterController = TextEditingController();
  final TextEditingController toFilterController = TextEditingController();
  final TextEditingController productFilterController = TextEditingController();
  final TextEditingController dateFilterController = TextEditingController();
  final TextEditingController searchController = TextEditingController();

  final RxString searchQuery = ''.obs;
  final RxString selectedShipFilter = ''.obs;
  final RxString fromFilter = ''.obs;
  final RxString toFilter = ''.obs;
  final RxString productFilter = ''.obs;
  final RxString dateFilter = ''.obs;
  final Rx<TripSortOption> sortOption = TripSortOption.newest.obs;

  @override
  void onInit() {
    super.onInit();
    fromFilterController.addListener(() {
      fromFilter.value = fromFilterController.text;
    });
    toFilterController.addListener(() {
      toFilter.value = toFilterController.text;
    });
    productFilterController.addListener(() {
      productFilter.value = productFilterController.text;
    });
    dateFilterController.addListener(() {
      dateFilter.value = dateFilterController.text;
    });
    searchController.addListener(() {
      searchQuery.value = searchController.text;
    });
    scrollController.addListener(_onScroll);

    clearAllFilters();
  }

  @override
  void onReady() {
    super.onReady();
    fetchTrips();
  }

  @override
  void onClose() {
    scrollController
      ..removeListener(_onScroll)
      ..dispose();
    fromFilterController.dispose();
    toFilterController.dispose();
    productFilterController.dispose();
    dateFilterController.dispose();
    searchController.dispose();
    super.onClose();
  }

  Future<void> fetchTrips() async {
    await fetchTripsPage(reset: true, showLoader: true);
  }

  Future<void> fetchTripsPage({
    bool reset = false,
    bool showLoader = false,
  }) async {
    if (reset) {
      _lastDocument = null;
      hasMore.value = true;
      trips.clear();
    }

    if (!hasMore.value && !reset) {
      return;
    }

    if (isLoadingMore.value || (showLoader && isLoading.value)) {
      return;
    }

    if (showLoader) {
      isLoading.value = true;
    } else {
      isLoadingMore.value = true;
    }

    try {
      final response = await ApiErrorHandler.call(
        () => _tripService.getTripsPage(
          startAfter: _lastDocument,
          limit: _pageSize,
        ),
        fallbackMessage: 'Failed to load trip history',
      );
      if (!response.isSuccess || response.data == null) return;
      final page = response.data!;
      if (reset) {
        trips.assignAll(page.items);
      } else {
        trips.addAll(page.items);
      }
      _lastDocument = page.lastDocument;
      hasMore.value = page.hasMore;
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  Future<void> onRefresh() async {
    await fetchTripsPage(reset: true, showLoader: false);
  }

  Future<void> loadMoreTrips() async {
    await fetchTripsPage(reset: false, showLoader: false);
  }

  List<TripModel> get filteredTrips {
    final query = searchQuery.value.trim().toLowerCase();
    final ship = selectedShipFilter.value.trim().toLowerCase();
    final from = fromFilter.value.trim().toLowerCase();
    final to = toFilter.value.trim().toLowerCase();
    final product = productFilter.value.trim().toLowerCase();
    final date = dateFilter.value.trim();

    final filtered = trips.where((trip) {
      final tripShip = trip.companyAndShipInfo.shipName.trim().toLowerCase();
      final tripFrom = trip.from.trim().toLowerCase();
      final tripTo = trip.to.trim().toLowerCase();
      final normalizedTripDate = _normalizeDate(trip.date);
      final tripProduct = trip.product?.productName.trim().toLowerCase() ?? '';
      final normalizedRawDate = trip.date.trim().toLowerCase();

      final shipMatch = ship.isEmpty || tripShip == ship;
      final fromMatch = from.isEmpty || tripFrom.contains(from);
      final toMatch = to.isEmpty || tripTo.contains(to);
      final dateMatch =
          date.isEmpty ||
          normalizedTripDate == date ||
          trip.date.trim() == date;
      final productMatch = product.isEmpty || tripProduct.contains(product);

      final searchMatch =
          query.isEmpty ||
          tripShip.contains(query) ||
          tripFrom.contains(query) ||
          tripTo.contains(query) ||
          normalizedRawDate.contains(query) ||
          (normalizedTripDate?.contains(query) ?? false) ||
          tripProduct.contains(query);

      return shipMatch &&
          fromMatch &&
          toMatch &&
          dateMatch &&
          productMatch &&
          searchMatch;
    }).toList();

    filtered.sort((left, right) {
      final leftFrom = left.from.trim().toLowerCase();
      final rightFrom = right.from.trim().toLowerCase();
      final leftTo = left.to.trim().toLowerCase();
      final rightTo = right.to.trim().toLowerCase();

      switch (sortOption.value) {
        case TripSortOption.newest:
          return _safeDate(right.date).compareTo(_safeDate(left.date));
        case TripSortOption.oldest:
          return _safeDate(left.date).compareTo(_safeDate(right.date));
        case TripSortOption.fromAZ:
          return leftFrom.compareTo(rightFrom);
        case TripSortOption.toAZ:
          return leftTo.compareTo(rightTo);
      }
    });

    return filtered;
  }

  List<String> get availableShips {
    final uniqueShips = trips
        .map((trip) => trip.companyAndShipInfo.shipName.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
    uniqueShips.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return uniqueShips;
  }

  List<String> get availableProducts {
    final uniqueProducts = trips
        .map((trip) => trip.product?.productName.trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    uniqueProducts.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return uniqueProducts;
  }

  bool get hasActiveFilters =>
      searchQuery.value.trim().isNotEmpty ||
      selectedShipFilter.value.trim().isNotEmpty ||
      fromFilter.value.trim().isNotEmpty ||
      toFilter.value.trim().isNotEmpty ||
      productFilter.value.trim().isNotEmpty ||
      dateFilter.value.trim().isNotEmpty ||
      sortOption.value != TripSortOption.newest;

  void onSortChanged(TripSortOption? option) {
    if (option == null) return;
    sortOption.value = option;
  }

  void onShipFilterChanged(String? shipName) {
    selectedShipFilter.value = (shipName ?? '').trim();
  }

  void setDateFilter(DateTime? selectedDate) {
    if (selectedDate == null) {
      dateFilter.value = '';
      dateFilterController.clear();
      return;
    }

    final year = selectedDate.year.toString().padLeft(4, '0');
    final month = selectedDate.month.toString().padLeft(2, '0');
    final day = selectedDate.day.toString().padLeft(2, '0');
    final normalized = '$year-$month-$day';

    dateFilter.value = normalized;
    dateFilterController.text = normalized;
  }

  void clearAllFilters() {
    selectedShipFilter.value = '';
    searchController.clear();
    fromFilterController.clear();
    toFilterController.clear();
    productFilterController.clear();
    dateFilterController.clear();

    searchQuery.value = '';
    fromFilter.value = '';
    toFilter.value = '';
    productFilter.value = '';
    dateFilter.value = '';
    sortOption.value = TripSortOption.newest;
  }

  DateTime? get initialDateForPicker {
    if (dateFilter.value.trim().isEmpty) {
      return DateTime.now();
    }
    return DateTime.tryParse(dateFilter.value) ?? DateTime.now();
  }

  String? _normalizeDate(String rawDate) {
    final parsed = DateTime.tryParse(rawDate.trim());
    if (parsed == null) return null;
    final year = parsed.year.toString().padLeft(4, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  DateTime _safeDate(String rawDate) {
    return DateTime.tryParse(rawDate.trim()) ?? DateTime(1970);
  }

  void _onScroll() {
    if (!scrollController.hasClients || isLoadingMore.value || !hasMore.value) {
      return;
    }

    final position = scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      loadMoreTrips();
    }
  }
}
