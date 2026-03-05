import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../core/themes/themes.dart';
import '../../../core/widgets/widgets.dart';
import 'post_verification_details_controller.dart';

class PostVerificationDetailsView
    extends GetView<PostVerificationDetailsController> {
  const PostVerificationDetailsView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSliverScaffold(
      title: 'Complete Profile',
      subtitle: 'Add your details to continue',
      icon: Icons.badge_outlined,
      maxContentWidth: 560,
      child: Form(
        key: controller.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 8.h),
            const AuthHeader(
              icon: Icons.badge_outlined,
              title: 'Complete Your Profile',
              subtitle:
                  'Now add your personal and organization details to continue.',
            ),
            AppTextField(
              controller: controller.userNameController,
              label: 'Full Name',
              hint: 'John Doe',
              prefixIcon: Icons.person_outline_rounded,
              textInputAction: TextInputAction.next,
              validator: controller.requiredValidator('Full name'),
            ),
            SizedBox(height: AppSpacing.base),
            AppTextField(
              controller: controller.organizationNameController,
              label: 'Organization',
              hint: 'Your company or organization',
              prefixIcon: Icons.business_outlined,
              textInputAction: TextInputAction.next,
              validator: controller.requiredValidator('Organization name'),
            ),
            SizedBox(height: AppSpacing.base),
            AppTextField(
              controller: controller.phoneController,
              label: 'Phone Number',
              hint: '+1 (555) 000-0000',
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              validator: controller.requiredValidator('Phone number'),
            ),
            SizedBox(height: AppSpacing.xxl),
            Obx(
              () => AppButton(
                text: 'Continue',
                icon: Icons.arrow_forward_rounded,
                onPressed: controller.onContinuePressed,
                isLoading: controller.isLoading,
              ),
            ),
            SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}
