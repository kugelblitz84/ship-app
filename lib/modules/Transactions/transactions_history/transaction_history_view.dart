import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../core/themes/themes.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routes/app_routes.dart';
import '../models/transaction_model.dart';
import 'transaction_history_controller.dart';
import 'transaction_history_filter_dialogue.dart';

class TransactionHistoryView extends GetView<TransactionHistoryController> {
  const TransactionHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSliverScaffold(
      title: 'Transaction History',
      subtitle: 'Review payment, expense, and trip records',
      icon: Icons.receipt_long_rounded,
      maxContentWidth: 1120,
      actions: [
        Obx(
          () => controller.visibleTransactions.isNotEmpty
              ? IconButton(
                  tooltip: 'Export filtered ledger PDF',
                  icon: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: AppColors.errorLight,
                    size: 25,
                  ),
                  onPressed: controller.exportFilteredLedgerPdf,
                )
              : const SizedBox.shrink(),
        ),
        Obx(
          () => controller.hasActiveFilters
              ? IconButton(
                  tooltip: 'Clear filters',
                  icon: const Icon(
                    Icons.filter_alt_off_rounded,
                    color: AppColors.successLight,
                    size: 25,
                  ),
                  onPressed: controller.clearAllFilters,
                )
              : const SizedBox.shrink(),
        ),
      ],
      scrollController: controller.scrollController,
      onRefresh: controller.onRefresh,
      child: Obx(() {
        final transactions = controller.transactions;
        final visibleTransactions = controller.visibleTransactions;

        if (controller.isLoading && transactions.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SummaryCard(transactions: transactions),
            SizedBox(height: AppSpacing.lg),
            _TransactionSearchSortFilterBar(controller: controller),
            SizedBox(height: AppSpacing.lg),
            if (visibleTransactions.isEmpty && transactions.isNotEmpty)
              _NoFilterResultState(onClear: controller.clearAllFilters)
            else if (transactions.isEmpty)
              const _EmptyState()
            else
              ...visibleTransactions
                  .map(
                    (transaction) => Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.base),
                      child: _TransactionCard(
                        transaction: transaction,
                        shipName: controller.resolvedShipName(transaction),
                        onTap: () =>
                            controller.openTransactionDetails(transaction),
                        onDelete: () => controller.onDeleteTransactionPressed(
                          context,
                          transaction,
                        ),
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
    );
  }
}

class _TransactionSearchSortFilterBar extends StatelessWidget {
  const _TransactionSearchSortFilterBar({required this.controller});

  final TransactionHistoryController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF6F8FF), Color(0xFFFFF8F1)],
        ),
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.neutral200),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: controller.searchController,
                  hint: 'Search company, payment method, amount, type',
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
                        builder: (_) => TransactionHistoryFilterDialog(
                          controller: controller,
                        ),
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
          DropdownButtonFormField<TransactionSortOption>(
            value: controller.sortOption.value,
            decoration: const InputDecoration(
              labelText: 'Sort by',
              prefixIcon: Icon(Icons.sort_rounded),
            ),
            borderRadius: AppRadius.md,
            items: TransactionSortOption.values
                .map(
                  (option) => DropdownMenuItem<TransactionSortOption>(
                    value: option,
                    child: Text(_sortLabel(option)),
                  ),
                )
                .toList(),
            onChanged: controller.onSortChanged,
          ),
          SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              FilterChip(
                selected: controller.showExpensesOnly.value,
                showCheckmark: false,
                backgroundColor: AppColors.surface,
                selectedColor: const Color(0xFFFBE4E4),
                side: BorderSide(
                  color: controller.showExpensesOnly.value
                      ? AppColors.error.withValues(alpha: 0.45)
                      : AppColors.neutral300,
                ),
                label: Text(
                  'Only expenses',
                  style: AppTextStyles.labelSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: controller.showExpensesOnly.value
                        ? AppColors.error
                        : AppColors.neutral700,
                  ),
                ),
                avatar: Icon(
                  controller.showExpensesOnly.value
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 16.sp,
                  color: controller.showExpensesOnly.value
                      ? AppColors.error
                      : AppColors.neutral500,
                ),
                onSelected: controller.setShowExpensesOnly,
              ),
              if (controller.showExpensesOnly.value)
                FilterChip(
                  selected: controller.includeAddedToDueExpenses.value,
                  showCheckmark: false,
                  backgroundColor: AppColors.surface,
                  selectedColor: const Color(0xFFF9E9D8),
                  side: BorderSide(
                    color: controller.includeAddedToDueExpenses.value
                        ? AppColors.accent.withValues(alpha: 0.45)
                        : AppColors.neutral300,
                  ),
                  label: Text(
                    'Company Due',
                    style: AppTextStyles.labelSmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: controller.includeAddedToDueExpenses.value
                          ? AppColors.accentDark
                          : AppColors.neutral700,
                    ),
                  ),
                  avatar: Icon(
                    controller.includeAddedToDueExpenses.value
                        ? Icons.check_rounded
                        : Icons.add_rounded,
                    size: 16.sp,
                    color: controller.includeAddedToDueExpenses.value
                        ? AppColors.accentDark
                        : AppColors.neutral500,
                  ),
                  onSelected: controller.setIncludeAddedToDueExpenses,
                ),
              if (controller.showExpensesOnly.value)
                FilterChip(
                  selected: controller.includeMainBalanceExpenses.value,
                  showCheckmark: false,
                  backgroundColor: AppColors.surface,
                  selectedColor: const Color(0xFFE2EEFF),
                  side: BorderSide(
                    color: controller.includeMainBalanceExpenses.value
                        ? AppColors.info.withValues(alpha: 0.45)
                        : AppColors.neutral300,
                  ),
                  label: Text(
                    'Main Balance',
                    style: AppTextStyles.labelSmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: controller.includeMainBalanceExpenses.value
                          ? AppColors.info
                          : AppColors.neutral700,
                    ),
                  ),
                  avatar: Icon(
                    controller.includeMainBalanceExpenses.value
                        ? Icons.check_rounded
                        : Icons.account_balance_wallet_outlined,
                    size: 16.sp,
                    color: controller.includeMainBalanceExpenses.value
                        ? AppColors.info
                        : AppColors.neutral500,
                  ),
                  onSelected: controller.setIncludeMainBalanceExpenses,
                ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            '${controller.visibleTransactions.length} result${controller.visibleTransactions.length == 1 ? '' : 's'}',
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
      width: double.infinity,
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
            color: AppColors.neutral500,
            size: 34.sp,
          ),
          SizedBox(height: AppSpacing.base),
          Text('No matching transactions', style: AppTextStyles.labelMedium),
          SizedBox(height: 4.h),
          Text(
            'Try a different keyword or clear the filters.',
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
  const _SummaryCard({required this.transactions});

  final List<TransactionModel> transactions;

  @override
  Widget build(BuildContext context) {
    final totalTransactions = transactions.length;
    final expenseCount = transactions.where((item) => item.isExpense).length;
    final paymentCount = transactions.where((item) => item.isPayment).length;
    final tripCount = transactions.where((item) => item.isTrip).length;
    final totalAmount = transactions.fold<double>(
      0,
      (sum, transaction) => sum + _toDouble(transaction.amount),
    );

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEEF1FF), Color(0xFFFFF4E8)],
        ),
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.neutral200),
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
                  Icons.account_balance_wallet_outlined,
                  color: AppColors.primary,
                  size: 22.sp,
                ),
              ),
              SizedBox(width: AppSpacing.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Transactions', style: AppTextStyles.bodyMedium),
                    SizedBox(height: 2.h),
                    Text(
                      '$totalTransactions',
                      style: AppTextStyles.headlineSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.base),
          _MetaChip(
            icon: Icons.paid_outlined,
            label: 'Total Amount: ৳ ${_formatAmount(totalAmount)}',
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _MetaChip(
                icon: Icons.arrow_upward_rounded,
                label: '$paymentCount Payments',
                color: AppColors.success,
                backgroundColor: AppColors.successLight,
              ),
              _MetaChip(
                icon: Icons.arrow_downward_rounded,
                label: '$expenseCount Expenses',
                color: AppColors.error,
                backgroundColor: AppColors.errorLight,
              ),
              _MetaChip(
                icon: Icons.route_rounded,
                label: '$tripCount Trips',
                color: AppColors.info,
                backgroundColor: AppColors.infoLight,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.transaction,
    required this.shipName,
    this.onTap,
    this.onDelete,
  });

  final TransactionModel transaction;
  final String shipName;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final amount = _toDouble(transaction.amount);
    final isExpense = transaction.isExpense;
    final isTrip = transaction.isTrip;
    final companyName = transaction.companyName.trim().isEmpty
        ? 'N/A'
        : transaction.companyName;
    final resolvedShipName = shipName.trim();
    final dateLabel = transaction.date.trim().isEmpty ? '--' : transaction.date;
    final transactionTypeLabel = transaction.transactionTypeLabel;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.lg,
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: isExpense
                ? const Color(0xFFFFFBF7)
                : isTrip
                ? const Color(0xFFF3FFF8)
                : const Color(0xFFF8FCFF),
            borderRadius: AppRadius.lg,
            border: Border.all(
              color: isExpense
                  ? AppColors.accent.withValues(alpha: 0.35)
                  : isTrip
                  ? AppColors.success.withValues(alpha: 0.30)
                  : AppColors.info.withValues(alpha: 0.30),
            ),
            boxShadow: AppShadows.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          companyName,
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          transaction.paymentMethodLabel,
                          style: AppTextStyles.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '৳ ${_formatAmount(amount)}',
                        style: AppTextStyles.headlineMedium.copyWith(
                          color: isExpense
                              ? AppColors.accentDark
                              : isTrip
                              ? AppColors.success
                              : AppColors.info,
                        ),
                      ),
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
                    ],
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: [
                  _MetaChip(
                    icon: Icons.category_outlined,
                    label: transactionTypeLabel,
                    color: isExpense
                        ? AppColors.accentDark
                        : isTrip
                        ? AppColors.success
                        : AppColors.info,
                    backgroundColor: isExpense
                        ? AppColors.accentLight
                        : isTrip
                        ? AppColors.successLight
                        : AppColors.infoLight,
                  ),
                  if (transaction.isExpense)
                    _MetaChip(
                      icon: Icons.source_outlined,
                      label: transaction.expenseSourceLabel,
                      color: AppColors.accentDark,
                      backgroundColor: AppColors.accentLight,
                    ),
                  _MetaChip(
                    icon: Icons.calendar_today_outlined,
                    label: dateLabel,
                    color: AppColors.neutral700,
                    backgroundColor: AppColors.neutral100,
                  ),
                  if (resolvedShipName.isNotEmpty)
                    _MetaChip(
                      icon: Icons.directions_boat_outlined,
                      label: resolvedShipName,
                      color: AppColors.neutral700,
                      backgroundColor: AppColors.neutral100,
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

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    this.color = AppColors.primary,
    this.backgroundColor = AppColors.primarySurface,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AppRadius.md,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15.sp, color: color),
          SizedBox(width: 6.w),
          Text(label, style: AppTextStyles.bodySmall.copyWith(color: color)),
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
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            color: AppColors.neutral500,
            size: 34.sp,
          ),
          SizedBox(height: AppSpacing.base),
          Text('No transactions found', style: AppTextStyles.labelMedium),
          SizedBox(height: 4.h),
          Text(
            'Add your first transaction to see it listed here.',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

double _toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  if (value is String) {
    final sanitized = value.replaceAll(',', '').trim();
    return double.tryParse(sanitized) ?? 0;
  }
  return 0;
}

String _formatAmount(double value) {
  return value.toInt().toString();
}

String _sortLabel(TransactionSortOption option) {
  switch (option) {
    case TransactionSortOption.newest:
      return 'Newest first';
    case TransactionSortOption.oldest:
      return 'Oldest first';
    case TransactionSortOption.amountHighToLow:
      return 'Amount high to low';
    case TransactionSortOption.amountLowToHigh:
      return 'Amount low to high';
    case TransactionSortOption.companyAZ:
      return 'Company A-Z';
    case TransactionSortOption.companyZA:
      return 'Company Z-A';
  }
}
