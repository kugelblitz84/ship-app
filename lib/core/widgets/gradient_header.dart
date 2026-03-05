import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../themes/themes.dart';

/// A gradient hero header used for feature/splash sections.
class GradientHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final double height;

  const GradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Container(
      width: double.infinity,
      height: height.h,
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: AppRadius.lg,
        boxShadow: AppShadows.lg,
      ),
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final headerHeight = constraints.maxHeight;
            final baseHeight = (height.h).clamp(140.0, 240.0);
            final compactScale = (headerHeight / baseHeight).clamp(
              isLandscape ? 0.65 : 0.8,
              1.0,
            );

            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(compactScale)),
              child: IconTheme(
                data: IconThemeData(size: 24.sp * compactScale),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 10.h * compactScale,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null)
                        Container(
                          width: 56.r * compactScale,
                          height: 56.r * compactScale,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: AppRadius.lg,
                          ),
                          child: Icon(
                            icon,
                            size: 28.sp * compactScale,
                            color: Colors.white,
                          ),
                        ),
                      if (icon != null) SizedBox(height: 16.h * compactScale),
                      Text(
                        title,
                        style: AppTextStyles.headlineLarge.copyWith(
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: isLandscape ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null) ...[
                        SizedBox(height: 6.h * compactScale),
                        Text(
                          subtitle!,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                          textAlign: TextAlign.center,
                          maxLines: isLandscape ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
