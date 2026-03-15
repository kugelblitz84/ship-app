import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../core/themes/themes.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/widgets.dart';
import 'cash_in_cash_out_controller.dart';
import 'models/cash_in_cash_out_model.dart';

class CashInCashOutView extends GetView<CashInCashOutController> {
  const CashInCashOutView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSliverScaffold(
      title: 'Cash In Cash Out',
      subtitle: 'Record main balance adjustments only',
      icon: Icons.account_balance_wallet_rounded,
      maxContentWidth: 980,
      onRefresh: controller.onRefresh,
      actions: [
        Obx(
          () => controller.entries.isNotEmpty
              ? IconButton(
                  tooltip: 'Export history PDF',
                  icon: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: AppColors.errorLight,
                    size: 25,
                  ),
                  onPressed: controller.exportHistory,
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
      child: Form(
        key: controller.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: AppSpacing.lg),
            _entryFormCard(context),
            SizedBox(height: AppSpacing.base),
            _summaryCard(),
            SizedBox(height: AppSpacing.base),
            _searchAndFilterBar(context),
            SizedBox(height: AppSpacing.lg),
            _historySection(),
            SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _entryFormCard(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg,
        boxShadow: AppShadows.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Entry Information', style: AppTextStyles.headlineSmall),
          SizedBox(height: 6.h),
          Text(
            'Add or withdraw amount to or from main balance',
            style: AppTextStyles.bodyMedium,
          ),
          SizedBox(height: AppSpacing.base),
          Obx(
            () => DropdownButtonFormField<String>(
              value: controller.selectedFlowType.value,
              decoration: const InputDecoration(
                labelText: 'Flow Type',
                prefixIcon: Icon(Icons.swap_vert_rounded),
              ),
              borderRadius: AppRadius.md,
              items: CashInCashOutController.flowTypes
                  .map(
                    (type) => DropdownMenuItem<String>(
                      value: type,
                      child: Text(
                        type == 'cash-out' ? 'Cash Out' : 'Cash In',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: controller.onFlowTypeChanged,
            ),
          ),
          SizedBox(height: AppSpacing.base),
          _transactionTypeDropdown(context),
          SizedBox(height: AppSpacing.base),
          AppTextField(
            controller: controller.amountController,
            label: 'Amount',
            hint: 'Enter amount',
            prefixIcon: Icons.currency_exchange_rounded,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            validator: controller.amountValidator,
          ),
          SizedBox(height: AppSpacing.base),
          AppTextField(
            controller: controller.dateController,
            label: 'Date',
            hint: 'YYYY-MM-DD',
            prefixIcon: Icons.calendar_today_rounded,
            textInputAction: TextInputAction.next,
            readOnly: true,
            validator: controller.dateValidator,
            suffix: IconButton(
              tooltip: 'Pick date',
              icon: const Icon(Icons.event_rounded),
              onPressed: () => controller.onPickDatePressed(context),
            ),
          ),
          SizedBox(height: AppSpacing.base),
          AppTextField(
            controller: controller.noteController,
            label: 'Description (Optional)',
            hint: 'Add a short description',
            prefixIcon: Icons.notes_rounded,
            textInputAction: TextInputAction.done,
            maxLines: 3,
          ),
          SizedBox(height: AppSpacing.base),
          Obx(
            () => AppButton(
              text: 'Save Entry',
              icon: Icons.save_rounded,
              onPressed: controller.onSavePressed,
              isLoading: controller.isSubmitting,
            ),
          ),
        ],
      ),
    );
  }

  Widget _transactionTypeDropdown(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Transaction Type', style: AppTextStyles.labelMedium),
            ),
            TextButton.icon(
              onPressed: () => _showAddTypeDialog(context),
              icon: Icon(
                Icons.add_rounded,
                size: 18.sp,
                color: AppColors.primary,
              ),
              label: Text(
                'Add',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => _showManageTypesDialog(context),
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 18.sp,
                color: AppColors.error,
              ),
              label: Text(
                'Delete',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.error,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Obx(() {
          final selectedType = controller.selectedTransactionType.value;
          final hasSelected = controller.transactionTypes.contains(
            selectedType,
          );
          return DropdownButtonFormField<String>(
            value: hasSelected ? selectedType : null,
            decoration: const InputDecoration(
              hintText: 'Select transaction type',
              prefixIcon: Icon(Icons.account_balance_wallet_outlined),
            ),
            borderRadius: AppRadius.md,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            items: controller.transactionTypes
                .map(
                  (type) => DropdownMenuItem<String>(
                    value: type,
                    child: Text(type, style: AppTextStyles.bodyMedium),
                  ),
                )
                .toList(),
            onChanged: controller.onTransactionTypeChanged,
            validator: controller.transactionTypeValidator,
          );
        }),
      ],
    );
  }

  Widget _summaryCard() {
    return Obx(
      () => Container(
        padding: EdgeInsets.all(18.w),
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          borderRadius: AppRadius.lg,
          border: Border.all(color: AppColors.neutral200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Main Balance Overview', style: AppTextStyles.labelMedium),
            SizedBox(height: AppSpacing.sm),
            Text(
              'From Transactions: ৳ ${controller.formatAmount(controller.transactionMainBalance)}',
              style: AppTextStyles.bodyMedium,
            ),
            SizedBox(height: 6.h),
            Text(
              'From Cash In/Out: ৳ ${controller.formatAmount(controller.cashFlowBalance)}',
              style: AppTextStyles.bodyMedium,
            ),
            SizedBox(height: 6.h),
            Text(
              'Combined Main Balance: ৳ ${controller.formatAmount(controller.combinedMainBalance)}',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchAndFilterBar(BuildContext context) {
    return Obx(
      () => Container(
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
                    hint: 'Search type, flow, note, amount, date',
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
                          builder: (_) =>
                              _CashFlowFilterDialog(controller: controller),
                        );
                      },
                    ),
                    if (controller.hasActiveFilters)
                      Positioned(
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
                      ),
                  ],
                ),
              ],
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              '${controller.filteredEntries.length} result${controller.filteredEntries.length == 1 ? '' : 's'}',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.neutral600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historySection() {
    return Obx(() {
      if (controller.isLoading && controller.entries.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      if (controller.entries.isEmpty) {
        return Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.lg,
            border: Border.all(color: AppColors.neutral200),
          ),
          child: Row(
            children: [
              Icon(
                Icons.history_rounded,
                color: AppColors.neutral400,
                size: 20.sp,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  'No cash in/cash out entries yet.',
                  style: AppTextStyles.bodyMedium,
                ),
              ),
            ],
          ),
        );
      }

      if (controller.filteredEntries.isEmpty) {
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
              Text('No matching entries', style: AppTextStyles.labelMedium),
              SizedBox(height: 4.h),
              Text(
                'Try another keyword or clear your filters.',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppSpacing.base),
              OutlinedButton.icon(
                onPressed: controller.clearAllFilters,
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Clear filters'),
              ),
            ],
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'History (${controller.filteredEntries.length})',
            style: AppTextStyles.headlineSmall,
          ),
          SizedBox(height: 10.h),
          SizedBox(
            height: _listViewportHeight(
              listLength: controller.visibleEntries.length,
              itemHeight: 106.h,
            ),
            child: Scrollbar(
              controller: controller.historyScrollController,
              thumbVisibility: controller.visibleEntries.length > 5,
              child: ListView.builder(
                controller: controller.historyScrollController,
                itemCount: controller.visibleEntries.length,
                itemBuilder: (context, index) {
                  final entry = controller.visibleEntries[index];
                  return _historyTile(context, entry);
                },
              ),
            ),
          ),
          if (controller.isLoadingMoreEntries && controller.hasMoreEntries)
            Padding(
              padding: EdgeInsets.only(top: AppSpacing.sm),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      );
    });
  }

  Widget _historyTile(BuildContext context, CashInCashOutModel entry) {
    final isOut = entry.isCashOut;
    final color = isOut ? AppColors.error : AppColors.success;

    return Container(
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
              color: isOut ? AppColors.errorLight : AppColors.successLight,
              borderRadius: AppRadius.sm,
            ),
            child: Icon(
              isOut ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              color: color,
              size: 16.sp,
            ),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.flowTypeLabel,
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
                        entry.date,
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
                        color: AppColors.infoLight,
                        borderRadius: AppRadius.full,
                      ),
                      child: Text(
                        entry.transactionTypeLabel,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.info,
                          fontWeight: FontWeight.w600,
                          fontSize: 10.sp,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: isOut
                            ? AppColors.errorLight
                            : AppColors.successLight,
                        borderRadius: AppRadius.full,
                      ),
                      child: Text(
                        isOut ? 'Main Balance -' : 'Main Balance +',
                        style: AppTextStyles.caption.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 10.sp,
                        ),
                      ),
                    ),
                  ],
                ),
                if ((entry.note ?? '').trim().isNotEmpty) ...[
                  SizedBox(height: 4.h),
                  Text(
                    entry.note!.trim(),
                    style: AppTextStyles.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Edit entry',
                visualDensity: VisualDensity.compact,
                onPressed: () => _showEditEntryDialog(Get.context!, entry),
                icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
              ),
              IconButton(
                tooltip: 'Delete entry',
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    controller.onDeleteEntryPressed(context, entry),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                ),
              ),
              Text(
                '৳ ${entry.signedAmountLabel}',
                style: AppTextStyles.labelMedium.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.sp,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showAddTypeDialog(BuildContext context) async {
    final TextEditingController typeController = TextEditingController();
    String? savedType;
    final dialogMaxWidth = MediaQuery.of(
      context,
    ).size.width.clamp(320.0, 560.0);

    await Get.dialog(
      AlertDialog(
        title: const Text('Add Transaction Type'),
        content: SizedBox(
          width: dialogMaxWidth,
          child: TextField(
            controller: typeController,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: 'e.g. office cash, bank transfer',
            ),
            onSubmitted: (_) async {
              final result = await controller.saveCashFlowTransactionType(
                typeController.text,
              );
              if (result == null) return;
              savedType = result;
              if (Get.isDialogOpen ?? false) Get.back();
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (Get.isDialogOpen ?? false) Get.back();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final result = await controller.saveCashFlowTransactionType(
                typeController.text,
              );
              if (result == null) return;
              savedType = result;
              if (Get.isDialogOpen ?? false) Get.back();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      typeController.dispose();
    });

    if (savedType != null) {
      controller.applyCashFlowTransactionType(savedType!);
      showAppSnackbar(
        'Type Added',
        'Cash flow transaction type added successfully.',
      );
    }
  }

  Future<void> _showManageTypesDialog(BuildContext context) async {
    final dialogMaxWidth = MediaQuery.of(
      context,
    ).size.width.clamp(320.0, 560.0);

    await Get.dialog(
      AlertDialog(
        title: const Text('Manage Transaction Types'),
        content: Obx(() {
          if (controller.transactionTypes.isEmpty) {
            return const Text('No transaction types found.');
          }

          return SizedBox(
            width: dialogMaxWidth,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: controller.transactionTypes.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final type = controller.transactionTypes[index];
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(type, style: AppTextStyles.bodyMedium),
                  trailing: IconButton(
                    tooltip: 'Delete type',
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error,
                    ),
                    onPressed: () async {
                      if (Get.isDialogOpen ?? false) Get.back();
                      await Future<void>.delayed(
                        const Duration(milliseconds: 120),
                      );
                      await controller.onDeleteCashFlowTransactionTypePressed(
                        context,
                        type,
                      );
                    },
                  ),
                );
              },
            ),
          );
        }),
        actions: [
          TextButton(
            onPressed: () {
              if (Get.isDialogOpen ?? false) Get.back();
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditEntryDialog(
    BuildContext context,
    CashInCashOutModel entry,
  ) async {
    final amountController = TextEditingController(text: entry.amount.trim());
    final noteController = TextEditingController(
      text: (entry.note ?? '').trim(),
    );
    String selectedFlowType = entry.flowType;
    String selectedType = entry.transactionType;
    final dialogMaxWidth = MediaQuery.of(
      context,
    ).size.width.clamp(320.0, 600.0);

    await Get.dialog(
      StatefulBuilder(
        builder: (dialogContext, setState) {
          final typeItems = controller.transactionTypes;
          if (!typeItems.contains(selectedType) && typeItems.isNotEmpty) {
            selectedType = typeItems.first;
          }

          return AlertDialog(
            title: const Text('Edit Cash In/Out Entry'),
            content: SizedBox(
              width: dialogMaxWidth,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedFlowType,
                      decoration: const InputDecoration(
                        labelText: 'Flow Type',
                        prefixIcon: Icon(Icons.swap_vert_rounded),
                      ),
                      borderRadius: AppRadius.md,
                      items: CashInCashOutController.flowTypes
                          .map(
                            (type) => DropdownMenuItem<String>(
                              value: type,
                              child: Text(
                                type == 'cash-out' ? 'Cash Out' : 'Cash In',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => selectedFlowType = value);
                      },
                    ),
                    SizedBox(height: AppSpacing.base),
                    DropdownButtonFormField<String>(
                      value: typeItems.contains(selectedType)
                          ? selectedType
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Transaction Type',
                        prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                      ),
                      borderRadius: AppRadius.md,
                      items: typeItems
                          .map(
                            (type) => DropdownMenuItem<String>(
                              value: type,
                              child: Text(type),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => selectedType = value);
                      },
                    ),
                    SizedBox(height: AppSpacing.base),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixIcon: Icon(Icons.currency_exchange_rounded),
                      ),
                    ),
                    SizedBox(height: AppSpacing.base),
                    TextField(
                      controller: noteController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: controller.isUpdatingEntry
                    ? null
                    : () {
                        if (Get.isDialogOpen ?? false) {
                          Get.back();
                        }
                      },
                child: const Text('Cancel'),
              ),
              Obx(
                () => TextButton(
                  onPressed: controller.isUpdatingEntry
                      ? null
                      : () async {
                          final saved = await controller.onEditEntrySavePressed(
                            entry: entry,
                            flowType: selectedFlowType,
                            transactionType: selectedType,
                            amount: amountController.text,
                            note: noteController.text,
                          );

                          if (!saved) return;
                          if (Get.isDialogOpen ?? false) {
                            Get.back();
                          }
                          showAppSnackbar(
                            'Entry Updated',
                            'Cash flow entry updated and balances recalculated.',
                          );
                        },
                  child: controller.isUpdatingEntry
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          );
        },
      ),
    );

    amountController.dispose();
    noteController.dispose();
  }
}

class _CashFlowFilterDialog extends StatelessWidget {
  const _CashFlowFilterDialog({required this.controller});

  final CashInCashOutController controller;

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
            final filterType = controller.selectedFilterType.value;
            final hasFilterType =
                filterType.isEmpty ||
                controller.availableFilterTypes.contains(filterType);

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
                  DropdownButtonFormField<String>(
                    value: hasFilterType ? filterType : '',
                    decoration: const InputDecoration(
                      labelText: 'Transaction Type',
                      prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                    ),
                    borderRadius: AppRadius.md,
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('All types'),
                      ),
                      ...controller.availableFilterTypes.map(
                        (type) => DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        ),
                      ),
                    ],
                    onChanged: controller.onFilterTypeChanged,
                  ),
                  SizedBox(height: AppSpacing.base),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              controller.onPickFilterStartDatePressed(context),
                          icon: const Icon(Icons.calendar_month_rounded),
                          label: Text(
                            'From: ${controller.formatFilterDate(controller.selectedStartDate.value)}',
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              controller.onPickFilterEndDatePressed(context),
                          icon: const Icon(Icons.event_available_rounded),
                          label: Text(
                            'To: ${controller.formatFilterDate(controller.selectedEndDate.value)}',
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.base),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            controller.clearAllFilters();
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.restart_alt_rounded),
                          label: const Text('Reset'),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.check_circle_outline_rounded),
                          label: const Text('Apply'),
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
}

double _listViewportHeight({
  required int listLength,
  required double itemHeight,
}) {
  if (listLength <= 0) return itemHeight;
  final visibleItems = listLength < 5 ? listLength : 5;
  return itemHeight * visibleItems;
}
