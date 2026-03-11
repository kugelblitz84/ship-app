import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/themes/themes.dart';
import '../../../core/widgets/widgets.dart';
import '../../Transactions/models/transaction_model.dart';
import '../../trip/models/trip_model.dart';
import 'company_details_controller.dart';

class CompanyDetailsView extends GetView<CompanyDetailsController> {
  const CompanyDetailsView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSliverScaffold(
      title: 'Company Details',
      subtitle: 'Profile, statement, trips and transactions',
      icon: Icons.business_rounded,
      maxContentWidth: 1120,
      actions: [
        Obx(() {
          if (controller.company == null) {
            return const SizedBox.shrink();
          }

          final busy =
              controller.isSaving.value ||
              controller.isDeleting.value ||
              controller.isLoading;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                onPressed: busy
                    ? null
                    : () => controller.onDeleteCompanyPressed(context),
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 18.sp,
                  color: Colors.white,
                ),
                label: Text(
                  'Delete',
                  style: AppTextStyles.labelSmall.copyWith(color: Colors.white),
                ),
              ),
              TextButton.icon(
                onPressed: busy
                    ? null
                    : (controller.isEditing.value
                          ? controller.cancelEditing
                          : controller.startEditing),
                icon: Icon(
                  controller.isEditing.value
                      ? Icons.close_rounded
                      : Icons.edit_outlined,
                  size: 18.sp,
                  color: Colors.white,
                ),
                label: Text(
                  controller.isEditing.value ? 'Cancel' : 'Edit',
                  style: AppTextStyles.labelSmall.copyWith(color: Colors.white),
                ),
              ),
            ],
          );
        }),
      ],
      onRefresh: controller.onRefresh,
      child: Obx(() {
        final company = controller.company;

        if (company == null) {
          return _InvalidCompanyState(onBackPressed: () => Get.back());
        }

        if (controller.isLoading &&
            controller.trips.isEmpty &&
            controller.transactions.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Company Information ──────────────────────────
            _SectionCard(
              icon: Icons.info_outline_rounded,
              title: 'Company Information',
              children: controller.isEditing.value
                  ? [
                      _DetailRow(
                        icon: Icons.business_outlined,
                        label: 'Company Name',
                        value: _safeText(company.name),
                      ),
                      SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: controller.descriptionController,
                        label: 'Description',
                        maxLines: 3,
                        prefixIcon: Icons.notes_outlined,
                      ),
                      SizedBox(height: AppSpacing.base),
                      AppButton(
                        text: 'Save Changes',
                        icon: Icons.save_rounded,
                        isLoading: controller.isSaving.value,
                        onPressed: controller.saveChanges,
                      ),
                    ]
                  : [
                      _DetailRow(
                        icon: Icons.business_outlined,
                        label: 'Company Name',
                        value: _safeText(company.name),
                      ),
                      _DetailRow(
                        icon: Icons.notes_outlined,
                        label: 'Description',
                        value: (company.description ?? '').trim().isEmpty
                            ? 'No description'
                            : company.description!.trim(),
                      ),
                    ],
            ),
            SizedBox(height: AppSpacing.base),

            // ── Financial Summary ────────────────────────────
            _FundSummaryCard(
              totalAmountBilled: controller.totalAmountBilled,
              totalAmountReceived: controller.totalAmountReceived,
              totalAmountCompanyAddedExpenses:
                  controller.totalAmountCompanyAddedExpenses,
              totalAmountMainBalanceExpenses:
                  controller.totalAmountMainBalanceExpenses,
              totalAmountDue: controller.totalAmountDue,
            ),
            SizedBox(height: AppSpacing.base),

            // ── Statement Actions ────────────────────────────
            //_StatementActionsCard(controller: controller),
            SizedBox(height: AppSpacing.base),

            // ── Trips ────────────────────────────────────────
            _SectionCard(
              icon: Icons.route_outlined,
              title: 'Trips (${controller.trips.length})',
              children: controller.trips.isEmpty
                  ? [
                      _EmptyItem(
                        icon: Icons.route_outlined,
                        message: 'No trips for this company yet.',
                      ),
                    ]
                  : [
                      SizedBox(
                        height: _listViewportHeight(
                          listLength: controller.visibleTrips.length,
                          itemHeight: 96.h,
                        ),
                        child: Scrollbar(
                          controller: controller.tripsScrollController,
                          thumbVisibility: controller.visibleTrips.length > 5,
                          child: ListView.builder(
                            controller: controller.tripsScrollController,
                            itemCount: controller.visibleTrips.length,
                            itemBuilder: (context, index) {
                              final trip = controller.visibleTrips[index];
                              return _TripTile(
                                trip: trip,
                                onTap: () => controller.openTripDetails(trip),
                              );
                            },
                          ),
                        ),
                      ),
                      if (controller.isLoadingMoreTrips) ...[
                        SizedBox(height: AppSpacing.sm),
                        const Center(child: CircularProgressIndicator()),
                      ],
                    ],
            ),
            SizedBox(height: AppSpacing.base),

            // ── Transactions ─────────────────────────────────
            _SectionCard(
              icon: Icons.receipt_long_outlined,
              title: 'Transactions (${controller.transactions.length})',
              children: controller.transactions.isEmpty
                  ? [
                      _EmptyItem(
                        icon: Icons.receipt_long_outlined,
                        message:
                            'No transactions received from this company yet.',
                      ),
                    ]
                  : [
                      SizedBox(
                        height: _listViewportHeight(
                          listLength: controller.visibleTransactions.length,
                          itemHeight: 112.h,
                        ),
                        child: Scrollbar(
                          controller: controller.transactionsScrollController,
                          thumbVisibility:
                              controller.visibleTransactions.length > 5,
                          child: ListView.builder(
                            controller: controller.transactionsScrollController,
                            itemCount: controller.visibleTransactions.length,
                            itemBuilder: (context, index) {
                              final transaction =
                                  controller.visibleTransactions[index];
                              return _TransactionTile(
                                transaction: transaction,
                                onTap: () => controller.openTransactionDetails(
                                  transaction,
                                ),
                                onDelete: () =>
                                    controller.onDeleteTransactionPressed(
                                      context,
                                      transaction,
                                    ),
                              );
                            },
                          ),
                        ),
                      ),
                      if (controller.isLoadingMoreTransactions) ...[
                        SizedBox(height: AppSpacing.sm),
                        const Center(child: CircularProgressIndicator()),
                      ],
                    ],
            ),
            SizedBox(height: AppSpacing.base),
            _StatementActionsCard(controller: controller),
            SizedBox(height: AppSpacing.massive),
          ],
        );
      }),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATEMENT ACTIONS CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _StatementActionsCard extends StatelessWidget {
  const _StatementActionsCard({required this.controller});

  final CompanyDetailsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final canGenerate =
          controller.company != null &&
          !controller.isLoading &&
          !controller.isSaving.value &&
          !controller.isDeleting.value;

      final totalRecords =
          controller.trips.length + controller.transactions.length;
      final expenseCount = controller.transactions
          .where(
            (item) => item.transactionType.trim().toLowerCase() == 'expenses',
          )
          .length;
      final paymentCount = controller.transactions
          .where(
            (item) => item.transactionType.trim().toLowerCase() == 'payment',
          )
          .length;
      final tripTransactionCount = controller.transactions
          .where((item) => item.transactionType.trim().toLowerCase() == 'trips')
          .length;

      return Container(
        padding: EdgeInsets.all(18.w),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.lg,
          boxShadow: AppShadows.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36.w,
                  height: 36.w,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: AppRadius.sm,
                  ),
                  child: Icon(
                    Icons.picture_as_pdf_rounded,
                    size: 18.sp,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Statement PDF', style: AppTextStyles.headlineSmall),
                      SizedBox(height: 2.h),
                      Text(
                        'Generate a company statement for selected months or a custom date range.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.neutral500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                _InfoChip(
                  icon: Icons.route_rounded,
                  label: '${controller.trips.length} trips',
                ),
                _InfoChip(
                  icon: Icons.payments_rounded,
                  label: '$paymentCount payments',
                ),
                _InfoChip(
                  icon: Icons.receipt_rounded,
                  label: '$expenseCount expenses',
                ),
                _InfoChip(
                  icon: Icons.alt_route_rounded,
                  label: '$tripTransactionCount trip txns',
                ),
                _InfoChip(
                  icon: Icons.dataset_rounded,
                  label: '$totalRecords records',
                ),
              ],
            ),
            SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: AppRadius.md,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active Filter: ${controller.statementFilterLabel}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showStatementFilterSheet(context),
                          icon: const Icon(Icons.filter_alt_outlined),
                          label: const Text('Set Time Filter'),
                        ),
                      ),
                      if (controller.statementFilterType.value !=
                          StatementTimeFilterType.all) ...[
                        SizedBox(width: 8.w),
                        TextButton(
                          onPressed: controller.clearStatementFilter,
                          child: const Text('Clear'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                text: 'Generate & Save PDF',
                icon: Icons.download_rounded,
                onPressed: canGenerate
                    ? controller.onGenerateStatementPressed
                    : null,
              ),
            ),
            if (!canGenerate) ...[
              SizedBox(height: AppSpacing.sm),
              Text(
                controller.isLoading
                    ? 'Please wait while company data is loading.'
                    : 'Statement actions are temporarily unavailable.',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.neutral500,
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  Future<void> _showStatementFilterSheet(BuildContext context) async {
    var tempType = controller.statementFilterType.value;
    var tempSelectedMonth = controller.statementSelectedMonth.value;
    var tempRangeStart = controller.statementRangeStart.value;
    var tempRangeEnd = controller.statementRangeEnd.value;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 20.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Statement Time Filter',
                      style: AppTextStyles.headlineSmall,
                    ),
                    SizedBox(height: AppSpacing.sm),
                    RadioListTile<StatementTimeFilterType>(
                      value: StatementTimeFilterType.all,
                      groupValue: tempType,
                      title: const Text('All Time'),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => tempType = value);
                      },
                    ),
                    RadioListTile<StatementTimeFilterType>(
                      value: StatementTimeFilterType.selectedMonth,
                      groupValue: tempType,
                      title: const Text('Selected Month'),
                      subtitle: const Text('Pick a single month and year'),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => tempType = value);
                      },
                    ),
                    if (tempType == StatementTimeFilterType.selectedMonth)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () async {
                            final picked = await _pickMonth(
                              context,
                              initialDate: tempSelectedMonth ?? DateTime.now(),
                            );
                            if (picked == null) return;
                            setState(() => tempSelectedMonth = picked);
                          },
                          child: Text(
                            tempSelectedMonth == null
                                ? 'Select Month'
                                : DateFormat(
                                    'MMM yyyy',
                                  ).format(tempSelectedMonth!),
                          ),
                        ),
                      ),
                    RadioListTile<StatementTimeFilterType>(
                      value: StatementTimeFilterType.dateRange,
                      groupValue: tempType,
                      title: const Text('Custom Date Range'),
                      subtitle: const Text(
                        'Pick start and end date across wider years',
                      ),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => tempType = value);
                      },
                    ),
                    if (tempType == StatementTimeFilterType.dateRange)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () async {
                            final initialRange =
                                (tempRangeStart != null && tempRangeEnd != null)
                                ? DateTimeRange(
                                    start: tempRangeStart!,
                                    end: tempRangeEnd!,
                                  )
                                : null;

                            final picked = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(1990, 1, 1),
                              lastDate: DateTime(2100, 12, 31),
                              initialDateRange: initialRange,
                              builder: (context, child) {
                                if (child == null) {
                                  return const SizedBox.shrink();
                                }

                                return Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 980,
                                      maxHeight: 820,
                                    ),
                                    child: child,
                                  ),
                                );
                              },
                            );

                            if (picked == null) return;
                            setState(() {
                              tempRangeStart = DateTime(
                                picked.start.year,
                                picked.start.month,
                                picked.start.day,
                              );
                              tempRangeEnd = DateTime(
                                picked.end.year,
                                picked.end.month,
                                picked.end.day,
                              );
                            });
                          },
                          child: Text(
                            (tempRangeStart == null || tempRangeEnd == null)
                                ? 'Pick Date Range'
                                : '${DateFormat('dd MMM yyyy').format(tempRangeStart!)} - ${DateFormat('dd MMM yyyy').format(tempRangeEnd!)}',
                          ),
                        ),
                      ),
                    SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: AppButton(
                            text: 'Apply',
                            onPressed: () {
                              if (tempType == StatementTimeFilterType.all) {
                                controller.clearStatementFilter();
                                Navigator.of(sheetContext).pop();
                                return;
                              }

                              if (tempType ==
                                  StatementTimeFilterType.selectedMonth) {
                                if (tempSelectedMonth == null) {
                                  Get.snackbar(
                                    'Missing month',
                                    'Please select a month.',
                                  );
                                  return;
                                }
                                controller.setStatementSelectedMonth(
                                  tempSelectedMonth!,
                                );
                                Navigator.of(sheetContext).pop();
                                return;
                              }

                              if (tempRangeStart == null ||
                                  tempRangeEnd == null) {
                                Get.snackbar(
                                  'Missing range',
                                  'Please select a valid date range.',
                                );
                                return;
                              }

                              controller.setStatementDateRange(
                                DateTimeRange(
                                  start: tempRangeStart!,
                                  end: tempRangeEnd!,
                                ),
                              );
                              Navigator.of(sheetContext).pop();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<DateTime?> _pickMonth(
    BuildContext context, {
    required DateTime initialDate,
  }) async {
    final now = DateTime.now();
    var selectedYear = initialDate.year;
    if (selectedYear < 1990) selectedYear = 1990;
    if (selectedYear > 2100) selectedYear = 2100;

    const monthLabels = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select Month'),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<int>(
                      value: selectedYear,
                      decoration: const InputDecoration(labelText: 'Year'),
                      items: [
                        for (int year = 1990; year <= 2100; year++)
                          DropdownMenuItem<int>(
                            value: year,
                            child: Text(year.toString()),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => selectedYear = value);
                      },
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: [
                        for (int i = 0; i < monthLabels.length; i++)
                          SizedBox(
                            width: 98,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.of(
                                  dialogContext,
                                ).pop(DateTime(selectedYear, i + 1, 1));
                              },
                              child: Text(
                                monthLabels[i],
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tip: tap a month to apply it for $selectedYear.',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.neutral500,
                      ),
                    ),
                    if (selectedYear == now.year) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Current year selected.',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.neutral400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: AppColors.neutral50,
        borderRadius: AppRadius.full,
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: AppColors.primary),
          SizedBox(width: 6.w),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FUND SUMMARY — Gradient financial overview
// ═══════════════════════════════════════════════════════════════════════════════

class _FundSummaryCard extends StatelessWidget {
  const _FundSummaryCard({
    required this.totalAmountBilled,
    required this.totalAmountReceived,
    required this.totalAmountCompanyAddedExpenses,
    required this.totalAmountMainBalanceExpenses,
    required this.totalAmountDue,
  });

  final double totalAmountBilled;
  final double totalAmountReceived;
  final double totalAmountCompanyAddedExpenses;
  final double totalAmountMainBalanceExpenses;
  final double totalAmountDue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: AppRadius.lg,
        boxShadow: AppShadows.primaryGlow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32.w,
                height: 32.w,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: AppRadius.sm,
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 16.sp,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Text(
                'Fund Summary',
                style: AppTextStyles.labelMedium.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.base),
          Column(
            children: [
              _HighlightItem(
                label: 'Total Billed',
                value: '৳ ${_formatAmount(totalAmountBilled)}',
              ),
              SizedBox(height: AppSpacing.sm),
              _HighlightItem(
                label: 'Received',
                value: '৳ ${_formatAmount(totalAmountReceived)}',
              ),
              SizedBox(height: AppSpacing.sm),
              _HighlightItem(
                label: 'Expenses (Deducted From Due)',
                value: '৳ ${_formatAmount(totalAmountCompanyAddedExpenses)}',
              ),
              SizedBox(height: AppSpacing.sm),
              _HighlightItem(
                label: 'Due (Total)',
                value: '৳ ${_formatAmount(totalAmountDue)}',
              ),
              SizedBox(height: AppSpacing.sm),
              // _HighlightItem(
              //   label: 'Expenses (Main Balance)',
              //   value: '৳ ${_formatAmount(totalAmountMainBalanceExpenses)}',
              // ),
              // SizedBox(height: AppSpacing.sm),

              // Text(
              //   'Main balance expenses are shown for fund tracking only and are not included in Due.',
              //   style: AppTextStyles.caption.copyWith(
              //     color: Colors.white.withValues(alpha: 0.7),
              //     fontWeight: FontWeight.w500,
              //   ),
              // ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HighlightItem extends StatelessWidget {
  const _HighlightItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 10.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: AppRadius.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                value,
                style: AppTextStyles.labelMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children, this.icon});

  final String title;
  final List<Widget> children;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg,
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 32.w,
                  height: 32.w,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: AppRadius.sm,
                  ),
                  child: Icon(icon, size: 16.sp, color: AppColors.primary),
                ),
                SizedBox(width: AppSpacing.sm),
              ],
              Expanded(child: Text(title, style: AppTextStyles.headlineSmall)),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DETAIL ROW
// ═══════════════════════════════════════════════════════════════════════════════

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 7.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28.w,
            height: 28.w,
            decoration: BoxDecoration(
              color: AppColors.neutral100,
              borderRadius: AppRadius.sm,
            ),
            child: Icon(icon, size: 14.sp, color: AppColors.neutral500),
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.neutral500,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: valueColor ?? AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TRIP TILE
// ═══════════════════════════════════════════════════════════════════════════════

class _TripTile extends StatelessWidget {
  const _TripTile({required this.trip, required this.onTap});

  final TripModel trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.md,
        child: Container(
          margin: EdgeInsets.only(bottom: 10.h),
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: AppColors.neutral50,
            borderRadius: AppRadius.md,
            border: Border.all(color: AppColors.neutral200),
          ),
          child: Row(
            children: [
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: AppRadius.sm,
                ),
                child: Icon(
                  Icons.route_rounded,
                  size: 20.sp,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_safeText(trip.from)} → ${_safeText(trip.to)}',
                      style: AppTextStyles.labelMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 11.sp,
                          color: AppColors.neutral400,
                        ),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: Text(
                            _safeText(trip.date),
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.neutral500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.successLight,
                            borderRadius: AppRadius.full,
                          ),
                          child: Text(
                            'Bill: ৳ ${_formatAmount(_toDouble(trip.totalBill))}',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                              fontSize: 10.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 4.w),
              Icon(
                Icons.chevron_right_rounded,
                size: 20.sp,
                color: AppColors.neutral300,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TRANSACTION TILE
// ═══════════════════════════════════════════════════════════════════════════════

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.onTap,
    this.onDelete,
  });

  final TransactionModel transaction;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.isExpense;
    final transactionTypeLabel = transaction.transactionTypeLabel;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.md,
        child: Container(
          margin: EdgeInsets.only(bottom: 10.h),
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: AppColors.neutral50,
            borderRadius: AppRadius.md,
            border: Border.all(color: AppColors.neutral200),
          ),
          child: Row(
            children: [
              Container(
                width: 35.w,
                height: 35.w,
                decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: AppRadius.sm,
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  size: 16.sp,
                  color: AppColors.accent,
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.paymentMethodLabel,
                      style: AppTextStyles.labelMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 11.sp,
                          color: AppColors.neutral400,
                        ),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: Text(
                            _safeText(transaction.date),
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.neutral500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Wrap(
                      spacing: 6.w,
                      runSpacing: 4.h,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: isExpense
                                ? AppColors.warningLight
                                : AppColors.successLight,
                            borderRadius: AppRadius.full,
                          ),
                          child: Text(
                            transactionTypeLabel,
                            style: AppTextStyles.caption.copyWith(
                              color: isExpense
                                  ? AppColors.warning
                                  : AppColors.success,
                              fontWeight: FontWeight.w600,
                              fontSize: 10.sp,
                            ),
                          ),
                        ),
                        if (isExpense)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.infoLight,
                              borderRadius: AppRadius.full,
                            ),
                            child: Text(
                              transaction.expenseSourceLabel,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.info,
                                fontWeight: FontWeight.w600,
                                fontSize: 10.sp,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onDelete != null)
                    IconButton(
                      tooltip: 'Delete transaction',
                      visualDensity: VisualDensity.compact,
                      onPressed: onDelete,
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.error,
                      ),
                    ),
                  Text(
                    '৳ ${_formatAmount(_toDouble(transaction.amount))}',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.sp,
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20.sp,
                    color: AppColors.neutral300,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// EMPTY & ERROR STATES
// ═══════════════════════════════════════════════════════════════════════════════

class _EmptyItem extends StatelessWidget {
  const _EmptyItem({required this.message, this.icon});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 20.h),
      child: Column(
        children: [
          if (icon != null)
            Icon(icon, size: 28.sp, color: AppColors.neutral300),
          if (icon != null) SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.neutral400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _InvalidCompanyState extends StatelessWidget {
  const _InvalidCompanyState({required this.onBackPressed});

  final VoidCallback onBackPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64.w,
              height: 64.w,
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: AppRadius.full,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 32.sp,
              ),
            ),
            SizedBox(height: AppSpacing.base),
            Text('Company not found', style: AppTextStyles.headlineSmall),
            SizedBox(height: AppSpacing.xs),
            Text(
              'Unable to load this company\'s details.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.neutral500,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.lg),
            AppButton(
              text: 'Go Back',
              icon: Icons.arrow_back_rounded,
              onPressed: onBackPressed,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

String _safeText(String value) {
  final text = value.trim();
  return text.isEmpty ? 'N/A' : text;
}

double _toDouble(String value) {
  final sanitized = value.replaceAll(',', '').trim();
  return double.tryParse(sanitized) ?? 0;
}

String _formatAmount(double value) {
  return value.toInt().toString();
}

double _listViewportHeight({
  required int listLength,
  required double itemHeight,
}) {
  if (listLength <= 0) return itemHeight;
  final visibleItems = listLength < 5 ? listLength : 5;
  return itemHeight * visibleItems;
}
