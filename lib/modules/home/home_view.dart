import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../core/themes/themes.dart';
import '../../core/widgets/widgets.dart';
import '../../routes/app_routes.dart';
import '../trip/models/trip_model.dart';
import '../Transactions/models/transaction_model.dart';
import 'home_controller.dart';

enum _HomeLayoutSize { mobile, tablet, desktop }

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final model = controller.homeModel.value;
      final isLoading = controller.isLoading.value;

      return LayoutBuilder(
        builder: (context, constraints) {
          final layout = _resolveLayout(constraints.maxWidth);

          return Scaffold(
            backgroundColor: AppColors.background,
            drawer: _buildDrawer(),
            body: RefreshIndicator(
              onRefresh: controller.onRefresh,
              color: AppColors.primary,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // ── Hero App Bar ───────────────────────────────────────
                  _buildSliverAppBar(model, layout),

                  // ── Body Content ───────────────────────────────────────
                  SliverToBoxAdapter(
                    child: isLoading
                        ? _buildLoadingState(layout)
                        : _buildDashboardContent(layout),
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  _HomeLayoutSize _resolveLayout(double width) {
    if (width < 600) return _HomeLayoutSize.mobile;
    if (width <= 1024) return _HomeLayoutSize.tablet;
    return _HomeLayoutSize.desktop;
  }

  Widget _buildSliverAppBar(dynamic model, _HomeLayoutSize layout) {
    final greeting = _getGreeting();
    final name = model?.name?.trim().isNotEmpty == true ? model!.name! : '';
    final org = model?.organization?.trim().isNotEmpty == true
        ? model!.organization!
        : '';
    final horizontalPadding = switch (layout) {
      _HomeLayoutSize.mobile => 24.w,
      _HomeLayoutSize.tablet => 28.w,
      _HomeLayoutSize.desktop => 36.w,
    };
    final verticalTopPadding = switch (layout) {
      _HomeLayoutSize.mobile => 56.h,
      _HomeLayoutSize.tablet => 56.h,
      _HomeLayoutSize.desktop => 60.h,
    };
    final bottomPadding = switch (layout) {
      _HomeLayoutSize.mobile => 24.h,
      _HomeLayoutSize.tablet => 24.h,
      _HomeLayoutSize.desktop => 28.h,
    };

    return SliverAppBar(
      expandedHeight: layout == _HomeLayoutSize.desktop ? 255.h : 230.h,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: controller.onRefresh,
          tooltip: 'Refresh',
        ),
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Colors.white),
          onPressed: controller.onLogoutPressed,
          tooltip: 'Sign Out',
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: LayoutBuilder(
          builder: (context, constraints) {
            final compactHeader = constraints.maxHeight < 235;
            final topPadding = compactHeader ? 12.h : verticalTopPadding;
            final bottomInset = compactHeader ? 8.h : bottomPadding;
            final avatarSize = compactHeader ? 42.0 : 48.w;
            final greetingStyle = compactHeader
                ? AppTextStyles.headlineSmall.copyWith(color: Colors.white)
                : AppTextStyles.headlineMedium.copyWith(color: Colors.white);

            return Container(
              decoration: const BoxDecoration(gradient: AppColors.heroGradient),
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    topPadding,
                    horizontalPadding,
                    bottomInset,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: avatarSize,
                            height: avatarSize,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: AppRadius.md,
                            ),
                            child: Center(
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: AppTextStyles.headlineLarge.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 14.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$greeting${name.isNotEmpty ? ', $name' : ''}',
                                  style: greetingStyle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (controller.isAdmin.value) ...[
                                  SizedBox(height: compactHeader ? 4.h : 6.h),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 10.w,
                                      vertical: compactHeader ? 3.h : 4.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.18,
                                      ),
                                      borderRadius: AppRadius.full,
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.22,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.verified_user_rounded,
                                          size: 14.sp,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 6.w),
                                        Text(
                                          'Admin',
                                          style: AppTextStyles.caption.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (org.isNotEmpty) ...[
                                  SizedBox(height: 2.h),
                                  Text(
                                    org,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.75,
                                      ),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (!compactHeader) ...[
                        SizedBox(height: 14.h),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 10.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: AppRadius.md,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.16),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 26.w,
                                height: 26.w,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: AppRadius.sm,
                                ),
                                child: Icon(
                                  Icons.account_balance_wallet_rounded,
                                  size: 14.sp,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: Text(
                                  'Lifetime Balance',
                                  style: AppTextStyles.caption.copyWith(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Obx(
                                () => Text(
                                  '৳ ${controller.totalFundReceived.value}',
                                  style: AppTextStyles.labelMedium.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
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

  // ═══════════════════════════════════════════════════════════════════════
  // LOADING STATE
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildLoadingState(_HomeLayoutSize layout) {
    final minHeight = switch (layout) {
      _HomeLayoutSize.mobile => 400.h,
      _HomeLayoutSize.tablet => 480.h,
      _HomeLayoutSize.desktop => 560.h,
    };

    return SizedBox(
      height: minHeight,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 48.w,
              height: 48.w,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'Loading dashboard...',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // DASHBOARD CONTENT
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildDashboardContent(_HomeLayoutSize layout) {
    switch (layout) {
      case _HomeLayoutSize.mobile:
        return _buildMobileDashboardContent();
      case _HomeLayoutSize.tablet:
        return _buildTabletDashboardContent();
      case _HomeLayoutSize.desktop:
        return _buildDesktopDashboardContent();
    }
  }

  Widget _buildMobileDashboardContent() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 20.h),

          // ── Stats Overview Cards ─────────────────────────────────
          _buildStatsGrid(columns: 2),

          SizedBox(height: 24.h),

          // ── Monthly + Lifetime Financial Overview ────────────────
          _buildFinancialOverview(sideBySide: false),

          SizedBox(height: 24.h),

          // ── Quick Actions ────────────────────────────────────────
          _buildSectionHeader('Quick Actions', null, null),
          SizedBox(height: 12.h),
          _buildQuickActions(columns: 4),

          SizedBox(height: 24.h),

          // ── Recent Trips ─────────────────────────────────────────
          _buildSectionHeader(
            'Recent Trips',
            'View All',
            () => Get.toNamed(AppRoutes.tripHistory),
          ),
          SizedBox(height: 12.h),
          _buildRecentTrips(),

          SizedBox(height: 24.h),

          // ── Recent Transactions ──────────────────────────────────
          _buildSectionHeader(
            'Recent Transactions',
            'View All',
            () => Get.toNamed(AppRoutes.transactionHistory),
          ),
          SizedBox(height: 12.h),
          _buildRecentTransactions(),

          SizedBox(height: 32.h),
        ],
      ),
    );
  }

  Widget _buildTabletDashboardContent() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 20.h),
          _buildStatsGrid(columns: 2),
          SizedBox(height: 24.h),
          _buildFinancialOverview(sideBySide: true),
          SizedBox(height: 24.h),
          _buildSectionHeader('Quick Actions', null, null),
          SizedBox(height: 12.h),
          _buildQuickActions(columns: 4),
          SizedBox(height: 24.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      'Recent Trips',
                      'View All',
                      () => Get.toNamed(AppRoutes.tripHistory),
                    ),
                    SizedBox(height: 12.h),
                    _buildRecentTrips(),
                  ],
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      'Recent Transactions',
                      'View All',
                      () => Get.toNamed(AppRoutes.transactionHistory),
                    ),
                    SizedBox(height: 12.h),
                    _buildRecentTransactions(),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 32.h),
        ],
      ),
    );
  }

  Widget _buildDesktopDashboardContent() {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 1280.w),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 28.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 24.h),
              _buildStatsGrid(columns: 4),
              SizedBox(height: 24.h),
              _buildFinancialOverview(sideBySide: true),
              SizedBox(height: 24.h),
              _buildSectionHeader('Quick Actions', null, null),
              SizedBox(height: 12.h),
              _buildQuickActions(columns: 4),
              SizedBox(height: 24.h),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                          'Recent Trips',
                          'View All',
                          () => Get.toNamed(AppRoutes.tripHistory),
                        ),
                        SizedBox(height: 12.h),
                        _buildRecentTrips(),
                      ],
                    ),
                  ),
                  SizedBox(width: 18.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                          'Recent Transactions',
                          'View All',
                          () => Get.toNamed(AppRoutes.transactionHistory),
                        ),
                        SizedBox(height: 12.h),
                        _buildRecentTransactions(),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 36.h),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STATS GRID — 4 stat summary cards
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildStatsGrid({required int columns}) {
    final items = [
      _DashboardStatItem(
        icon: Icons.directions_boat_rounded,
        label: 'Ships',
        value: controller.shipCount.value.toString(),
        color: AppColors.primary,
        bgColor: AppColors.primarySurface,
        onTap: () => Get.toNamed(AppRoutes.shipList),
      ),
      _DashboardStatItem(
        icon: Icons.business_rounded,
        label: 'Companies',
        value: controller.companyCount.value.toString(),
        color: AppColors.accent,
        bgColor: AppColors.accentLight,
        onTap: () => Get.toNamed(AppRoutes.companyList),
      ),
      _DashboardStatItem(
        icon: Icons.route_rounded,
        label: 'Trips',
        value: controller.tripCount.value.toString(),
        color: AppColors.info,
        bgColor: AppColors.infoLight,
        onTap: () => Get.toNamed(AppRoutes.tripHistory),
      ),
      _DashboardStatItem(
        icon: Icons.receipt_long_rounded,
        label: 'Transactions',
        value: controller.transactionCount.value.toString(),
        color: AppColors.success,
        bgColor: AppColors.successLight,
        onTap: () => Get.toNamed(AppRoutes.transactionHistory),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = 12.w;
        final width =
            (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: 12.h,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: _buildStatCard(
                  icon: item.icon,
                  label: item.label,
                  value: item.value,
                  color: item.color,
                  bgColor: item.bgColor,
                  onTap: item.onTap,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color bgColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.lg,
          boxShadow: AppShadows.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: AppRadius.md,
              ),
              child: Icon(icon, size: 22.sp, color: color),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: AppTextStyles.headlineMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    label,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 10.sp,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14.sp,
              color: AppColors.neutral400,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // FINANCIAL OVERVIEW — Monthly + Lifetime (distinct cards)
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildFinancialOverview({required bool sideBySide}) {
    if (!sideBySide) {
      return Column(
        children: [
          _buildMonthlyFinancialCard(),
          SizedBox(height: 12.h),
          _buildLifetimeFinancialCard(),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildMonthlyFinancialCard()),
        SizedBox(width: 12.w),
        Expanded(child: _buildLifetimeFinancialCard()),
      ],
    );
  }

  Widget _buildMonthlyFinancialCard() {
    //final billed = controller.monthlyFundOwed.value;
    //final received = controller.monthlyFundReceived.value;
    //final totalDue = controller.monthlyTotalDue.value;
    final progress = controller.monthlyFundOwed.value > 0
        ? (controller.monthlyFundReceived.value /
                  controller.monthlyFundOwed.value)
              .clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: AppRadius.lg,
        boxShadow: AppShadows.primaryGlow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOverviewHeader(
            icon: Icons.calendar_month_rounded,
            title: 'Monthly Overview',
            subtitle: _currentMonthLabel(),
            badgeText: 'MONTHLY',
            badgeColor: Colors.white.withValues(alpha: 0.18),
            titleColor: Colors.white,
            subtitleColor: Colors.white.withValues(alpha: 0.72),
            iconColor: Colors.white,
          ),
          SizedBox(height: 20.h),
          Text(
            'Total Due',
            style: AppTextStyles.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.65),
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 4.h),
          Obx(
            () => Text(
              '৳ ${_formatCurrency(controller.monthlyTotalDue.value)}',
              style: AppTextStyles.displayMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(height: 16.h),
          ClipRRect(
            borderRadius: AppRadius.full,
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.success,
              ),
              minHeight: 6.h,
            ),
          ),
          SizedBox(height: 6.h),
          Obx(
            () => Text(
              controller.monthlyFundOwed.value > 0
                  ? '${(progress * 100).toStringAsFixed(1)}% collected this month'
                  : 'No financial activity this month',
              style: AppTextStyles.caption.copyWith(
                color: Colors.white.withValues(alpha: 0.65),
              ),
            ),
          ),
          SizedBox(height: 18.h),
          Row(
            children: [
              Obx(
                () => Expanded(
                  child: _buildFinanceStat(
                    'Total Billed',
                    '৳ ${_formatCurrency(controller.monthlyFundOwed.value)}',
                    Icons.trending_up_rounded,
                    AppColors.warningLight,
                    labelColor: Colors.white.withValues(alpha: 0.7),
                    valueColor: Colors.white,
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 40.h,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              Obx(
                () => Expanded(
                  child: _buildFinanceStat(
                    'Current Balance',
                    '৳ ${_formatCurrency(controller.monthlyFundReceived.value)}',
                    Icons.trending_down_rounded,
                    AppColors.successLight,
                    labelColor: Colors.white.withValues(alpha: 0.7),
                    valueColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLifetimeFinancialCard() {
    //final billed = controller.totalFundOwed.value;
    //final received = controller.totalFundReceived.value;
    //final totalDue = controller.totalDue.value;
    final progress = controller.totalFundOwed.value > 0
        ? (controller.totalFundReceived.value / controller.totalFundOwed.value)
              .clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.neutral200),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOverviewHeader(
            icon: Icons.account_balance_wallet_rounded,
            title: 'Lifetime Overview',
            subtitle: 'All-time totals',
            badgeText: 'LIFETIME',
            badgeColor: AppColors.primarySurface,
            titleColor: AppColors.textPrimary,
            subtitleColor: AppColors.textSecondary,
            iconColor: AppColors.primary,
          ),
          SizedBox(height: 20.h),
          Text(
            'Total Due',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 4.h),
          Obx(
            () => Text(
              '৳ ${_formatCurrency(controller.totalDue.value)}',
              style: AppTextStyles.displayMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(height: 16.h),
          ClipRRect(
            borderRadius: AppRadius.full,
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.neutral200,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.success,
              ),
              minHeight: 6.h,
            ),
          ),
          SizedBox(height: 6.h),
          Obx(
            () => Text(
              controller.totalFundOwed.value > 0
                  ? '${(progress * 100).toStringAsFixed(1)}% collected'
                  : 'No due amount',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          SizedBox(height: 18.h),
          Row(
            children: [
              Obx(
                () => Expanded(
                  child: _buildFinanceStat(
                    'Total Billed',
                    '৳ ${_formatCurrency(controller.totalFundOwed.value)}',
                    Icons.trending_up_rounded,
                    AppColors.warning,
                    labelColor: AppColors.textSecondary,
                    valueColor: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(width: 1, height: 40.h, color: AppColors.neutral200),
              Obx(
                () => Expanded(
                  child: _buildFinanceStat(
                    'Lifetime Balance',
                    '৳ ${_formatCurrency(controller.totalFundReceived.value)}',
                    Icons.trending_down_rounded,
                    AppColors.success,
                    labelColor: AppColors.textSecondary,
                    valueColor: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required Color titleColor,
    required Color subtitleColor,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Container(
          width: 34.w,
          height: 34.w,
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: AppRadius.sm,
          ),
          child: Icon(icon, color: iconColor, size: 18.sp),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.labelMedium.copyWith(
                  color: titleColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: AppTextStyles.caption.copyWith(color: subtitleColor),
              ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: AppRadius.full,
          ),
          child: Text(
            badgeText,
            style: AppTextStyles.labelSmall.copyWith(
              color: titleColor,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFinanceStat(
    String label,
    String value,
    IconData icon,
    Color iconColor, {
    required Color labelColor,
    required Color valueColor,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14.sp, color: iconColor),
              SizedBox(width: 4.w),
              Flexible(
                child: Text(
                  label,
                  style: AppTextStyles.caption.copyWith(color: labelColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: AppTextStyles.labelMedium.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _currentMonthLabel() {
    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final now = DateTime.now();
    return '${monthNames[now.month - 1]} ${now.year}';
  }

  // ═══════════════════════════════════════════════════════════════════════
  // QUICK ACTIONS — Navigate to key features
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildQuickActions({required int columns}) {
    final actions = [
      _QuickActionItem(
        icon: Icons.add_circle_outline_rounded,
        label: 'Add Trip',
        color: AppColors.primary,
        onTap: () => Get.toNamed(AppRoutes.addTrip),
      ),
      _QuickActionItem(
        icon: Icons.payments_outlined,
        label: 'Add Payment',
        color: AppColors.accent,
        onTap: () => Get.toNamed(AppRoutes.addTransaction),
      ),
      _QuickActionItem(
        icon: Icons.directions_boat_outlined,
        label: 'Add Ship',
        color: AppColors.info,
        onTap: () => Get.toNamed(AppRoutes.addShip),
      ),
      _QuickActionItem(
        icon: Icons.domain_add_rounded,
        label: 'Add Co.',
        color: AppColors.success,
        onTap: () => Get.toNamed(AppRoutes.addCompany),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = 10.w;
        final width =
            (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final action in actions)
              SizedBox(
                width: width,
                child: _buildActionChip(
                  icon: action.icon,
                  label: action.label,
                  color: action.color,
                  onTap: action.onTap,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 4.w),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.md,
          border: Border.all(color: AppColors.neutral200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20.sp, color: color),
            ),
            SizedBox(height: 8.h),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SECTION HEADER
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildSectionHeader(
    String title,
    String? actionText,
    VoidCallback? onAction,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTextStyles.headlineSmall),
        if (actionText != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  actionText,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 2.w),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12.sp,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // RECENT TRIPS
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildRecentTrips() {
    final trips = controller.recentTrips;

    if (trips.isEmpty) {
      return _buildEmptyCard(
        icon: Icons.route_rounded,
        message: 'No trips recorded yet',
        actionLabel: 'Add First Trip',
        onAction: () => Get.toNamed(AppRoutes.addTrip),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg,
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        children: [
          for (int i = 0; i < trips.length; i++) ...[
            _buildTripTile(trips[i]),
            if (i < trips.length - 1)
              Divider(
                height: 1,
                color: AppColors.neutral100,
                indent: 16.w,
                endIndent: 16.w,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildTripTile(TripModel trip) {
    final totalBill = trip.totalBill;

    return InkWell(
      onTap: () => Get.toNamed(AppRoutes.tripDetails, arguments: trip),
      borderRadius: AppRadius.lg,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Row(
          children: [
            // Route icon
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: AppRadius.sm,
              ),
              child: Icon(
                Icons.sailing_rounded,
                size: 20.sp,
                color: AppColors.primary,
              ),
            ),
            SizedBox(width: 12.w),
            // Trip route + info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${trip.from} → ${trip.to}',
                    style: AppTextStyles.labelMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    '${trip.companyAndShipInfo.shipName} • ${trip.date}',
                    style: AppTextStyles.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Text(
              '৳ $totalBill',
              style: AppTextStyles.labelMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // RECENT TRANSACTIONS
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildRecentTransactions() {
    final transactions = controller.recentTransactions;

    if (transactions.isEmpty) {
      return _buildEmptyCard(
        icon: Icons.receipt_long_rounded,
        message: 'No transactions recorded yet',
        actionLabel: 'Add Transaction',
        onAction: () => Get.toNamed(AppRoutes.addTransaction),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg,
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        children: [
          for (int i = 0; i < transactions.length; i++) ...[
            _buildTransactionTile(transactions[i]),
            if (i < transactions.length - 1)
              Divider(
                height: 1,
                color: AppColors.neutral100,
                indent: 16.w,
                endIndent: 16.w,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildTransactionTile(TransactionModel tx) {
    final typeIcon = _getTransactionTypeIcon(tx.type);
    final typeColor = _getTransactionTypeColor(tx.type);

    return InkWell(
      onTap: () => Get.toNamed(AppRoutes.transactionDetails, arguments: tx),
      borderRadius: AppRadius.lg,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Row(
          children: [
            // Type icon
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.1),
                borderRadius: AppRadius.sm,
              ),
              child: Icon(typeIcon, size: 20.sp, color: typeColor),
            ),
            SizedBox(width: 12.w),
            // Transaction info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.companyName.isNotEmpty ? tx.companyName : 'Transaction',
                    style: AppTextStyles.labelMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    tx.isExpense
                        ? '${tx.routeLabel} • ${tx.date} • ${tx.transactionTypeLabel} • ${tx.expenseSourceLabel}'
                        : '${tx.routeLabel} • ${tx.date} • ${tx.transactionTypeLabel}',
                    style: AppTextStyles.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            // Amount + type label
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '৳ ${tx.amount}',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  _formatTransactionType(tx.type),
                  style: AppTextStyles.overline.copyWith(
                    color: typeColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // EMPTY STATE CARD
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildEmptyCard({
    required IconData icon,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 32.h, horizontal: 20.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg,
        border: Border.all(
          color: AppColors.neutral200,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              color: AppColors.neutral100,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24.sp, color: AppColors.neutral400),
          ),
          SizedBox(height: 12.h),
          Text(
            message,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            SizedBox(height: 12.h),
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: AppRadius.full,
                ),
                child: Text(
                  actionLabel,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // DRAWER — Navigation Menu
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildDrawer() {
    return Drawer(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: AppColors.surface,
      surfaceTintColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Drawer Header ─────────────────────────────────────
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.lg,
              ),
              decoration: const BoxDecoration(gradient: AppColors.heroGradient),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52.w,
                    height: 52.w,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: AppRadius.md,
                    ),
                    child: Icon(
                      Icons.rocket_launch_rounded,
                      size: 26.sp,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'Urgent',
                    style: AppTextStyles.headlineMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Shipping Management',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 8.h),

            // ── Menu Items ────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildDrawerItem(
                      Icons.dashboard_rounded,
                      'Dashboard',
                      true,
                      () => Get.back(),
                    ),
                    _buildDrawerItem(
                      Icons.directions_boat_rounded,
                      'Ships',
                      false,
                      () {
                        Get.back();
                        Get.toNamed(AppRoutes.shipList);
                      },
                    ),
                    _buildDrawerItem(
                      Icons.business_rounded,
                      'Companies',
                      false,
                      () {
                        Get.back();
                        Get.toNamed(AppRoutes.companyList);
                      },
                    ),

                    if (controller.isAdmin.value)
                      _buildDrawerItem(
                        Icons.admin_panel_settings_rounded,
                        'Admin Users',
                        false,
                        () {
                          Get.back();
                          Get.toNamed(AppRoutes.adminUsers);
                        },
                      ),

                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 8.h,
                      ),
                      child: Divider(color: AppColors.neutral200, height: 1),
                    ),

                    _buildDrawerItem(
                      Icons.route_rounded,
                      'Add Trip',
                      false,
                      () {
                        Get.back();
                        Get.toNamed(AppRoutes.addTrip);
                      },
                    ),
                    _buildExpandableTransactionDrawerItem(),

                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 8.h,
                      ),
                      child: Divider(color: AppColors.neutral200, height: 1),
                    ),

                    _buildDrawerItem(
                      Icons.history_rounded,
                      'Trip History',
                      false,
                      () {
                        Get.back();
                        Get.toNamed(AppRoutes.tripHistory);
                      },
                    ),
                    _buildDrawerItem(
                      Icons.receipt_long_rounded,
                      'Transaction History',
                      false,
                      () {
                        Get.back();
                        Get.toNamed(AppRoutes.transactionHistory);
                      },
                    ),
                  ],
                ),
              ),
            ),

            // ── Sign Out ──────────────────────────────────────────
            Padding(
              padding: EdgeInsets.all(16.w),
              child: AppButton(
                text: 'Sign Out',
                icon: Icons.logout_rounded,
                onPressed: controller.onLogoutPressed,
                isOutlined: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    IconData icon,
    String title,
    bool isActive,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 2.h),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.sm),
        tileColor: isActive ? AppColors.primarySurface : null,
        leading: Icon(
          icon,
          color: isActive ? AppColors.primary : AppColors.neutral500,
          size: 22.sp,
        ),
        title: Text(
          title,
          style: AppTextStyles.labelMedium.copyWith(
            color: isActive ? AppColors.primary : AppColors.textPrimary,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildExpandableTransactionDrawerItem() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 2.h),
      child: ExpansionTile(
        tilePadding: EdgeInsets.symmetric(horizontal: 16.w),
        childrenPadding: EdgeInsets.only(left: 12.w, right: 6.w, bottom: 6.h),
        leading: Icon(
          Icons.payments_rounded,
          color: AppColors.neutral500,
          size: 22.sp,
        ),
        title: Text(
          'Add Transaction',
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.sm),
        collapsedShape: RoundedRectangleBorder(borderRadius: AppRadius.sm),
        children: [
          ListTile(
            dense: true,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.sm),
            leading: Icon(
              Icons.arrow_right_rounded,
              color: AppColors.neutral500,
              size: 20.sp,
            ),
            title: Text('Payment', style: AppTextStyles.bodyMedium),
            onTap: () {
              Get.back();
              Get.toNamed(AppRoutes.addTransaction);
            },
          ),
          ListTile(
            dense: true,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.sm),
            leading: Icon(
              Icons.arrow_right_rounded,
              color: AppColors.neutral500,
              size: 20.sp,
            ),
            title: Text('Expenses', style: AppTextStyles.bodyMedium),
            onTap: () {
              Get.back();
              Get.toNamed(AppRoutes.addExpensesTransaction);
            },
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _formatCurrency(double value) {
    return value.toInt().toString();
    if (value >= 1e7) {
      return '${(value / 1e7).toStringAsFixed(2)} Cr';
    }
    if (value >= 1e5) {
      return '${(value / 1e5).toStringAsFixed(2)} L';
    }
    if (value % 1 == 0) {
      // Add commas to integer
      return value.toInt().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
    }
    return value
        .toStringAsFixed(2)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }

  IconData _getTransactionTypeIcon(String type) {
    switch (type.trim().toLowerCase()) {
      case 'cash':
        return Icons.money_rounded;
      case 'bank-payment':
        return Icons.account_balance_rounded;
      case 'bkash':
        return Icons.phone_android_rounded;
      case 'nagad':
        return Icons.smartphone_rounded;
      case 'other':
        return Icons.more_horiz_rounded;
      default:
        return Icons.payment_rounded;
    }
  }

  Color _getTransactionTypeColor(String type) {
    switch (type.trim().toLowerCase()) {
      case 'cash':
        return AppColors.success;
      case 'bank-payment':
        return AppColors.info;
      case 'bkash':
        return const Color(0xFFE2136E);
      case 'nagad':
        return AppColors.accent;
      case 'other':
        return AppColors.neutral600;
      default:
        return AppColors.neutral500;
    }
  }

  String _formatTransactionType(String type) {
    switch (type.trim().toLowerCase()) {
      case 'cash':
        return 'CASH';
      case 'bank-payment':
        return 'BANK';
      case 'bkash':
        return 'BKASH';
      case 'nagad':
        return 'NAGAD';
      case 'other':
        return 'OTHER';
      default:
        return type.toUpperCase();
    }
  }
}

class _DashboardStatItem {
  const _DashboardStatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;
}

class _QuickActionItem {
  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}
