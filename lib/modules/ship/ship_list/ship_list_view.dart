import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../core/themes/themes.dart';
import '../../../core/widgets/widgets.dart';
import '../models/ship_model.dart';
import 'ship_list_controller.dart';

class ShipListView extends GetView<ShipListController> {
  const ShipListView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSliverScaffold(
      title: 'Ships',
      subtitle: 'Manage your fleet records',
      icon: Icons.directions_boat_rounded,
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: controller.onAddShipPressed,
        icon: const Icon(Icons.add_rounded, color: AppColors.primary),
        label: const Text(
          'Add Ship',
          style: TextStyle(color: AppColors.primary),
        ),
      ),
      scrollController: controller.scrollController,
      child: Obx(() {
        final visibleShips = controller.visibleShips;

        if (controller.isLoading && controller.ships.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SummaryCard(count: controller.ships.length),
            SizedBox(height: AppSpacing.lg),
            _ShipSearchSortFilterBar(controller: controller),
            SizedBox(height: AppSpacing.lg),
            if (visibleShips.isEmpty && controller.ships.isNotEmpty)
              _NoFilterResultState(onClear: controller.clearAllFilters)
            else if (controller.ships.isEmpty)
              _EmptyState(onAddPressed: controller.onAddShipPressed)
            else
              ...visibleShips
                  .map(
                    (ship) => Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.base),
                      child: _ShipCard(
                        ship: ship,
                        onTap: () => controller.onShipPressed(ship),
                        onDelete: () =>
                            controller.onDeleteShipPressed(context, ship),
                      ),
                    ),
                  )
                  .toList(),
            if (controller.isLoadingMore)
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

class _ShipSearchSortFilterBar extends StatelessWidget {
  const _ShipSearchSortFilterBar({required this.controller});

  final ShipListController controller;

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
          AppTextField(
            controller: controller.searchController,
            hint: 'Search ship name or license',
            prefixIcon: Icons.search_rounded,
            suffix: controller.searchQuery.value.trim().isNotEmpty
                ? IconButton(
                    onPressed: controller.searchController.clear,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.neutral500,
                    ),
                  )
                : null,
          ),
          SizedBox(height: AppSpacing.base),
          DropdownButtonFormField<ShipSortOption>(
            value: controller.sortOption.value,
            decoration: const InputDecoration(
              labelText: 'Sort by',
              prefixIcon: Icon(Icons.sort_rounded),
            ),
            borderRadius: AppRadius.md,
            items: ShipSortOption.values
                .map(
                  (option) => DropdownMenuItem<ShipSortOption>(
                    value: option,
                    child: Text(_shipSortLabel(option)),
                  ),
                )
                .toList(),
            onChanged: controller.onSortChanged,
          ),
          SizedBox(height: AppSpacing.base),
          DropdownButtonFormField<ShipLicenseFilter>(
            value: controller.licenseFilter.value,
            decoration: const InputDecoration(
              labelText: 'License status',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            borderRadius: AppRadius.md,
            items: ShipLicenseFilter.values
                .map(
                  (filter) => DropdownMenuItem<ShipLicenseFilter>(
                    value: filter,
                    child: Text(_shipLicenseFilterLabel(filter)),
                  ),
                )
                .toList(),
            onChanged: controller.onLicenseFilterChanged,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            '${controller.visibleShips.length} result${controller.visibleShips.length == 1 ? '' : 's'}',
            style: AppTextStyles.bodySmall.copyWith(
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
          Text('No matching ships', style: AppTextStyles.headlineSmall),
          SizedBox(height: 4.h),
          Text(
            'Adjust your search or filter to find ships.',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.base),
          OutlinedButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Clear filters'),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg,
        boxShadow: AppShadows.md,
      ),
      child: Row(
        children: [
          Container(
            width: 46.w,
            height: 46.w,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: AppRadius.md,
            ),
            child: Icon(
              Icons.directions_boat_outlined,
              color: AppColors.primary,
              size: 22.sp,
            ),
          ),
          SizedBox(width: AppSpacing.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Ships', style: AppTextStyles.bodyMedium),
                SizedBox(height: 2.h),
                Text('$count', style: AppTextStyles.headlineSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShipCard extends StatelessWidget {
  const _ShipCard({required this.ship, this.onTap, this.onDelete});

  final ShipModel ship;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final license = (ship.licenseNumber ?? '').trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.lg,
        onTap: onTap,
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
                children: [
                  Container(
                    width: 38.w,
                    height: 38.w,
                    decoration: BoxDecoration(
                      color: AppColors.accentLight,
                      borderRadius: AppRadius.sm,
                    ),
                    child: Icon(
                      Icons.sailing_rounded,
                      color: AppColors.accent,
                      size: 20.sp,
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(ship.name, style: AppTextStyles.labelMedium),
                  ),
                  InkWell(
                    borderRadius: AppRadius.full,
                    onTap: onDelete,
                    child: Padding(
                      padding: EdgeInsets.all(4.w),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 18.sp,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Icon(
                    Icons.open_in_new_rounded,
                    size: 18.sp,
                    color: AppColors.primary,
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.base),
              _MetaRow(
                icon: Icons.badge_outlined,
                label: 'License',
                value: license.isEmpty ? 'Not provided' : license,
              ),
            ],
          ),
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
            value,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddPressed});

  final VoidCallback onAddPressed;

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
            Icons.directions_boat_outlined,
            color: AppColors.neutral400,
            size: 44.sp,
          ),
          SizedBox(height: AppSpacing.sm),
          Text('No ships yet', style: AppTextStyles.headlineSmall),
          SizedBox(height: 4.h),
          Text(
            'Add your first ship to start building the fleet.',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.base),
          AppButton(
            text: 'Add Ship',
            icon: Icons.add_rounded,
            onPressed: onAddPressed,
          ),
        ],
      ),
    );
  }
}

String _shipSortLabel(ShipSortOption option) {
  switch (option) {
    case ShipSortOption.nameAZ:
      return 'Name A-Z';
    case ShipSortOption.nameZA:
      return 'Name Z-A';
    case ShipSortOption.licenseAZ:
      return 'License A-Z';
    case ShipSortOption.licenseZA:
      return 'License Z-A';
  }
}

String _shipLicenseFilterLabel(ShipLicenseFilter filter) {
  switch (filter) {
    case ShipLicenseFilter.all:
      return 'All ships';
    case ShipLicenseFilter.withLicense:
      return 'With license';
    case ShipLicenseFilter.withoutLicense:
      return 'Without license';
  }
}
