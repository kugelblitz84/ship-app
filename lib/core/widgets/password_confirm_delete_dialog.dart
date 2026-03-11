import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../themes/themes.dart';

Future<bool> showPasswordConfirmDeletionDialog({
  required BuildContext context,
  required String title,
  required String message,
  required Future<bool> Function(String password) onConfirm,
}) async {
  final passwordController = TextEditingController();
  var isSubmitting = false;
  final dialogMaxWidth = Get.width.clamp(320.0, 560.0);

  final deleted =
      await Get.dialog<bool>(
        StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: dialogMaxWidth,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(message),
                      SizedBox(height: AppSpacing.base),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        enabled: !isSubmitting,
                        decoration: const InputDecoration(
                          hintText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () {
                          if (Get.isDialogOpen ?? false) {
                            Get.back(result: false);
                          }
                        },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          setState(() => isSubmitting = true);
                          final success = await onConfirm(
                            passwordController.text,
                          );

                          if (!success) {
                            if (Get.isDialogOpen ?? false) {
                              setState(() => isSubmitting = false);
                            }
                            return;
                          }

                          if (Get.isDialogOpen ?? false) {
                            Get.back(result: true);
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Delete'),
                ),
              ],
            );
          },
        ),
        barrierDismissible: !isSubmitting,
      ) ??
      false;

  passwordController.dispose();
  return deleted;
}
