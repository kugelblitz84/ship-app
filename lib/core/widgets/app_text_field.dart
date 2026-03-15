import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../themes/themes.dart';

/// A premium text field with icon support, password toggle, and elegant styling.
class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool readOnly;
  final int maxLines;

  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.prefixIcon,
    this.suffix,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.focusNode,
    this.autofocus = false,
    this.readOnly = false,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8.h),
        ],
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          validator: validator,
          onChanged: onChanged,
          focusNode: focusNode,
          autofocus: autofocus,
          readOnly: readOnly,
          maxLines: maxLines,
          style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon != null
                ? Padding(
                    padding: EdgeInsets.only(left: 14.w, right: 10.w),
                    child: Icon(prefixIcon, size: 20.sp),
                  )
                : null,
            prefixIconConstraints: prefixIcon != null
                ? BoxConstraints(minHeight: 20.sp, minWidth: 44.w)
                : null,
            suffixIcon: suffix != null
                ? Padding(
                    padding: EdgeInsets.only(right: 8.w),
                    child: suffix,
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

/// Text field specifically designed for passwords with visibility toggle.
class AppPasswordField extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final FormFieldValidator<String>? validator;
  final TextInputAction? textInputAction;

  const AppPasswordField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.validator,
    this.textInputAction,
  });

  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: widget.controller,
      label: widget.label,
      hint: widget.hint ?? 'Enter your password',
      prefixIcon: Icons.lock_outline_rounded,
      obscureText: _obscure,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      suffix: GestureDetector(
        onTap: () => setState(() => _obscure = !_obscure),
        child: Icon(
          _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          size: 20.sp,
          color: AppColors.neutral400,
        ),
      ),
    );
  }
}
