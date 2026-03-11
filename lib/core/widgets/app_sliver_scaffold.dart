import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../themes/themes.dart';

class AppSliverScaffold extends StatelessWidget {
  const AppSliverScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.icon,
    this.actions,
    this.onRefresh,
    this.maxContentWidth = 1120,
    this.contentPadding,
    this.backgroundColor,
    this.expandedHeight = 190,
    this.showBackButton = true,
    this.floatingActionButton,
    this.drawer,
    this.scrollController,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget child;
  final List<Widget>? actions;
  final Future<void> Function()? onRefresh;
  final double maxContentWidth;
  final EdgeInsetsGeometry? contentPadding;
  final Color? backgroundColor;
  final double expandedHeight;
  final bool showBackButton;
  final Widget? floatingActionButton;
  final Widget? drawer;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = EdgeInsets.symmetric(horizontal: AppSpacing.xl);
    final page = Scaffold(
      backgroundColor: backgroundColor ?? AppColors.background,
      drawer: drawer,
      floatingActionButton: floatingActionButton,
      body: CustomScrollView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          AppHeroSliverAppBar(
            title: title,
            subtitle: subtitle,
            icon: icon,
            actions: actions,
            expandedHeight: expandedHeight,
            showBackButton: showBackButton,
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: Padding(
                  padding:
                      contentPadding ??
                      horizontalPadding.add(
                        EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      ),
                  child: child,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: AppSpacing.massive)),
        ],
      ),
    );

    if (onRefresh == null) {
      return page;
    }

    return Scaffold(
      backgroundColor: backgroundColor ?? AppColors.background,
      drawer: drawer,
      floatingActionButton: floatingActionButton,
      body: RefreshIndicator(
        onRefresh: onRefresh!,
        color: AppColors.primary,
        child: CustomScrollView(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            AppHeroSliverAppBar(
              title: title,
              subtitle: subtitle,
              icon: icon,
              actions: actions,
              expandedHeight: expandedHeight,
              showBackButton: showBackButton,
            ),
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: Padding(
                    padding:
                        contentPadding ??
                        horizontalPadding.add(
                          EdgeInsets.symmetric(vertical: AppSpacing.lg),
                        ),
                    child: child,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: AppSpacing.massive)),
          ],
        ),
      ),
    );
  }
}

class AppHeroSliverAppBar extends StatelessWidget {
  const AppHeroSliverAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.actions,
    this.expandedHeight = 190,
    this.showBackButton = true,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<Widget>? actions;
  final double expandedHeight;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final resolvedActions = actions ?? const <Widget>[];

    return SliverAppBar(
      expandedHeight: expandedHeight.h,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Get.back(),
            )
          : null,
      actions: resolvedActions,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(gradient: AppColors.heroGradient),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24.w, 54.h, 24.w, 20.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 48.w,
                      height: 48.w,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: AppRadius.md,
                      ),
                      child: Icon(icon, color: Colors.white, size: 24.sp),
                    ),
                    SizedBox(width: 12.w),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          title,
                          style: AppTextStyles.headlineMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null &&
                            subtitle!.trim().isNotEmpty) ...[
                          SizedBox(height: 2.h),
                          Text(
                            subtitle!,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white.withValues(alpha: 0.76),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
