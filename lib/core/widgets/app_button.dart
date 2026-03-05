import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../themes/themes.dart';

/// Primary elevated button with gradient support and loading state.
class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool useGradient;
  final bool isOutlined;
  final IconData? icon;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.useGradient = true,
    this.isOutlined = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    if (isOutlined) {
      return OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        child: _buildChild(AppColors.primary),
      );
    }

    if (useGradient) {
      return _GradientButton(
        onPressed: isLoading ? null : onPressed,
        child: _buildChild(AppColors.textOnPrimary),
      );
    }

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      child: _buildChild(AppColors.textOnPrimary),
    );
  }

  Widget _buildChild(Color color) {
    if (isLoading) {
      return SizedBox(
        height: 22.h,
        width: 22.h,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: color),
      );
    }

    if (icon != null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 20.sp),
                  SizedBox(width: 8.w),
                  Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          );
        },
      );
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

// ─── Gradient Button (internal widget) ──────────────────────────────────────

class _GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;

  const _GradientButton({this.onPressed, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;

    return Container(
      width: double.infinity,
      height: 52.h,
      decoration: BoxDecoration(
        gradient: isDisabled ? null : AppColors.primaryGradient,
        color: isDisabled ? AppColors.neutral300 : null,
        borderRadius: AppRadius.md,
        boxShadow: isDisabled ? null : AppShadows.primaryGlow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: AppRadius.md,
          child: Center(
            child: DefaultTextStyle(
              style: AppTextStyles.buttonText.copyWith(
                color: isDisabled
                    ? AppColors.neutral500
                    : AppColors.textOnPrimary,
              ),
              child: IconTheme(
                data: IconThemeData(
                  color: isDisabled
                      ? AppColors.neutral500
                      : AppColors.textOnPrimary,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A secondary action link-style button used inline.
class AppLinkButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? color;

  const AppLinkButton({
    super.key,
    required this.text,
    this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Text(
        text,
        style: AppTextStyles.labelMedium.copyWith(
          color: color ?? AppColors.primary,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}
