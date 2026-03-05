import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

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
                    : () => _showDeleteCompanyDialog(context),
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
              totalAmountExpenses: controller.totalAmountExpenses,
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
                  : controller.trips
                        .map(
                          (trip) => _TripTile(
                            trip: trip,
                            onTap: () => controller.openTripDetails(trip),
                          ),
                        )
                        .toList(),
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
                  : controller.transactions
                        .map(
                          (transaction) => _TransactionTile(
                            transaction: transaction,
                            onTap: () =>
                                controller.openTransactionDetails(transaction),
                          ),
                        )
                        .toList(),
            ),
            SizedBox(height: AppSpacing.base),
            _StatementActionsCard(controller: controller),
            SizedBox(height: AppSpacing.massive),
          ],
        );
      }),
      onRefresh: controller.onRefresh,
    );
  }

  Future<void> _showDeleteCompanyDialog(BuildContext context) async {
    final passwordController = TextEditingController();
    var isSubmitting = false;
    final dialogMaxWidth = Get.width.clamp(320.0, 560.0);

    final deleted = await Get.dialog<bool>(
      StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
            title: const Text('Delete Company'),
            content: SizedBox(
              width: dialogMaxWidth,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Enter your password to confirm deletion.'),
                    SizedBox(height: AppSpacing.base),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      enabled: !isSubmitting,
                      decoration: const InputDecoration(
                        hintText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline_rounded),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () {
                        if (Get.isDialogOpen ?? false) Get.back(result: false);
                      },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        setState(() => isSubmitting = true);
                        final isDeleted = await controller
                            .deleteCompanyWithPassword(passwordController.text);
                        if (!isDeleted) {
                          if (Get.isDialogOpen ?? false) {
                            setState(() => isSubmitting = false);
                          }
                          return;
                        }
                        if (Get.isDialogOpen ?? false) Get.back(result: true);
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Delete'),
              ),
            ],
          );
        },
      ),
    );

    passwordController.dispose();

    if (deleted == true) {
      Get.back(result: true);
    }
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
    final paymentCount = controller.transactions.length - expenseCount;

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
                      'Generate a date-grouped company statement with trips, payments, and expenses.',
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18.sp,
                  color: AppColors.primary,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'Preview lets you review the statement before saving. Quick save generates and downloads the PDF immediately.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: AppSpacing.md),

          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  text: 'Preview & Save Options',
                  icon: Icons.visibility_outlined,
                  onPressed: canGenerate
                      ? controller.onShowPreviewPressed
                      : null,
                ),
              ),
              SizedBox(height: AppSpacing.sm),
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
            ],
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
    required this.totalAmountExpenses,
    required this.totalAmountDue,
  });

  final double totalAmountBilled;
  final double totalAmountReceived;
  final double totalAmountExpenses;
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
                label: 'Expenses',
                value: '৳ ${_formatAmount(totalAmountExpenses)}',
              ),
              SizedBox(height: AppSpacing.sm),
              _HighlightItem(
                label: 'Due',
                value: '৳ ${_formatAmount(totalAmountDue)}',
              ),
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
  const _TransactionTile({required this.transaction, required this.onTap});

  final TransactionModel transaction;
  final VoidCallback onTap;

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
                      transaction.routeLabel,
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
  if (value >= 1e7) {
    return '${(value / 1e7).toStringAsFixed(2)} Cr';
  }
  if (value >= 1e5) {
    return '${(value / 1e5).toStringAsFixed(2)} L';
  }
  if (value % 1 == 0) {
    return value.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }
  return value
      .toStringAsFixed(2)
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
}
