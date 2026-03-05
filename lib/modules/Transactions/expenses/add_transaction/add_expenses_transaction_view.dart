import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../core/themes/themes.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../company/models/company_model.dart';
import '../../../ship/models/ship_model.dart';
import 'add_expenses_transaction_controller.dart';

class AddExpensesTransactionView
    extends GetView<AddExpensesTransactionController> {
  const AddExpensesTransactionView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSliverScaffold(
      title: 'Add Expense',
      subtitle: 'Record deductions from company due or main balance',
      icon: Icons.money_off_csred_outlined,
      maxContentWidth: 980,
      child: Form(
        key: controller.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // const GradientHeader(
            //   title: 'Record Expense',
            //   subtitle:
            //       'Choose expense source, select ship, then add amount and details.',
            //   icon: Icons.money_off_csred_outlined,
            //   height: 210,
            // ),
            SizedBox(height: AppSpacing.lg),
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.lg,
                boxShadow: AppShadows.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Transaction Information',
                    style: AppTextStyles.headlineSmall,
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Ship is required. Company is required only for company-based expenses.',
                    style: AppTextStyles.bodyMedium,
                  ),
                  SizedBox(height: AppSpacing.base),
                  Obx(
                    () => _expenseSourceDropdown(
                      selectedValue: controller.selectedExpenseSource.value,
                      onChanged: controller.onExpenseSourceChanged,
                      validator: controller.expenseSourceValidator,
                    ),
                  ),
                  SizedBox(height: AppSpacing.base),
                  Obx(
                    () => _companyDropdown(
                      companies: controller.companies,
                      selectedValue: controller.selectedCompanyName.value,
                      onChanged: controller.onCompanyChanged,
                      validator: controller.companyValidator,
                      isLoading: controller.isCompaniesLoading,
                    ),
                  ),
                  SizedBox(height: AppSpacing.base),
                  Obx(() => _sourceInfoCard(controller.isCompanySource)),
                  SizedBox(height: AppSpacing.base),
                  Obx(
                    () => _shipDropdown(
                      ships: controller.ships,
                      selectedValue: controller.selectedShipName.value,
                      onChanged: controller.onShipChanged,
                      validator: controller.shipValidator,
                      isLoading: controller.isShipsLoading,
                    ),
                  ),
                  SizedBox(height: AppSpacing.base),
                  Obx(
                    () => _transactionTypeDropdown(
                      selectedValue: controller.selectedType.value,
                      onChanged: controller.onTypeChanged,
                      validator: controller.typeValidator,
                      onAddMethodPressed: _showAddMethodDialog,
                      onDeleteMethodPressed: _showManageMethodsDialog,
                    ),
                  ),
                  SizedBox(height: AppSpacing.base),
                  AppTextField(
                    controller: controller.amountController,
                    label: 'Amount',
                    hint: '5000',
                    prefixIcon: Icons.currency_exchange_rounded,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                    validator: controller.amountValidator,
                  ),
                  SizedBox(height: AppSpacing.base),
                  _dateField(),
                  SizedBox(height: AppSpacing.base),
                  AppTextField(
                    controller: controller.descriptionController,
                    label: 'Description',
                    hint: 'Expense note (optional)',
                    prefixIcon: Icons.notes_rounded,
                    textInputAction: TextInputAction.done,
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            SizedBox(height: AppSpacing.base),
            _summaryCard(),
            SizedBox(height: AppSpacing.xxl),
            Obx(
              () => AppButton(
                text: 'Add Expense Transaction',
                icon: Icons.add_card_rounded,
                onPressed: controller.onAddTransactionPressed,
                isLoading: controller.isLoading,
              ),
            ),
            SizedBox(height: AppSpacing.base),
            AppButton(
              text: 'Cancel',
              icon: Icons.close_rounded,
              isOutlined: true,
              onPressed: () => Get.back(),
            ),
          ],
        ),
      ),
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
            Text(
              controller.isCompanySource
                  ? 'Company Balance Preview'
                  : 'Main Balance Preview',
              style: AppTextStyles.labelMedium,
            ),
            SizedBox(height: AppSpacing.sm),
            if (controller.isCompanySource) ...[
              Text(
                controller.currentReceivedDisplay.value == '--'
                    ? 'Company Received: --'
                    : 'Company Received (unchanged): ৳ ${controller.currentReceivedDisplay.value}',
                style: AppTextStyles.bodyMedium,
              ),
              SizedBox(height: 6.h),
              Text(
                controller.currentDueDisplay.value == '--'
                    ? 'Updated Company Due: --'
                    : 'Updated Company Due: ৳ ${controller.currentDueDisplay.value}',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ] else ...[
              Text(
                controller.currentMainBalanceDisplay.value == '--'
                    ? 'Current Main Balance: --'
                    : 'Current Main Balance: ৳ ${controller.currentMainBalanceDisplay.value}',
                style: AppTextStyles.bodyMedium,
              ),
              SizedBox(height: 6.h),
              Text(
                controller.updatedMainBalanceDisplay.value == '--'
                    ? 'Updated Main Balance: --'
                    : 'Updated Main Balance: ৳ ${controller.updatedMainBalanceDisplay.value}',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sourceInfoCard(bool isCompanySource) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.infoLight,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.info, size: 20.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              isCompanySource
                  ? 'Company Due selected. This expense will be added to the selected company due amount.'
                  : 'Main Balance selected. This expense will be deducted from lifetime total fund received.',
              style: AppTextStyles.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _companyDropdown({
    required List<CompanyModel> companies,
    required String? selectedValue,
    required ValueChanged<String?> onChanged,
    required FormFieldValidator<String> validator,
    required bool isLoading,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Company',
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 8.h),
        DropdownButtonFormField<String>(
          value: selectedValue,
          decoration: InputDecoration(
            hintText: isLoading ? 'Loading companies...' : 'Select company',
            prefixIcon: const Icon(Icons.business_outlined),
          ),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          borderRadius: AppRadius.md,
          items: companies
              .map<DropdownMenuItem<String>>(
                (company) => DropdownMenuItem<String>(
                  value: company.name,
                  child: Text(
                    company.name,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: isLoading ? null : onChanged,
          validator: validator,
        ),
      ],
    );
  }

  Widget _shipDropdown({
    required List<ShipModel> ships,
    required String? selectedValue,
    required ValueChanged<String?> onChanged,
    required FormFieldValidator<String> validator,
    required bool isLoading,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ship',
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 8.h),
        DropdownButtonFormField<String>(
          value: selectedValue,
          decoration: InputDecoration(
            hintText: isLoading ? 'Loading ships...' : 'Select ship',
            prefixIcon: const Icon(Icons.directions_boat_rounded),
          ),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          borderRadius: AppRadius.md,
          items: ships
              .map<DropdownMenuItem<String>>(
                (ship) => DropdownMenuItem<String>(
                  value: ship.name,
                  child: Text(
                    ship.name,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: isLoading ? null : onChanged,
          validator: validator,
        ),
      ],
    );
  }

  Widget _transactionTypeDropdown({
    required String? selectedValue,
    required ValueChanged<String?> onChanged,
    required FormFieldValidator<String> validator,
    required VoidCallback onAddMethodPressed,
    VoidCallback? onDeleteMethodPressed,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Transaction Type',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onAddMethodPressed,
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
              onPressed: onDeleteMethodPressed,
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
        Obx(
          () => DropdownButtonFormField<String>(
            value: selectedValue,
            decoration: const InputDecoration(
              hintText: 'Select payment type',
              prefixIcon: Icon(Icons.account_balance_wallet_outlined),
            ),
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            borderRadius: AppRadius.md,
            items: controller.transactionTypes
                .map(
                  (type) => DropdownMenuItem<String>(
                    value: type,
                    child: Text(
                      type,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: onChanged,
            validator: validator,
          ),
        ),
      ],
    );
  }

  Future<void> _showAddMethodDialog() async {
    final TextEditingController methodController = TextEditingController();
    String? savedMethod;
    final dialogMaxWidth = Get.width.clamp(320.0, 560.0);

    await Get.dialog(
      AlertDialog(
        title: const Text('Add Transaction Method'),
        content: SizedBox(
          width: dialogMaxWidth,
          child: TextField(
            controller: methodController,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: 'e.g. cash, bank, mobile banking',
            ),
            onSubmitted: (_) async {
              final result = await controller.saveTransactionMethod(
                methodController.text,
              );
              if (result == null) return;
              savedMethod = result;
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
              final result = await controller.saveTransactionMethod(
                methodController.text,
              );
              if (result == null) return;
              savedMethod = result;
              if (Get.isDialogOpen ?? false) Get.back();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    methodController.dispose();

    // Update reactive state only after dialog is fully removed from tree.
    if (savedMethod != null) {
      controller.applyTransactionMethod(savedMethod!);
      Get.snackbar(
        'Method Added',
        'Expense method added successfully.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.successLight,
        colorText: AppColors.success,
        icon: const Icon(Icons.check_circle_rounded, color: AppColors.success),
      );
    }
  }

  Future<void> _showDeleteMethodPasswordDialog(String method) async {
    final passwordController = TextEditingController();
    var isSubmitting = false;
    final dialogMaxWidth = Get.width.clamp(320.0, 560.0);

    await Get.dialog(
      StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
            title: const Text('Delete Transaction Method'),
            content: SizedBox(
              width: dialogMaxWidth,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Enter your password to delete "$method".'),
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
                        if (Get.isDialogOpen ?? false) Get.back();
                      },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        setState(() => isSubmitting = true);
                        final isDeleted = await controller
                            .deleteTransactionMethodWithPassword(
                              method: method,
                              password: passwordController.text,
                            );
                        if (!isDeleted) {
                          if (Get.isDialogOpen ?? false) {
                            setState(() => isSubmitting = false);
                          }
                          return;
                        }
                        if (Get.isDialogOpen ?? false) Get.back();
                        Get.snackbar(
                          'Method Deleted',
                          'Transaction method deleted successfully.',
                          snackPosition: SnackPosition.TOP,
                          backgroundColor: AppColors.successLight,
                          colorText: AppColors.success,
                          icon: const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.success,
                          ),
                        );
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      passwordController.dispose();
    });
  }

  Future<void> _showManageMethodsDialog() async {
    final dialogMaxWidth = Get.width.clamp(320.0, 560.0);

    await Get.dialog(
      AlertDialog(
        title: const Text('Manage Transaction Methods'),
        content: Obx(() {
          if (controller.transactionTypes.isEmpty) {
            return const Text('No transaction methods found.');
          }

          return SizedBox(
            width: dialogMaxWidth,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: controller.transactionTypes.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final method = controller.transactionTypes[index];
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(method, style: AppTextStyles.bodyMedium),
                  trailing: IconButton(
                    tooltip: 'Delete method',
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error,
                    ),
                    onPressed: () async {
                      if (Get.isDialogOpen ?? false) Get.back();
                      await Future<void>.delayed(
                        const Duration(milliseconds: 120),
                      );
                      await _showDeleteMethodPasswordDialog(method);
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

  Widget _expenseSourceDropdown({
    required String? selectedValue,
    required ValueChanged<String?> onChanged,
    required FormFieldValidator<String> validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Deduct From',
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 8.h),
        DropdownButtonFormField<String>(
          value: selectedValue,
          decoration: const InputDecoration(
            hintText: 'Select source',
            prefixIcon: Icon(Icons.account_balance_wallet_outlined),
          ),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          borderRadius: AppRadius.md,
          items: const [
            DropdownMenuItem<String>(
              value: 'company',
              child: Text('Company Due'),
            ),
            DropdownMenuItem<String>(
              value: 'main-balance',
              child: Text('Main Balance'),
            ),
          ],
          onChanged: onChanged,
          validator: validator,
        ),
      ],
    );
  }

  Widget _dateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date',
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          controller: controller.dateController,
          readOnly: true,
          onTap: () => controller.onPickDatePressed(Get.context!),
          validator: controller.requiredValidator('Date'),
          decoration: InputDecoration(
            hintText: 'YYYY-MM-DD',
            prefixIcon: const Icon(Icons.calendar_today_outlined),
            suffixIcon: const Icon(Icons.edit_calendar_outlined),
          ),
        ),
      ],
    );
  }
}
