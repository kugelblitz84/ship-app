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
      subtitle: 'Review payment and expense records',
      icon: Icons.receipt_long_rounded,
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
                        onTap: () => Get.toNamed(
                          AppRoutes.transactionDetails,
                          arguments: transaction,
                        ),
                      ),
                    ),
                  )
                  .toList(),
          ],
        );
      }),
      onRefresh: controller.onRefresh,
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
                child: AppTextField(
                  controller: controller.searchController,
                  hint: 'Search company, route, amount, type',
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
    final totalAmount = transactions.fold<double>(
      0,
      (sum, transaction) => sum + _toDouble(transaction.amount),
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
          ),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.transaction, this.onTap});

  final TransactionModel transaction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final amount = _toDouble(transaction.amount);
    final companyName = transaction.companyName.trim().isEmpty
        ? 'Unknown company'
        : transaction.companyName;
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
            color: AppColors.surface,
            borderRadius: AppRadius.lg,
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
                          transaction.routeLabel,
                          style: AppTextStyles.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    '৳ ${_formatAmount(amount)}',
                    style: AppTextStyles.headlineMedium.copyWith(
                      color: AppColors.primary,
                    ),
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
                  ),
                  if (transaction.isExpense)
                    _MetaChip(
                      icon: Icons.source_outlined,
                      label: transaction.expenseSourceLabel,
                    ),
                  _MetaChip(
                    icon: Icons.calendar_today_outlined,
                    label: dateLabel,
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
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: AppRadius.md,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15.sp, color: AppColors.primary),
          SizedBox(width: 6.w),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary),
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
  if (value % 1 == 0) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(2);
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
