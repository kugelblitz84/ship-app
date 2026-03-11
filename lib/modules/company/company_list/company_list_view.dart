import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../core/themes/themes.dart';
import '../../../core/widgets/widgets.dart';
import '../models/company_model.dart';
import 'company_list_controller.dart';

class CompanyListView extends GetView<CompanyListController> {
  const CompanyListView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSliverScaffold(
      title: 'Companies',
      subtitle: 'Browse and manage carrier profiles',
      icon: Icons.business_rounded,
      maxContentWidth: 1120,
      actions: [
        Obx(
          () => controller.hasActiveFilters
              ? IconButton(
                  tooltip: 'Clear filters',
                  icon: const Icon(Icons.filter_alt_off_rounded),
                  onPressed: controller.clearAllFilters,
                )
              : const SizedBox.shrink(),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: controller.onAddCompanyPressed,
        icon: const Icon(Icons.add_rounded, color: AppColors.primary),
        label: const Text(
          'Add Company',
          style: TextStyle(color: AppColors.primary),
        ),
      ),
      scrollController: controller.scrollController,
      onRefresh: controller.onRefresh,
      child: Obx(() {
        final visibleCompanies = controller.visibleCompanies;

        if (controller.isLoading && controller.companies.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SummaryCard(count: controller.companies.length),
            SizedBox(height: AppSpacing.lg),
            _CompanySearchSortFilterBar(controller: controller),
            SizedBox(height: AppSpacing.lg),
            if (visibleCompanies.isEmpty && controller.companies.isNotEmpty)
              _NoFilterResultState(onClear: controller.clearAllFilters)
            else if (controller.companies.isEmpty)
              _EmptyState(onAddPressed: controller.onAddCompanyPressed)
            else
              ...visibleCompanies
                  .map(
                    (company) => Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.base),
                      child: _CompanyCard(
                        company: company,
                        onTap: () => controller.onCompanyPressed(company),
                        onDelete: () =>
                            controller.onDeleteCompanyPressed(context, company),
                      ),
                    ),
                  )
                  .toList(),
            if (controller.isLoadingMore)
              Padding(
                padding: EdgeInsets.only(top: AppSpacing.sm),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        );
      }),
    );
  }
}

class _CompanySearchSortFilterBar extends StatelessWidget {
  const _CompanySearchSortFilterBar({required this.controller});

  final CompanyListController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            controller: controller.searchController,
            hint: 'Search company name or description',
            prefixIcon: Icons.search_rounded,
            suffix: controller.searchQuery.value.trim().isNotEmpty
                ? IconButton(
                    onPressed: controller.searchController.clear,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.neutral500,
                    ),
                  )
                : null,
          ),
          SizedBox(height: AppSpacing.base),
          DropdownButtonFormField<CompanySortOption>(
            value: controller.sortOption.value,
            decoration: const InputDecoration(
              labelText: 'Sort by',
              prefixIcon: Icon(Icons.sort_rounded),
            ),
            borderRadius: AppRadius.md,
            items: CompanySortOption.values
                .map(
                  (option) => DropdownMenuItem<CompanySortOption>(
                    value: option,
                    child: Text(_companySortLabel(option)),
                  ),
                )
                .toList(),
            onChanged: controller.onSortChanged,
          ),
          SizedBox(height: AppSpacing.base),
          DropdownButtonFormField<CompanyActivityFilter>(
            value: controller.activityFilter.value,
            decoration: const InputDecoration(
              labelText: 'Activity',
              prefixIcon: Icon(Icons.insights_rounded),
            ),
            borderRadius: AppRadius.md,
            items: CompanyActivityFilter.values
                .map(
                  (filter) => DropdownMenuItem<CompanyActivityFilter>(
                    value: filter,
                    child: Text(_companyActivityFilterLabel(filter)),
                  ),
                )
                .toList(),
            onChanged: controller.onActivityFilterChanged,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            '${controller.visibleCompanies.length} result${controller.visibleCompanies.length == 1 ? '' : 's'}',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.neutral600,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoFilterResultState extends StatelessWidget {
  const _NoFilterResultState({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            color: AppColors.neutral400,
            size: 44.sp,
          ),
          SizedBox(height: AppSpacing.sm),
          Text('No matching companies', style: AppTextStyles.headlineSmall),
          SizedBox(height: 4.h),
          Text(
            'Try changing your search or activity filters.',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.base),
          OutlinedButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Clear filters'),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg,
        boxShadow: AppShadows.md,
      ),
      child: Row(
        children: [
          Container(
            width: 46.w,
            height: 46.w,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: AppRadius.md,
            ),
            child: Icon(
              Icons.apartment_rounded,
              color: AppColors.primary,
              size: 22.sp,
            ),
          ),
          SizedBox(width: AppSpacing.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Companies', style: AppTextStyles.bodyMedium),
                SizedBox(height: 2.h),
                Text('$count', style: AppTextStyles.headlineSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompanyCard extends StatelessWidget {
  const _CompanyCard({required this.company, this.onTap, this.onDelete});

  final CompanyModel company;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final description = (company.description ?? '').trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.lg,
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.lg,
            border: Border.all(color: AppColors.neutral200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38.w,
                    height: 38.w,
                    decoration: BoxDecoration(
                      color: AppColors.accentLight,
                      borderRadius: AppRadius.sm,
                    ),
                    child: Icon(
                      Icons.business_center_rounded,
                      color: AppColors.accent,
                      size: 20.sp,
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(company.name, style: AppTextStyles.labelMedium),
                  ),
                  InkWell(
                    borderRadius: AppRadius.full,
                    onTap: onDelete,
                    child: Padding(
                      padding: EdgeInsets.all(4.w),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 18.sp,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Icon(
                    Icons.open_in_new_rounded,
                    size: 18.sp,
                    color: AppColors.primary,
                  ),
                ],
              ),
              if (description.isNotEmpty) ...[
                SizedBox(height: AppSpacing.sm),
                Text(
                  description,
                  style: AppTextStyles.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddPressed});

  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.business_outlined,
            color: AppColors.neutral400,
            size: 44.sp,
          ),
          SizedBox(height: AppSpacing.sm),
          Text('No companies yet', style: AppTextStyles.headlineSmall),
          SizedBox(height: 4.h),
          Text(
            'Create your first company to start tracking trips.',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.base),
          AppButton(
            text: 'Add Company',
            icon: Icons.add_rounded,
            onPressed: onAddPressed,
          ),
        ],
      ),
    );
  }
}

String _companySortLabel(CompanySortOption option) {
  switch (option) {
    case CompanySortOption.nameAZ:
      return 'Name A-Z';
    case CompanySortOption.nameZA:
      return 'Name Z-A';
    case CompanySortOption.tripsHighToLow:
      return 'Most trips';
    case CompanySortOption.transactionsHighToLow:
      return 'Most transactions';
  }
}

String _companyActivityFilterLabel(CompanyActivityFilter filter) {
  switch (filter) {
    case CompanyActivityFilter.all:
      return 'All companies';
    case CompanyActivityFilter.withTrips:
      return 'With trips';
    case CompanyActivityFilter.withTransactions:
      return 'With transactions';
    case CompanyActivityFilter.withBoth:
      return 'With both';
  }
}
