import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../core/themes/themes.dart';
import '../../../core/widgets/widgets.dart';
import 'force_update_controller.dart';

class ForceUpdateView extends GetView<ForceUpdateController> {
  const ForceUpdateView({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AppSliverScaffold(
        title: 'Update Required',
        subtitle: 'A newer version is required to continue',
        icon: Icons.system_update_alt_rounded,
        showBackButton: false,
        maxContentWidth: 620,
        child: Center(
          child: Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.lg,
              boxShadow: AppShadows.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68.w,
                  height: 68.w,
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.system_update_alt_rounded,
                    size: 34.sp,
                    color: AppColors.warning,
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'Update Required',
                  style: AppTextStyles.headlineMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10.h),
                Text(
                  controller.message,
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10.h),
                Text(
                  'Current build: ${controller.currentVersionCode} | Required build: ${controller.latestVersionCode}',
                  style: AppTextStyles.bodySmall,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24.h),
                Obx(
                  () => AppButton(
                    text: 'Update Now',
                    icon: Icons.download_rounded,
                    isLoading: controller.isLaunching.value,
                    onPressed: controller.openUpdateUrl,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
