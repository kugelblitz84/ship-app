import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../core/themes/themes.dart';
import '../../../core/widgets/widgets.dart';
import 'transaction_history_controller.dart';

class TransactionHistoryFilterDialog extends StatelessWidget {
  const TransactionHistoryFilterDialog({super.key, required this.controller});

  final TransactionHistoryController controller;

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
            final years = controller.availableYears;
            final companies = controller.availableCompanies;
            final ships = controller.availableShips;
            final selectedYearValue =
                controller.selectedYear.value == 0 ||
                    years.contains(controller.selectedYear.value)
                ? controller.selectedYear.value
                : 0;
            final selectedCompanyValue =
                controller.selectedCompany.value.trim().isEmpty ||
                    companies.contains(controller.selectedCompany.value)
                ? controller.selectedCompany.value
                : '';
            final selectedShipValue =
                controller.selectedShip.value.trim().isEmpty ||
                    ships.contains(controller.selectedShip.value)
                ? controller.selectedShip.value
                : '';

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
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.base),
                  DropdownButtonFormField<int>(
                    value: controller.selectedMonth.value,
                    decoration: const InputDecoration(
                      labelText: 'Month',
                      prefixIcon: Icon(Icons.calendar_month_rounded),
                    ),
                    borderRadius: AppRadius.md,
                    items: _months
                        .asMap()
                        .entries
                        .map(
                          (entry) => DropdownMenuItem<int>(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(),
                    onChanged: controller.onMonthChanged,
                  ),
                  SizedBox(height: AppSpacing.base),
                  DropdownButtonFormField<int>(
                    value: selectedYearValue,
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      prefixIcon: Icon(Icons.calendar_today_rounded),
                    ),
                    borderRadius: AppRadius.md,
                    items: [
                      const DropdownMenuItem<int>(
                        value: 0,
                        child: Text('All years'),
                      ),
                      ...years.map(
                        (year) => DropdownMenuItem<int>(
                          value: year,
                          child: Text(year.toString()),
                        ),
                      ),
                    ],
                    onChanged: controller.onYearChanged,
                  ),
                  SizedBox(height: AppSpacing.base),
                  DropdownButtonFormField<String>(
                    value: selectedCompanyValue,
                    decoration: const InputDecoration(
                      labelText: 'Company',
                      prefixIcon: Icon(Icons.business_rounded),
                    ),
                    borderRadius: AppRadius.md,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('All companies'),
                      ),
                      ...companies.map(
                        (companyName) => DropdownMenuItem<String>(
                          value: companyName,
                          child: Text(
                            companyName,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                    onChanged: controller.onCompanyChanged,
                  ),
                  SizedBox(height: AppSpacing.base),
                  DropdownButtonFormField<String>(
                    value: selectedShipValue,
                    decoration: const InputDecoration(
                      labelText: 'Ship',
                      prefixIcon: Icon(Icons.directions_boat_rounded),
                    ),
                    borderRadius: AppRadius.md,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('All ships'),
                      ),
                      ...ships.map(
                        (shipName) => DropdownMenuItem<String>(
                          value: shipName,
                          child: Text(
                            shipName,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                    onChanged: controller.onShipChanged,
                  ),
                  SizedBox(height: AppSpacing.base),
                  // Container(
                  //   width: double.infinity,
                  //   padding: EdgeInsets.all(12.w),
                  //   decoration: BoxDecoration(
                  //     color: AppColors.primarySurface,
                  //     borderRadius: AppRadius.md,
                  //     border: Border.all(color: AppColors.neutral200),
                  //   ),
                  //   child: Column(
                  //     crossAxisAlignment: CrossAxisAlignment.start,
                  //     children: [
                  //       Text(
                  //         'Expense filters',
                  //         style: AppTextStyles.labelMedium.copyWith(
                  //           color: AppColors.primary,
                  //         ),
                  //       ),
                  //       SizedBox(height: 8.h),
                  //       SwitchListTile.adaptive(
                  //         contentPadding: EdgeInsets.zero,
                  //         dense: true,
                  //         value: controller.showExpensesOnly.value,
                  //         title: const Text('Show only expenses'),
                  //         subtitle: const Text('Hide payment transactions'),
                  //         onChanged: controller.setShowExpensesOnly,
                  //       ),
                  //       SizedBox(height: 4.h),
                  //       Wrap(
                  //         spacing: 8.w,
                  //         runSpacing: 8.h,
                  //         children: [
                  //           FilterChip(
                  //             selected:
                  //                 controller.includeAddedToDueExpenses.value,
                  //             showCheckmark: false,
                  //             backgroundColor: AppColors.surface,
                  //             selectedColor: const Color(0xFFF9E9D8),
                  //             side: BorderSide(
                  //               color:
                  //                   controller.includeAddedToDueExpenses.value
                  //                   ? AppColors.accent.withValues(alpha: 0.45)
                  //                   : AppColors.neutral300,
                  //             ),
                  //             label: Text(
                  //               'Company Due',
                  //               style: AppTextStyles.labelSmall.copyWith(
                  //                 fontWeight: FontWeight.w600,
                  //                 color:
                  //                     controller.includeAddedToDueExpenses.value
                  //                     ? AppColors.accentDark
                  //                     : AppColors.neutral700,
                  //               ),
                  //             ),
                  //             avatar: Icon(
                  //               controller.includeAddedToDueExpenses.value
                  //                   ? Icons.check_rounded
                  //                   : Icons.add_rounded,
                  //               size: 16.sp,
                  //               color:
                  //                   controller.includeAddedToDueExpenses.value
                  //                   ? AppColors.accentDark
                  //                   : AppColors.neutral500,
                  //             ),
                  //             onSelected:
                  //                 controller.setIncludeAddedToDueExpenses,
                  //           ),
                  //           FilterChip(
                  //             selected:
                  //                 controller.includeMainBalanceExpenses.value,
                  //             showCheckmark: false,
                  //             backgroundColor: AppColors.surface,
                  //             selectedColor: const Color(0xFFE2EEFF),
                  //             side: BorderSide(
                  //               color:
                  //                   controller.includeMainBalanceExpenses.value
                  //                   ? AppColors.info.withValues(alpha: 0.45)
                  //                   : AppColors.neutral300,
                  //             ),
                  //             label: Text(
                  //               'Main Balance',
                  //               style: AppTextStyles.labelSmall.copyWith(
                  //                 fontWeight: FontWeight.w600,
                  //                 color:
                  //                     controller
                  //                         .includeMainBalanceExpenses
                  //                         .value
                  //                     ? AppColors.info
                  //                     : AppColors.neutral700,
                  //               ),
                  //             ),
                  //             avatar: Icon(
                  //               controller.includeMainBalanceExpenses.value
                  //                   ? Icons.check_rounded
                  //                   : Icons.account_balance_wallet_outlined,
                  //               size: 16.sp,
                  //               color:
                  //                   controller.includeMainBalanceExpenses.value
                  //                   ? AppColors.info
                  //                   : AppColors.neutral500,
                  //             ),
                  //             onSelected:
                  //                 controller.setIncludeMainBalanceExpenses,
                  //           ),
                  //         ],
                  //       ),
                  //     ],
                  //   ),
                  // ),
                  SizedBox(height: AppSpacing.base),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickDate(context),
                          icon: const Icon(Icons.event_rounded),
                          label: Text(
                            controller.selectedDate.value == null
                                ? 'Pick specific date'
                                : _formatDateLabel(
                                    controller.selectedDate.value,
                                  ),
                          ),
                        ),
                      ),
                      if (controller.selectedDate.value != null) ...[
                        SizedBox(width: 8.w),
                        IconButton(
                          onPressed: () => controller.setDateFilter(null),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: AppColors.neutral500,
                          ),
                        ),
                      ],
                    ],
                  ),
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
                          text: 'Apply',
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

    if (controller.selectedMonth.value != 0) {
      chips.add(
        _ActiveFilterChip(
          label: 'Month: ${_months[controller.selectedMonth.value]}',
          onRemove: () => controller.onMonthChanged(0),
        ),
      );
    }

    if (controller.selectedYear.value != 0) {
      chips.add(
        _ActiveFilterChip(
          label: 'Year: ${controller.selectedYear.value}',
          onRemove: () => controller.onYearChanged(0),
        ),
      );
    }

    if (controller.selectedCompany.value.trim().isNotEmpty) {
      chips.add(
        _ActiveFilterChip(
          label: 'Company: ${controller.selectedCompany.value.trim()}',
          onRemove: () => controller.onCompanyChanged(null),
        ),
      );
    }

    if (controller.selectedShip.value.trim().isNotEmpty) {
      chips.add(
        _ActiveFilterChip(
          label: 'Ship: ${controller.selectedShip.value.trim()}',
          onRemove: () => controller.onShipChanged(null),
        ),
      );
    }

    if (controller.selectedDate.value != null) {
      chips.add(
        _ActiveFilterChip(
          label: 'Date: ${_formatDateLabel(controller.selectedDate.value)}',
          onRemove: () => controller.setDateFilter(null),
        ),
      );
    }

    if (controller.showExpensesOnly.value) {
      chips.add(
        _ActiveFilterChip(
          label: 'Only expenses',
          onRemove: () => controller.setShowExpensesOnly(false),
        ),
      );
    }

    if (!controller.includeAddedToDueExpenses.value) {
      chips.add(
        _ActiveFilterChip(
          label: 'Exclude: Company Due',
          onRemove: () => controller.setIncludeAddedToDueExpenses(true),
        ),
      );
    }

    if (!controller.includeMainBalanceExpenses.value) {
      chips.add(
        _ActiveFilterChip(
          label: 'Exclude: Main Balance',
          onRemove: () => controller.setIncludeMainBalanceExpenses(true),
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
      initialDate: controller.initialDateForPicker,
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

String _formatDateLabel(DateTime? date) {
  if (date == null) return '';
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

const List<String> _months = [
  'All months',
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
