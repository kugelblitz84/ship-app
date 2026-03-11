import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../core/themes/themes.dart';
import '../../../core/widgets/widgets.dart';
import 'otp_verification_controller.dart';

class OtpVerificationView extends GetView<OtpVerificationController> {
  const OtpVerificationView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSliverScaffold(
      title: 'OTP Verification',
      subtitle: 'Enter the 6-digit code sent to you',
      icon: Icons.verified_user_outlined,
      maxContentWidth: 560,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 8.h),

            // ── Header ───────────────────────────────────────────
            AuthHeader(
              icon: Icons.verified_user_outlined,
              title: 'Otp Verification',
              subtitle: 'Enter the 6-digit OTP sent to your email/phone',
            ),

            // ── OTP Input Boxes ──────────────────────────────────
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8.w,
              runSpacing: 8.h,
              children: List.generate(6, (index) => _otpBox(context, index)),
            ),

            SizedBox(height: 12.h),

            // ── Error Message ──────────────────────────────────────
            Obx(
              () => AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: controller.showOtpError.value ? 1.0 : 0.0,
                child: Padding(
                  padding: EdgeInsets.only(top: 4.h),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 16.sp,
                        color: AppColors.error,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        'Please enter the complete 6-digit OTP',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(height: AppSpacing.xxl),

            // ── Resend OTP ─────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Didn't receive the code? ",
                  style: AppTextStyles.bodyMedium,
                ),
                AppLinkButton(
                  text: 'Resend',
                  onPressed: () => controller.onResendPressed(),
                ),
              ],
            ),

            SizedBox(height: AppSpacing.xxl),

            // ── Verify Button ──────────────────────────────────────
            Obx(
              () => AppButton(
                text: 'Verify OTP',
                icon: Icons.check_circle_outline_rounded,
                isLoading: controller.isVerifyingOtp.value,
                onPressed: () => controller.onVerifyPressed(),
              ),
            ),

            SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _otpBox(BuildContext context, int index) {
    return Obx(() {
      final hasValue = controller.digitControllers[index].text.isNotEmpty;
      final isFocused = controller.focusedIndex.value == index;

      return AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 48.w,
        height: 56.h,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.md,
          border: Border.all(
            color: isFocused
                ? AppColors.primary
                : hasValue
                ? AppColors.primaryLight
                : AppColors.neutral400,
            width: isFocused ? 2 : 1,
          ),
          boxShadow: isFocused ? AppShadows.primaryGlow : AppShadows.sm,
        ),
        child: Focus(
          onKeyEvent: (_, event) => controller.onKeyEvent(index, event),
          onFocusChange: (hasFocus) {
            if (hasFocus) controller.focusedIndex.value = index;
          },
          child: TextField(
            controller: controller.digitControllers[index],
            focusNode: controller.focusNodes[index],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            textInputAction: index == 5
                ? TextInputAction.done
                : TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(1),
            ],
            style: AppTextStyles.headlineMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              filled: false,
            ),
            onChanged: (value) => controller.onOtpChanged(index, value),
          ),
        ),
      );
    });
  }
}
