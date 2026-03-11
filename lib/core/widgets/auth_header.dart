import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../themes/themes.dart';

/// Branded header section used at the top of auth screens.
/// Provides visual identity with icon, title, and subtitle.
class AuthHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const AuthHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 8.h),
        // Icon badge with primary surface background
        Container(
          width: 68.w,
          height: 68.w,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: AppRadius.lg,
          ),
          child: Padding(
            padding: EdgeInsets.all(5.w),
            child: Image.asset(
              'assets/logo/master_logo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  Icon(icon, size: 30.sp, color: AppColors.primary),
            ),
          ),
        ),
        SizedBox(height: 20.h),
        Text(
          title,
          style: AppTextStyles.headlineLarge,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8.h),
        Text(
          subtitle,
          style: AppTextStyles.bodyMedium,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 32.h),
      ],
    );
  }
}
