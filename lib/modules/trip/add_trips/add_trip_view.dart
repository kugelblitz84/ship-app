import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../core/themes/themes.dart';
import '../../../core/widgets/widgets.dart';
import '../../company/models/company_model.dart';
import '../../ship/models/ship_model.dart';
import 'add_trip_controller.dart';

class AddTripView extends GetView<AddTripController> {
  const AddTripView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSliverScaffold(
      title: 'Add Trip',
      subtitle: 'Create a route with company and ship',
      icon: Icons.route_rounded,
      maxContentWidth: 980,
      child: Form(
        key: controller.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const GradientHeader(
              title: 'Create Trip Record',
              subtitle: 'Choose a company and ship, then enter route details.',
              icon: Icons.route_rounded,
              height: 210,
            ),
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
                  Text('Trip Information', style: AppTextStyles.headlineSmall),
                  SizedBox(height: 6.h),
                  Text(
                    'Trips are the only place where companies and ships are connected.',
                    style: AppTextStyles.bodyMedium,
                  ),
                  SizedBox(height: AppSpacing.base),
                  Obx(
                    () => _companyDropdown(
                      context,
                      companies: controller.companies,
                      selectedValue: controller.selectedCompanyName.value,
                      onChanged: controller.onCompanyChanged,
                      validator: controller.companyValidator,
                      isLoading: controller.isCompaniesLoading,
                    ),
                  ),
                  SizedBox(height: AppSpacing.base),
                  Obx(
                    () => _shipDropdown(
                      context,
                      ships: controller.ships,
                      selectedValue: controller.selectedShipName.value,
                      onChanged: controller.onShipChanged,
                      validator: controller.shipValidator,
                      isLoading: controller.isShipsLoading,
                    ),
                  ),
                  SizedBox(height: AppSpacing.base),
                  AppTextField(
                    controller: controller.fromController,
                    label: 'From',
                    hint: 'Port A',
                    prefixIcon: Icons.trip_origin_rounded,
                    textInputAction: TextInputAction.next,
                    validator: controller.requiredValidator('From'),
                  ),
                  SizedBox(height: AppSpacing.base),
                  AppTextField(
                    controller: controller.toController,
                    label: 'To',
                    hint: 'Port B',
                    prefixIcon: Icons.flag_outlined,
                    textInputAction: TextInputAction.next,
                    validator: controller.requiredValidator('To'),
                  ),
                  SizedBox(height: AppSpacing.base),
                  _dateField(context),
                  SizedBox(height: AppSpacing.base),
                  _productsSection(),
                  SizedBox(height: AppSpacing.base),
                  AppTextField(
                    controller: controller.rateController,
                    label: 'Rate',
                    hint: '15000',
                    prefixIcon: Icons.paid_outlined,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                    validator: controller.requiredValidator('Rate'),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppSpacing.base),
            _totalBillSummarySection(),
            SizedBox(height: AppSpacing.xxl),
            Obx(
              () => AppButton(
                text: 'Add Trip',
                icon: Icons.add_rounded,
                onPressed: controller.onAddTripPressed,
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

  Widget _totalBillSummarySection() {
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
            Row(
              children: [
                Container(
                  width: 36.w,
                  height: 36.w,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.sm,
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 20.sp,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                Text('Total Bill', style: AppTextStyles.labelMedium),
              ],
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              controller.totalBillDisplay.value == '--'
                  ? '--'
                  : '৳ ${controller.totalBillDisplay.value}',
              style: AppTextStyles.headlineLarge.copyWith(
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'Auto-calculated as: Rate × Quantity',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.neutral700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Product',
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 8.h),
        AppTextField(
          controller: controller.productController,
          label: 'Product Name',
          hint: 'Enter product name',
          prefixIcon: Icons.inventory_2_outlined,
          textInputAction: TextInputAction.next,
          validator: controller.requiredValidator('Product name'),
        ),
        SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: controller.productQuantityController,
                label: 'Quantity',
                hint: 'Quantity',
                prefixIcon: Icons.format_list_numbered_rounded,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                validator: controller.quantityValidator,
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: controller.productUnitController.text,
                decoration: const InputDecoration(
                  labelText: 'Unit',
                  hintText: 'Unit',
                  prefixIcon: Icon(Icons.straighten_rounded),
                ),
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                borderRadius: AppRadius.md,
                items: controller.productUnits
                    .map(
                      (unit) => DropdownMenuItem<String>(
                        value: unit,
                        child: Text(
                          unit,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: controller.onProductUnitChanged,
                validator: controller.requiredValidator('Unit'),
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.sm),
        AppTextField(
          controller: controller.productDescriptionController,
          label: 'Description (optional)',
          hint: 'Description (optional)',
          prefixIcon: Icons.notes_rounded,
          textInputAction: TextInputAction.done,
        ),
      ],
    );
  }

  Widget _dateField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trip Date',
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          controller: controller.dateController,
          readOnly: true,
          validator: controller.requiredValidator('Trip date'),
          decoration: InputDecoration(
            hintText: 'YYYY-MM-DD',
            prefixIcon: const Icon(Icons.calendar_today_outlined),
            suffixIcon: IconButton(
              icon: const Icon(Icons.edit_calendar_rounded),
              onPressed: () => controller.onPickDatePressed(context),
            ),
          ),
          onTap: () => controller.onPickDatePressed(context),
        ),
      ],
    );
  }

  Widget _shipDropdown(
    BuildContext context, {
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
            prefixIcon: const Icon(Icons.directions_boat_outlined),
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

  Widget _companyDropdown(
    BuildContext context, {
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
}
