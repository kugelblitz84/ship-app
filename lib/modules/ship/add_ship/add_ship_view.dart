import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../core/themes/themes.dart';
import '../../../core/widgets/widgets.dart';
import 'add_ship_controller.dart';

class AddShipView extends GetView<AddShipController> {
  const AddShipView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSliverScaffold(
      title: 'Add Ship',
      subtitle: 'Register a ship in your fleet',
      icon: Icons.directions_boat_rounded,
      maxContentWidth: 980,
      child: Form(
        key: controller.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const GradientHeader(
              title: 'Create Ship Profile',
              subtitle: 'Enter ship details.',
              icon: Icons.directions_boat_rounded,
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
                  Text('Ship Information', style: AppTextStyles.headlineSmall),
                  SizedBox(height: 6.h),
                  Text(
                    'Ships are created independently and can be attached to trips later.',
                    style: AppTextStyles.bodyMedium,
                  ),
                  SizedBox(height: AppSpacing.base),
                  AppTextField(
                    controller: controller.shipNameController,
                    label: 'Ship Name',
                    hint: 'MV Horizon',
                    prefixIcon: Icons.directions_boat_outlined,
                    textInputAction: TextInputAction.next,
                    validator: controller.requiredValidator('Ship name'),
                  ),
                  SizedBox(height: AppSpacing.base),
                  AppTextField(
                    controller: controller.licenseNumberController,
                    label: 'License Number (optional)',
                    hint: 'MV-12345',
                    prefixIcon: Icons.badge_outlined,
                    textInputAction: TextInputAction.done,
                  ),
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
                      'Company selection is now done while creating trips.',
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
                text: 'Add Ship',
                icon: Icons.add_rounded,
                onPressed: controller.onAddShipPressed,
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
}
