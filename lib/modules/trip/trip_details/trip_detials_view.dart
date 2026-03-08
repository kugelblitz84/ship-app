import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../core/themes/themes.dart';
import '../../../core/widgets/widgets.dart';
import '../models/trip_model.dart';
import 'trip_details_controller.dart';

class TripDetailsView extends GetView<TripDetailsController> {
  const TripDetailsView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSliverScaffold(
      title: 'Trip Details',
      subtitle: 'Route, product, and financial details',
      icon: Icons.route_rounded,
      maxContentWidth: 1120,
      actions: [
        Obx(() {
          if (controller.trip == null) {
            return const SizedBox.shrink();
          }

          return TextButton.icon(
            onPressed: controller.isSaving.value
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
          );
        }),
      ],
      child: Obx(() {
        final trip = controller.trip;

        if (trip == null) {
          return _InvalidTripState(onBackPressed: () => Get.back());
        }

        if (controller.isEditing.value) {
          return _buildEditMode(trip);
        }

        return _buildDetailMode(trip);
      }),
    );
  }

  // ─── EDIT MODE ──────────────────────────────────────────────────────────

  Widget _buildEditMode(TripModel trip) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: Form(
        key: controller.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GradientHeader(
              title: 'Editing Trip',
              subtitle: '${_safeText(trip.from)} → ${_safeText(trip.to)}',
              icon: Icons.edit_rounded,
              height: 160,
            ),
            SizedBox(height: AppSpacing.lg),

            // ── Route & Date ─────────────────────────────────────
            _SectionCard(
              icon: Icons.route_rounded,
              title: 'Route & Date',
              children: [
                AppTextField(
                  controller: controller.fromController,
                  label: 'From',
                  prefixIcon: Icons.trip_origin_rounded,
                  validator: (value) =>
                      controller.requiredValidator('From', value),
                ),
                SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: controller.toController,
                  label: 'To',
                  prefixIcon: Icons.flag_outlined,
                  validator: (value) =>
                      controller.requiredValidator('To', value),
                ),
                SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: controller.dateController,
                  label: 'Date',
                  hint: 'YYYY-MM-DD',
                  prefixIcon: Icons.calendar_today_outlined,
                  validator: (value) =>
                      controller.requiredValidator('Date', value),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.base),

            // ── Product ──────────────────────────────────────────
            _SectionCard(
              icon: Icons.inventory_2_outlined,
              title: 'Product',
              children: [
                AppTextField(
                  controller: controller.productNameController,
                  label: 'Product Name',
                  prefixIcon: Icons.category_outlined,
                ),
                SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: AppTextField(
                        controller: controller.productQuantityController,
                        label: 'Quantity',
                        prefixIcon: Icons.numbers_rounded,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppTextField(
                        controller: controller.productUnitController,
                        label: 'Unit',
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: controller.productDescriptionController,
                  label: 'Description',
                  maxLines: 3,
                  prefixIcon: Icons.notes_outlined,
                ),
              ],
            ),
            SizedBox(height: AppSpacing.base),

            // ── Financials ───────────────────────────────────────
            _SectionCard(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Financials',
              children: [
                AppTextField(
                  controller: controller.rateController,
                  label: 'Rate',
                  hint: 'e.g. 15000',
                  prefixIcon: Icons.paid_outlined,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) =>
                      controller.numericRequiredValidator('Rate', value),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.base),

            // ── Auto-calculated Total Bill ───────────────────────
            _TotalBillSummary(controller: controller),
            SizedBox(height: AppSpacing.lg),

            AppButton(
              text: 'Save Changes',
              icon: Icons.save_rounded,
              isLoading: controller.isSaving.value,
              onPressed: controller.saveChanges,
            ),
            SizedBox(height: AppSpacing.massive),
          ],
        ),
      ),
    );
  }

  // ─── DETAIL MODE ────────────────────────────────────────────────────────

  Widget _buildDetailMode(TripModel trip) {
    final rate = _toDouble(trip.rate);
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GradientHeader(
            title: '${_safeText(trip.from)} → ${_safeText(trip.to)}',
            subtitle:
                '${trip.companyAndShipInfo.companyName} • ${trip.companyAndShipInfo.shipName}',
            icon: Icons.route_rounded,
            height: 180,
          ),
          SizedBox(height: AppSpacing.lg),

          // ── Financial Highlights ─────────────────────────────
          _FinancialHighlightBar(
            rate: rate,
            totalBill: _toDouble(trip.totalBill),
          ),
          SizedBox(height: AppSpacing.base),

          // ── Overview ───────────────────────────────────────────
          _SectionCard(
            icon: Icons.info_outline_rounded,
            title: 'Overview',
            children: [
              _DetailRow(
                icon: Icons.calendar_today_outlined,
                label: 'Date',
                value: _formatDate(trip.date),
              ),
              _DetailRow(
                icon: Icons.trip_origin_rounded,
                label: 'From',
                value: _safeText(trip.from),
              ),
              _DetailRow(
                icon: Icons.flag_outlined,
                label: 'To',
                value: _safeText(trip.to),
              ),
              if (trip.isEdited)
                _DetailRow(
                  icon: Icons.edit_note_rounded,
                  label: 'Status',
                  value: 'Edited',
                  valueColor: AppColors.warning,
                ),
            ],
          ),
          SizedBox(height: AppSpacing.base),

          // ── Company & Ship ─────────────────────────────────────
          _SectionCard(
            icon: Icons.business_outlined,
            title: 'Company & Ship',
            children: [
              _DetailRow(
                icon: Icons.business_outlined,
                label: 'Company',
                value: _safeText(trip.companyAndShipInfo.companyName),
              ),
              _DetailRow(
                icon: Icons.directions_boat_outlined,
                label: 'Ship',
                value: _safeText(trip.companyAndShipInfo.shipName),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.base),

          // ── Financials ─────────────────────────────────────────
          _SectionCard(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Financials',
            children: [
              _DetailRow(
                icon: Icons.paid_outlined,
                label: 'Rate',
                value: '৳ ${_formatAmount(rate)}',
              ),
              _DetailRow(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Total Bill',
                value: '৳ ${_formatAmount(_toDouble(trip.totalBill))}',
                valueColor: AppColors.primary,
              ),
            ],
          ),
          SizedBox(height: AppSpacing.base),

          // ── Product ────────────────────────────────────────────
          _ProductSection(product: trip.product),
          SizedBox(height: AppSpacing.massive),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

/// Financial highlight bar showing key monetary figures as cards.
class _FinancialHighlightBar extends StatelessWidget {
  const _FinancialHighlightBar({required this.rate, required this.totalBill});

  final double rate;
  final double totalBill;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: AppRadius.lg,
        boxShadow: AppShadows.primaryGlow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Financial Summary',
            style: AppTextStyles.labelMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _HighlightItem(
                label: 'Total Bill',
                value: '৳ ${_formatAmount(totalBill)}',
              ),
              SizedBox(width: AppSpacing.sm),
              _HighlightItem(label: 'Rate', value: '৳ ${_formatAmount(rate)}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HighlightItem extends StatelessWidget {
  const _HighlightItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
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
              label,
              style: AppTextStyles.caption.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            SizedBox(height: 2.h),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: AppTextStyles.labelMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Auto-calculated fund owed summary (for edit mode).
class _TotalBillSummary extends StatelessWidget {
  const _TotalBillSummary({required this.controller});

  final TripDetailsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Container(
        padding: EdgeInsets.all(18.w),
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          borderRadius: AppRadius.lg,
          border: Border.all(color: AppColors.neutral200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36.w,
                  height: 36.w,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.sm,
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 20.sp,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Bill', style: AppTextStyles.labelMedium),
                      SizedBox(height: 2.h),
                      Text(
                        'Auto-calculated: Rate × Quantity',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.neutral500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              controller.totalBillDisplay.value == '--'
                  ? '--'
                  : '৳ ${controller.totalBillDisplay.value}',
              style: AppTextStyles.headlineLarge.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
              Text(title, style: AppTextStyles.headlineSmall),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

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

class _ProductSection extends StatelessWidget {
  const _ProductSection({required this.product});

  final ProductInfo? product;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.inventory_2_outlined,
      title: 'Product',
      children: [
        if (product == null)
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 20.h),
            child: Column(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 32.sp,
                  color: AppColors.neutral300,
                ),
                SizedBox(height: AppSpacing.sm),
                Text(
                  'No product added for this trip',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.neutral400,
                  ),
                ),
              ],
            ),
          )
        else
          _ProductTile(product: product!),
      ],
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product});

  final ProductInfo product;

  @override
  Widget build(BuildContext context) {
    final quantityText = product.quantity.trim();
    final unitText = product.unit.trim();
    final detailsText = '$quantityText ${unitText.isEmpty ? '' : unitText}'
        .trim();

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.neutral50,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: AppRadius.sm,
            ),
            child: Icon(
              Icons.category_outlined,
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
                  _safeText(product.productName),
                  style: AppTextStyles.labelMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (detailsText.isNotEmpty) ...[
                  SizedBox(height: 4.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 3.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: AppRadius.full,
                    ),
                    child: Text(
                      detailsText,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                if ((product.desctription ?? '').trim().isNotEmpty) ...[
                  SizedBox(height: 6.h),
                  Text(
                    product.desctription!.trim(),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.neutral600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InvalidTripState extends StatelessWidget {
  const _InvalidTripState({required this.onBackPressed});

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
            Text('Trip not found', style: AppTextStyles.headlineSmall),
            SizedBox(height: AppSpacing.xs),
            Text(
              'Unable to load this trip\'s details.',
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

double _toDouble(String value) {
  return double.tryParse(value.replaceAll(',', '').trim()) ?? 0;
}

String _formatAmount(double value) {
  return value.toInt().toString();
}

String _formatDate(String rawDate) {
  final parsed = DateTime.tryParse(rawDate.trim());
  if (parsed == null) {
    return rawDate.trim().isEmpty ? 'Date not provided' : rawDate.trim();
  }

  final year = parsed.year.toString().padLeft(4, '0');
  final month = parsed.month.toString().padLeft(2, '0');
  final day = parsed.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
