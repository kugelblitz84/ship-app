import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../core/themes/themes.dart';
import '../../../core/widgets/widgets.dart';
import '../../trip/models/trip_model.dart';
import 'ship_detials_controller.dart';

class ShipDetailsView extends GetView<ShipDetailsController> {
  const ShipDetailsView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSliverScaffold(
      title: 'Ship Details',
      subtitle: 'Ship profile and linked trips',
      icon: Icons.directions_boat_rounded,
      maxContentWidth: 1120,
      actions: [
        Obx(() {
          if (controller.ship == null) {
            return const SizedBox.shrink();
          }

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                onPressed:
                    (controller.isSaving.value || controller.isDeleting.value)
                    ? null
                    : () => controller.onDeleteShipPressed(context),
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 18.sp,
                  color: Colors.white,
                ),
                label: Text(
                  'Delete',
                  style: AppTextStyles.labelSmall.copyWith(color: Colors.white),
                ),
              ),
              TextButton.icon(
                onPressed:
                    (controller.isSaving.value || controller.isDeleting.value)
                    ? null
                    : (controller.isEditing.value
                          ? controller.cancelEditing
                          : controller.startEditing),
                icon: Icon(
                  controller.isEditing.value
                      ? Icons.close_rounded
                      : Icons.edit_outlined,
                  size: 18.sp,
                  color: Colors.white,
                ),
                label: Text(
                  controller.isEditing.value ? 'Cancel' : 'Edit',
                  style: AppTextStyles.labelSmall.copyWith(color: Colors.white),
                ),
              ),
            ],
          );
        }),
      ],
      child: Obx(() {
        final ship = controller.ship;

        if (ship == null) {
          return _InvalidShipState(onBackPressed: () => Get.back());
        }

        if (controller.isLoading && controller.trips.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final licenseText = (ship.licenseNumber ?? '').trim().isEmpty
            ? 'Not provided'
            : ship.licenseNumber!.trim();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Quick Stats ─────────────────────────────────
            _QuickStatsBar(
              totalTrips: controller.trips.length,
              license: licenseText,
            ),
            SizedBox(height: AppSpacing.base),

            // ── Ship Information ────────────────────────────
            _SectionCard(
              icon: Icons.info_outline_rounded,
              title: 'Ship Information',
              children: controller.isEditing.value
                  ? [
                      _DetailRow(
                        icon: Icons.directions_boat_outlined,
                        label: 'Ship Name',
                        value: _safeText(ship.name),
                      ),
                      SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: controller.licenseController,
                        label: 'License Number',
                        prefixIcon: Icons.badge_outlined,
                      ),
                      SizedBox(height: AppSpacing.base),
                      AppButton(
                        text: 'Save Changes',
                        icon: Icons.save_rounded,
                        isLoading: controller.isSaving.value,
                        onPressed: controller.saveChanges,
                      ),
                    ]
                  : [
                      _DetailRow(
                        icon: Icons.directions_boat_outlined,
                        label: 'Ship Name',
                        value: _safeText(ship.name),
                      ),
                      _DetailRow(
                        icon: Icons.badge_outlined,
                        label: 'License Number',
                        value: licenseText,
                      ),
                      _DetailRow(
                        icon: Icons.route_outlined,
                        label: 'Total Trips',
                        value: '${controller.trips.length}',
                      ),
                    ],
            ),
            SizedBox(height: AppSpacing.base),

            // ── Trips Made ──────────────────────────────────
            _SectionCard(
              icon: Icons.route_outlined,
              title: 'Trips Made (${controller.trips.length})',
              children: controller.trips.isEmpty
                  ? [
                      _EmptyItem(
                        icon: Icons.route_outlined,
                        message: 'No trips found for this ship yet.',
                      ),
                    ]
                  : controller.trips
                        .map(
                          (trip) => _TripTile(
                            trip: trip,
                            onTap: () => controller.openTripDetails(trip),
                          ),
                        )
                        .toList(),
            ),
            SizedBox(height: AppSpacing.massive),
          ],
        );
      }),
      onRefresh: controller.onRefresh,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// QUICK STATS BAR
// ═══════════════════════════════════════════════════════════════════════════════

class _QuickStatsBar extends StatelessWidget {
  const _QuickStatsBar({required this.totalTrips, required this.license});

  final int totalTrips;
  final String license;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: AppRadius.lg,
        boxShadow: AppShadows.primaryGlow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 8.w),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: AppRadius.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Trips',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    '$totalTrips',
                    style: AppTextStyles.headlineMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 2,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 8.w),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: AppRadius.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'License',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    license,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children, this.icon});

  final String title;
  final List<Widget> children;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg,
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 32.w,
                  height: 32.w,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: AppRadius.sm,
                  ),
                  child: Icon(icon, size: 16.sp, color: AppColors.primary),
                ),
                SizedBox(width: AppSpacing.sm),
              ],
              Expanded(child: Text(title, style: AppTextStyles.headlineSmall)),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DETAIL ROW
// ═══════════════════════════════════════════════════════════════════════════════

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 7.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28.w,
            height: 28.w,
            decoration: BoxDecoration(
              color: AppColors.neutral100,
              borderRadius: AppRadius.sm,
            ),
            child: Icon(icon, size: 14.sp, color: AppColors.neutral500),
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.neutral500,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: valueColor ?? AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TRIP TILE
// ═══════════════════════════════════════════════════════════════════════════════

class _TripTile extends StatelessWidget {
  const _TripTile({required this.trip, required this.onTap});

  final TripModel trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.md,
        child: Container(
          margin: EdgeInsets.only(bottom: 10.h),
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: AppColors.neutral50,
            borderRadius: AppRadius.md,
            border: Border.all(color: AppColors.neutral200),
          ),
          child: Row(
            children: [
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: AppRadius.sm,
                ),
                child: Icon(
                  Icons.route_rounded,
                  size: 20.sp,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_safeText(trip.from)} → ${_safeText(trip.to)}',
                      style: AppTextStyles.labelMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 11.sp,
                          color: AppColors.neutral400,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          _safeText(trip.date),
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.neutral500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20.sp,
                color: AppColors.neutral300,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// EMPTY & ERROR STATES
// ═══════════════════════════════════════════════════════════════════════════════

class _EmptyItem extends StatelessWidget {
  const _EmptyItem({required this.message, this.icon});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 20.h),
      child: Column(
        children: [
          if (icon != null)
            Icon(icon, size: 28.sp, color: AppColors.neutral300),
          if (icon != null) SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.neutral400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _InvalidShipState extends StatelessWidget {
  const _InvalidShipState({required this.onBackPressed});

  final VoidCallback onBackPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64.w,
              height: 64.w,
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: AppRadius.full,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 32.sp,
              ),
            ),
            SizedBox(height: AppSpacing.base),
            Text('Ship not found', style: AppTextStyles.headlineSmall),
            SizedBox(height: AppSpacing.xs),
            Text(
              'Unable to load this ship\'s details.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.neutral500,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.lg),
            AppButton(
              text: 'Go Back',
              icon: Icons.arrow_back_rounded,
              onPressed: onBackPressed,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

String _safeText(String value) {
  final text = value.trim();
  return text.isEmpty ? 'N/A' : text;
}
