import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:urgent/core/themes/themes.dart';

SnackbarController showAppSnackbar(
  String title,
  String message, {
  SnackPosition snackPosition = SnackPosition.TOP,
  Color? backgroundColor,
  Color colorText = Colors.white,
  Widget? icon,
  Duration duration = const Duration(seconds: 3),
  EdgeInsets? margin,
  double borderRadius = 12,
  SnackStyle snackStyle = SnackStyle.FLOATING,
  bool isDismissible = true,
}) {
  final lowerTitle = title.toLowerCase();
  final isSuccess =
      lowerTitle.contains('success') ||
      lowerTitle.contains('added') ||
      lowerTitle.contains('updated') ||
      lowerTitle.contains('sent') ||
      lowerTitle.contains('exported') ||
      lowerTitle.contains('reset');
  final isError =
      lowerTitle.contains('error') ||
      lowerTitle.contains('invalid') ||
      lowerTitle.contains('missing') ||
      lowerTitle.contains('unable') ||
      lowerTitle.contains('failed') ||
      lowerTitle.contains('not found') ||
      lowerTitle.contains('unavailable') ||
      lowerTitle.contains('expired') ||
      lowerTitle.contains('no ');

  final defaultBackgroundColor = isSuccess
      ? const Color(0xFF00A63E)
      : isError
      ? const Color(0xFFD92D20)
      : const Color(0xFF0057D9);

  final usesLegacySuccess =
      backgroundColor?.value == AppColors.successLight.value;
  final usesLegacyError = backgroundColor?.value == AppColors.errorLight.value;
  final usesLegacyInfo = backgroundColor?.value == AppColors.infoLight.value;
  final usesLegacyWarning =
      backgroundColor?.value == AppColors.warningLight.value;

  final resolvedBackgroundColor = usesLegacySuccess
      ? const Color(0xFF00A63E)
      : usesLegacyError
      ? const Color(0xFFD92D20)
      : usesLegacyInfo
      ? const Color(0xFF0057D9)
      : usesLegacyWarning
      ? const Color(0xFFB54708)
      : backgroundColor ?? defaultBackgroundColor;

  final resolvedTextColor =
      (usesLegacySuccess ||
          usesLegacyError ||
          usesLegacyInfo ||
          usesLegacyWarning)
      ? Colors.white
      : colorText;

  return Get.snackbar(
    title,
    message,
    snackPosition: snackPosition,
    backgroundColor: resolvedBackgroundColor,
    colorText: resolvedTextColor,
    icon: icon,
    duration: duration,
    margin: margin ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    borderRadius: borderRadius,
    snackStyle: snackStyle,
    isDismissible: isDismissible,
  );
}
