import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../core/themes/themes.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routes/app_routes.dart';
import '../models/trip_model.dart';
import 'trip_hisotry_controller.dart';
import 'trip_history_filter_dialogue.dart';

class TripHistoryView extends GetView<TripHistoryController> {
  const TripHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSliverScaffold(
      title: 'Trip History',
      subtitle: 'Track completed routes and details',
      icon: Icons.history_rounded,
      maxContentWidth: 1120,
      actions: [
        Obx(
          () => controller.hasActiveFilters
              ? IconButton(
                  tooltip: 'Clear filters',
                  icon: const Icon(Icons.filter_alt_off_rounded),
                  onPressed: controller.clearAllFilters,
                )
              : const SizedBox.shrink(),
        ),
      ],
      scrollController: controller.scrollController,
      child: Obx(() {
        final filteredTrips = controller.filteredTrips;

        if (controller.isLoading.value && controller.trips.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SummaryCard(trips: controller.trips),
            SizedBox(height: AppSpacing.lg),
            _TripSearchAndFilterBar(controller: controller),
            SizedBox(height: AppSpacing.lg),
            if (filteredTrips.isEmpty && controller.trips.isNotEmpty)
              _NoFilterResultState(onClear: controller.clearAllFilters)
            else if (controller.trips.isEmpty)
              const _EmptyState()
            else
              ...filteredTrips
                  .map(
                    (trip) => Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.base),
                      child: _TripCard(trip: trip, controller: controller),
                    ),
                  )
                  .toList(),
            if (controller.isLoadingMore.value)
              Padding(
                padding: EdgeInsets.only(top: AppSpacing.sm),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        );
      }),
      onRefresh: controller.onRefresh,
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.trips});

  final List<TripModel> trips;

  @override
  Widget build(BuildContext context) {
    final total = trips.length;
    final totalBilled = trips.fold<double>(
      0,
      (sum, trip) => sum + _toDouble(trip.totalBill),
    );

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg,
        boxShadow: AppShadows.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46.w,
                height: 46.w,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: AppRadius.md,
                ),
                child: Icon(
                  Icons.route_rounded,
                  color: AppColors.primary,
                  size: 22.sp,
                ),
              ),
              SizedBox(width: AppSpacing.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Trips', style: AppTextStyles.bodyMedium),
                    SizedBox(height: 2.h),
                    Text('$total', style: AppTextStyles.headlineSmall),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.base),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _MetaChip(
                icon: Icons.paid_outlined,
                label: 'Total Billed: ৳ ${_formatAmount(totalBilled)}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({required this.controller});

  final TripHistoryController controller;

  @override
  Widget build(BuildContext context) {
    final ships = controller.availableShips;
    final products = controller.availableProducts;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.filter_alt_rounded,
                color: AppColors.primary,
                size: 20.sp,
              ),
              SizedBox(width: 8.w),
              Text('Filters', style: AppTextStyles.labelMedium),
              const Spacer(),
              Text(
                '${controller.filteredTrips.length} result${controller.filteredTrips.length == 1 ? '' : 's'}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.neutral600,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.base),
          DropdownButtonFormField<String>(
            value: controller.selectedShipFilter.value.isEmpty
                ? null
                : controller.selectedShipFilter.value,
            decoration: const InputDecoration(
              hintText: 'Filter by ship',
              prefixIcon: Icon(Icons.directions_boat_outlined),
            ),
            borderRadius: AppRadius.md,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            items: ships
                .map(
                  (shipName) => DropdownMenuItem<String>(
                    value: shipName,
                    child: Text(
                      shipName,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: controller.onShipFilterChanged,
          ),
          SizedBox(height: AppSpacing.base),
          AppTextField(
            controller: controller.dateFilterController,
            label: 'Date',
            hint: 'YYYY-MM-DD',
            prefixIcon: Icons.calendar_today_outlined,
            suffix: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (controller.dateFilter.value.trim().isNotEmpty)
                  IconButton(
                    onPressed: () => controller.setDateFilter(null),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.neutral500,
                    ),
                  ),
                IconButton(
                  onPressed: () => _pickDate(context),
                  icon: const Icon(
                    Icons.edit_calendar_rounded,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.base),
          AppTextField(
            controller: controller.fromFilterController,
            label: 'From',
            hint: 'Search departure',
            prefixIcon: Icons.trip_origin_rounded,
          ),
          SizedBox(height: AppSpacing.base),
          AppTextField(
            controller: controller.toFilterController,
            label: 'To',
            hint: 'Search destination',
            prefixIcon: Icons.place_outlined,
          ),
          SizedBox(height: AppSpacing.base),
          AppTextField(
            controller: controller.productFilterController,
            label: 'Product',
            hint: 'Search product',
            prefixIcon: Icons.inventory_2_outlined,
          ),
          if (products.isNotEmpty) ...[
            SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: products
                  .take(8)
                  .map(
                    (item) => ActionChip(
                      label: Text(item),
                      onPressed: () =>
                          controller.productFilterController.text = item,
                    ),
                  )
                  .toList(),
            ),
          ],
          if (controller.hasActiveFilters) ...[
            SizedBox(height: AppSpacing.base),
            Wrap(spacing: 8.w, runSpacing: 8.h, children: _activeFilters()),
          ],
          SizedBox(height: AppSpacing.base),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: controller.hasActiveFilters
                  ? controller.clearAllFilters
                  : null,
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Reset Filters'),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _activeFilters() {
    final chips = <Widget>[];

    if (controller.selectedShipFilter.value.trim().isNotEmpty) {
      chips.add(
        _ActiveFilterChip(
          label: 'Ship: ${controller.selectedShipFilter.value}',
          onRemove: () => controller.onShipFilterChanged(null),
        ),
      );
    }

    if (controller.dateFilter.value.trim().isNotEmpty) {
      chips.add(
        _ActiveFilterChip(
          label: 'Date: ${controller.dateFilter.value}',
          onRemove: () => controller.setDateFilter(null),
        ),
      );
    }

    if (controller.fromFilter.value.trim().isNotEmpty) {
      chips.add(
        _ActiveFilterChip(
          label: 'From: ${controller.fromFilter.value.trim()}',
          onRemove: () => controller.fromFilterController.clear(),
        ),
      );
    }

    if (controller.toFilter.value.trim().isNotEmpty) {
      chips.add(
        _ActiveFilterChip(
          label: 'To: ${controller.toFilter.value.trim()}',
          onRemove: () => controller.toFilterController.clear(),
        ),
      );
    }

    if (controller.productFilter.value.trim().isNotEmpty) {
      chips.add(
        _ActiveFilterChip(
          label: 'Product: ${controller.productFilter.value.trim()}',
          onRemove: () => controller.productFilterController.clear(),
        ),
      );
    }

    return chips;
  }

  Future<void> _pickDate(BuildContext context) async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: controller.initialDateForPicker ?? DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppColors.primary),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    controller.setDateFilter(selected);
  }
}

class _ActiveFilterChip extends StatelessWidget {
  const _ActiveFilterChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: AppRadius.full,
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.neutral700,
            ),
          ),
          SizedBox(width: 6.w),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close_rounded,
              size: 16.sp,
              color: AppColors.neutral600,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoFilterResultState extends StatelessWidget {
  const _NoFilterResultState({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            color: AppColors.neutral400,
            size: 44.sp,
          ),
          SizedBox(height: AppSpacing.sm),
          Text('No matching trips', style: AppTextStyles.headlineSmall),
          SizedBox(height: 4.h),
          Text(
            'Try adjusting your filters to see more results.',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.base),
          AppButton(
            text: 'Clear Filters',
            icon: Icons.filter_alt_off_rounded,
            isOutlined: true,
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip, required this.controller});

  final TripModel trip;
  final TripHistoryController controller;

  Future<void> _openDetails() async {
    final result = await Get.toNamed(AppRoutes.tripDetails, arguments: trip);
    if (result == true) {
      await controller.fetchTripsPage(reset: true, showLoader: false);
    }
  }

  Future<void> _deleteTrip(BuildContext context) async {
    await controller.onDeleteTripPressed(context, trip);
  }

  @override
  Widget build(BuildContext context) {
    final from = trip.from.trim();
    final to = trip.to.trim();

    return InkWell(
      borderRadius: AppRadius.lg,
      onTap: _openDetails,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.lg,
          border: Border.all(color: AppColors.neutral200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 38.w,
                        height: 38.w,
                        decoration: BoxDecoration(
                          color: AppColors.accentLight,
                          borderRadius: AppRadius.sm,
                        ),
                        child: Icon(
                          Icons.alt_route_rounded,
                          color: AppColors.accent,
                          size: 20.sp,
                        ),
                      ),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${from.isEmpty ? '-' : from} → ${to.isEmpty ? '-' : to}',
                              style: AppTextStyles.labelMedium,
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              _formatDate(trip.date),
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.neutral600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Delete trip',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _deleteTrip(context),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.error,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _openDetails,
                      icon: const Icon(Icons.open_in_new_rounded, size: 13),
                      label: const Text(
                        'View Details',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: AppSpacing.base),
            _MetaRow(
              icon: Icons.business_outlined,
              label: 'Company',
              value: trip.companyAndShipInfo.companyName,
            ),
            _MetaRow(
              icon: Icons.directions_boat_outlined,
              label: 'Ship',
              value: trip.companyAndShipInfo.shipName,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = value.trim().isEmpty ? 'Not provided' : value.trim();

    return Row(
      children: [
        Icon(icon, size: 17.sp, color: AppColors.neutral500),
        SizedBox(width: 8.w),
        Text(
          '$label: ',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.neutral600),
        ),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.neutral50,
        borderRadius: AppRadius.full,
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16.sp, color: AppColors.neutral600),
          SizedBox(width: 6.w),
          Text(label, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

class _ProductChip extends StatelessWidget {
  const _ProductChip({required this.product});

  final ProductInfo product;

  @override
  Widget build(BuildContext context) {
    final productName = product.productName.trim();
    final quantity = product.quantity.trim();
    final unit = product.unit.trim();
    final productDescription = product.desctription?.trim() ?? '';

    final qtyAndUnit = quantity.isEmpty && unit.isEmpty
        ? ''
        : '${quantity.isEmpty ? '-' : quantity} ${unit.isEmpty ? '' : unit}'
              .trim();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: AppColors.infoLight,
        borderRadius: AppRadius.full,
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            productName.isEmpty ? 'N/A' : productName,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.neutral700,
            ),
          ),
          if (qtyAndUnit.isNotEmpty)
            Text(
              qtyAndUnit,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.neutral600,
              ),
            ),
          if (productDescription.isNotEmpty)
            Text(
              productDescription,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.neutral600,
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            color: AppColors.neutral400,
            size: 44.sp,
          ),
          SizedBox(height: AppSpacing.sm),
          Text('No trips yet', style: AppTextStyles.headlineSmall),
          SizedBox(height: 4.h),
          Text(
            'Trips will appear here once new records are added.',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

double _toDouble(String value) {
  return double.tryParse(value.trim()) ?? 0;
}

String _formatAmount(double value) {
  return value.toInt().toString();
}

String _formatDate(String rawDate) {
  final parsed = DateTime.tryParse(rawDate.trim());
  if (parsed == null) {
    return rawDate.trim().isEmpty ? 'Date not provided' : rawDate.trim();
  }

  final year = parsed.year.toString().padLeft(4, '0');
  final month = parsed.month.toString().padLeft(2, '0');
  final day = parsed.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

class _TripSearchAndFilterBar extends StatelessWidget {
  const _TripSearchAndFilterBar({required this.controller});

  final TripHistoryController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller.searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search trips (from, to, ship, company, product)',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    tooltip: 'Filters',
                    icon: const Icon(Icons.filter_alt_rounded),
                    color: AppColors.primary,
                    onPressed: () async {
                      await showDialog(
                        context: context,
                        barrierDismissible: true,
                        builder: (_) =>
                            TripHistoryFilterDialog(controller: controller),
                      );
                    },
                  ),
                  Obx(() {
                    if (!controller.hasActiveFilters) {
                      return const SizedBox.shrink();
                    }
                    return Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        width: 10.w,
                        height: 10.w,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surface,
                            width: 2,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
          SizedBox(height: AppSpacing.base),
          DropdownButtonFormField<TripSortOption>(
            value: controller.sortOption.value,
            decoration: const InputDecoration(
              labelText: 'Sort by',
              prefixIcon: Icon(Icons.sort_rounded),
            ),
            borderRadius: AppRadius.md,
            items: TripSortOption.values
                .map(
                  (option) => DropdownMenuItem<TripSortOption>(
                    value: option,
                    child: Text(_tripSortLabel(option)),
                  ),
                )
                .toList(),
            onChanged: controller.onSortChanged,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            '${controller.filteredTrips.length} result${controller.filteredTrips.length == 1 ? '' : 's'}',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.neutral600,
            ),
          ),
        ],
      ),
    );
  }
}

String _tripSortLabel(TripSortOption option) {
  switch (option) {
    case TripSortOption.newest:
      return 'Newest first';
    case TripSortOption.oldest:
      return 'Oldest first';
    case TripSortOption.fromAZ:
      return 'From A-Z';
    case TripSortOption.toAZ:
      return 'To A-Z';
  }
}
