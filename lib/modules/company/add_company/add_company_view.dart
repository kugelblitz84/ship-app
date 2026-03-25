import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../core/themes/themes.dart';
import '../../../core/widgets/widgets.dart';
import 'add_company_controller.dart';

class AddCompanyView extends GetView<AddCompanyController> {
  const AddCompanyView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSliverScaffold(
      title: 'Add Company',
      subtitle: 'Create a new carrier profile',
      icon: Icons.business_rounded,
      maxContentWidth: 980,
      child: Form(
        key: controller.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // const GradientHeader(
            //   title: 'Create Company Profile',
            //   subtitle: 'Add carrier details.',
            //   icon: Icons.business_rounded,
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
                    'Company Information',
                    style: AppTextStyles.headlineSmall,
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Keep details clear to help teams identify the right carrier.',
                    style: AppTextStyles.bodyMedium,
                  ),
                  SizedBox(height: AppSpacing.base),
                  AppTextField(
                    controller: controller.companyNameController,
                    label: 'Company Name',
                    hint: 'Oceanic Logistics',
                    prefixIcon: Icons.apartment_outlined,
                    textInputAction: TextInputAction.next,
                    validator: controller.requiredValidator('Company name'),
                  ),
                  SizedBox(height: AppSpacing.base),
                  AppTextField(
                    controller: controller.companyDescriptionController,
                    label: 'Description (optional)',
                    hint: 'Regional marine carrier with refrigerated fleet',
                    prefixIcon: Icons.description_outlined,
                    maxLines: 4,
                    textInputAction: TextInputAction.next,
                  ),
                  SizedBox(height: AppSpacing.base),
                  Obx(() => _openingDueSection(context)),
                ],
              ),
            ),
            SizedBox(height: AppSpacing.lg),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.base,
                vertical: 14.h,
              ),
              decoration: BoxDecoration(
                color: AppColors.infoLight,
                borderRadius: AppRadius.md,
                border: Border.all(color: AppColors.neutral200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.info,
                    size: 18.sp,
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Ships are created separately and connected through trips.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.neutral700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppSpacing.xxl),
            Obx(
              () => AppButton(
                text: 'Add Company',
                icon: Icons.add_rounded,
                onPressed: controller.onAddCompanyPressed,
                isLoading: controller.isLoading,
              ),
            ),
            SizedBox(height: AppSpacing.base),
            AppButton(
              text: 'Clear Form',
              icon: Icons.clear_rounded,
              isOutlined: true,
              onPressed: controller.onClearPressed,
            ),
          ],
        ),
      ),
    );
  }

  Widget _openingDueSection(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                color: AppColors.primary,
                size: 20.sp,
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Opening Due (optional)',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Enable this if the company already owes money from earlier records.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.neutral700,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: controller.includeOpeningDue.value,
                onChanged: controller.onIncludeOpeningDueChanged,
              ),
            ],
          ),
          if (controller.includeOpeningDue.value) ...[
            SizedBox(height: AppSpacing.base),
            AppTextField(
              controller: controller.openingDueAmountController,
              label: 'Opening Due Amount',
              hint: 'Enter amount',
              prefixIcon: Icons.currency_exchange_rounded,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.next,
              validator: controller.openingDueAmountValidator(),
            ),
            SizedBox(height: AppSpacing.base),
            _openingDueDateField(context),
            SizedBox(height: AppSpacing.base),
            AppTextField(
              controller: controller.openingDueDescriptionController,
              label: 'Opening Due Description (optional)',
              hint: 'Example: Previous balance carried forward',
              prefixIcon: Icons.notes_rounded,
              maxLines: 3,
              textInputAction: TextInputAction.done,
            ),
          ],
        ],
      ),
    );
  }

  Widget _openingDueDateField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Opening Due Date',
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          controller: controller.openingDueDateController,
          readOnly: true,
          onTap: () => controller.onPickOpeningDueDatePressed(context),
          validator: controller.openingDueDateValidator(),
          decoration: const InputDecoration(
            hintText: 'YYYY-MM-DD',
            prefixIcon: Icon(Icons.calendar_today_outlined),
            suffixIcon: Icon(Icons.edit_calendar_outlined),
          ),
        ),
      ],
    );
  }
}
