import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/themes/themes.dart';
import '../../../core/widgets/widgets.dart';
import 'trip_hisotry_controller.dart';

class TripHistoryFilterDialog extends StatelessWidget {
  const TripHistoryFilterDialog({super.key, required this.controller});

  final TripHistoryController controller;

  @override
  Widget build(BuildContext context) {
    final dialogWidth = MediaQuery.of(context).size.width.clamp(320.0, 620.0);

    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 22.h),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lg),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogWidth),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Obx(() {
            final ships = controller.availableShips;
            final products = controller.availableProducts;

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                      IconButton(
                        tooltip: "Close",
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
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
                                  controller.productFilterController.text =
                                      item,
                            ),
                          )
                          .toList(),
                    ),
                  ],

                  if (controller.hasActiveFilters) ...[
                    SizedBox(height: AppSpacing.base),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: _activeFilters(),
                    ),
                  ],

                  SizedBox(height: AppSpacing.lg),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: controller.hasActiveFilters
                              ? controller.clearAllFilters
                              : null,
                          icon: const Icon(Icons.restart_alt_rounded),
                          label: const Text('Reset'),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: AppButton(
                          text: "Apply",
                          icon: Icons.check_rounded,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ),
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

/// (copied from your file, keep same style)
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
