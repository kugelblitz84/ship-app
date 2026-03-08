import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../core/themes/themes.dart';
import '../../../../core/widgets/widgets.dart';
import '../../utils/invoice_util.dart';
import 'transaction_details_controller.dart';

class TransactionDetailsView extends GetView<TransactionDetailsController> {
  const TransactionDetailsView({super.key});

  @override
  Widget build(BuildContext context) {
    final transaction = controller.transaction;

    return AppSliverScaffold(
      title: 'Transaction Details',
      subtitle: 'Payment and related record information',
      icon: Icons.receipt_long_rounded,
      maxContentWidth: 1120,
      child: transaction == null
          ? _InvalidTransactionState(onBackPressed: () => Get.back())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Amount Highlight ──────────────────────────
                _AmountHighlight(
                  amount: _toDouble(transaction.amount),
                  transactionType: transaction.transactionType,
                ),
                SizedBox(height: AppSpacing.base),

                // ── Payment Summary ───────────────────────────
                _SectionCard(
                  icon: Icons.paid_outlined,
                  title: 'Payment Summary',
                  children: [
                    _DetailRow(
                      icon: Icons.paid_outlined,
                      label: 'Amount',
                      value:
                          '৳ ${_formatAmount(_toDouble(transaction.amount))}',
                      valueColor: AppColors.primary,
                    ),
                    _DetailRow(
                      icon: Icons.price_change_outlined,
                      label: 'Company Total Billed',
                      value:
                          '৳ ${_formatAmount(_toDouble(transaction.totalPrice))}',
                    ),
                    _DetailRow(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Company Due After Payment',
                      value:
                          '৳ ${_formatAmount(_toDouble(transaction.amountDue))}',
                    ),
                    _DetailRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Date',
                      value: _safeText(transaction.date),
                    ),
                    _DetailRow(
                      icon: Icons.category_outlined,
                      label: 'Transaction Type',
                      value: _formatTransactionCategory(
                        transaction.transactionType,
                      ),
                    ),
                    if (_isExpenseTransaction(transaction.transactionType))
                      _DetailRow(
                        icon: Icons.source_outlined,
                        label: 'Expense Source',
                        value: _formatExpenseSource(transaction.expenseSource),
                      ),
                    _DetailRow(
                      icon: Icons.account_balance_rounded,
                      label: 'Payment Method',
                      value: _formatType(transaction.type),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.base),

                // ── Trip Information ──────────────────────────
                if (transaction.hasTrip) ...[
                  _SectionCard(
                    icon: Icons.route_outlined,
                    title: 'Trip Information',
                    children: [
                      _DetailRow(
                        icon: Icons.trip_origin_rounded,
                        label: 'From',
                        value: _safeText(transaction.tripFrom ?? ''),
                      ),
                      _DetailRow(
                        icon: Icons.flag_outlined,
                        label: 'To',
                        value: _safeText(transaction.tripTo ?? ''),
                      ),
                      if ((transaction.tripId ?? '').trim().isNotEmpty)
                        _DetailRow(
                          icon: Icons.tag_rounded,
                          label: 'Trip ID',
                          value: transaction.tripId!.trim(),
                        ),
                      SizedBox(height: AppSpacing.sm),
                      AppButton(
                        text: 'Open Trip Details',
                        icon: Icons.open_in_new_rounded,
                        isOutlined: true,
                        onPressed: controller.openLinkedTrip,
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.base),
                ],

                // ── Company & Record ─────────────────────────
                _SectionCard(
                  icon: Icons.business_outlined,
                  title: 'Company & Record',
                  children: [
                    _DetailRow(
                      icon: Icons.business_outlined,
                      label: 'Company',
                      value: _safeText(
                        transaction.companyAndShipInfo.companyName ?? 'N/A',
                      ),
                    ),
                    _DetailRow(
                      icon: Icons.directions_boat_outlined,
                      label: 'Ship',
                      value: _safeText(
                        transaction.companyAndShipInfo.shipName ?? 'N/A',
                      ),
                    ),
                    if ((transaction.description ?? '').trim().isNotEmpty)
                      _DetailRow(
                        icon: Icons.notes_outlined,
                        label: 'Description',
                        value: transaction.description!.trim(),
                      ),
                  ],
                ),
                SizedBox(height: AppSpacing.lg),

                AppButton(
                  text: 'Generate & Save PDF Invoice',
                  icon: Icons.picture_as_pdf_outlined,
                  onPressed: () =>
                      InvoiceUtil.saveInvoiceAndNotify(transaction),
                ),
                SizedBox(height: AppSpacing.massive),
              ],
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// AMOUNT HIGHLIGHT
// ═══════════════════════════════════════════════════════════════════════════════

class _AmountHighlight extends StatelessWidget {
  const _AmountHighlight({required this.amount, required this.transactionType});

  final double amount;
  final String transactionType;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: AppRadius.lg,
        boxShadow: AppShadows.primaryGlow,
      ),
      child: Row(
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: AppRadius.md,
            ),
            child: Icon(Icons.paid_rounded, size: 24.sp, color: Colors.white),
          ),
          SizedBox(width: AppSpacing.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transaction Amount',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                SizedBox(height: 4.h),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '৳ ${_formatAmount(amount)}',
                    style: AppTextStyles.headlineLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: AppRadius.full,
            ),
            child: Text(
              _formatTransactionCategory(transactionType),
              style: AppTextStyles.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
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
// ERROR STATE
// ═══════════════════════════════════════════════════════════════════════════════

class _InvalidTransactionState extends StatelessWidget {
  const _InvalidTransactionState({required this.onBackPressed});

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
            Text('Transaction not found', style: AppTextStyles.headlineSmall),
            SizedBox(height: AppSpacing.xs),
            Text(
              'Unable to load this transaction\'s details.',
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
  final sanitized = value.replaceAll(',', '').trim();
  return double.tryParse(sanitized) ?? 0;
}

String _formatAmount(double value) {
  return value.toInt().toString();
}

String _formatType(String type) {
  final normalized = type.trim();
  if (normalized.isEmpty) {
    return 'N/A';
  }

  return normalized
      .split('-')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}

String _formatTransactionCategory(String transactionType) {
  final normalized = transactionType.trim().toLowerCase();
  if (normalized == 'expenses') {
    return 'Expenses';
  }
  return 'Payment';
}

bool _isExpenseTransaction(String transactionType) {
  return transactionType.trim().toLowerCase() == 'expenses';
}

String _formatExpenseSource(String expenseSource) {
  final normalized = expenseSource.trim().toLowerCase();
  if (normalized == 'main-balance') {
    return 'From Main Balance';
  }
  if (normalized == 'company') {
    return 'Added to Due';
  }
  if (normalized.isEmpty) {
    return 'N/A';
  }

  return normalized
      .split(RegExp(r'[-_\s]+'))
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}
