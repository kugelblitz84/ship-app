import 'package:firebase_auth/firebase_auth.dart';
import 'package:urgent/core/widgets/app_snackbar.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:mailer/mailer.dart';
import 'connectivity_watcher_service.dart';
import '../themes/themes.dart';

class ApiErrorHandler {
  static bool get _shouldSuppressOfflineSnackbar {
    if (!Get.isRegistered<ConnectivityWatcherService>()) {
      return false;
    }
    return Get.find<ConnectivityWatcherService>().isOffline;
  }

  static Future<ApiResponse<T>> call<T>(
    Future<T> Function() apiCall, {
    bool showErrorSnackbar = true,
    String fallbackMessage = 'Something went wrong',
  }) async {
    try {
      final data = await apiCall();
      return ApiResponse<T>(data: data, isSuccess: true);
    } on FirebaseAuthException catch (e) {
      final errorMsg = switch (e.code) {
        "wrong-password" => "Incorrect password",
        "invalid-credential" => "Incorrect password",
        "user-not-found" => "User not found",
        "invalid-email" => "Invalid email",
        "email-already-in-use" => "Email already registered",
        "weak-password" => "Password must be at least 6 characters",
        "operation-not-allowed" => "Email signup is disabled",
        "network-request-failed" => "No internet connection",
        _ => e.message ?? "Failed",
      };
      if (showErrorSnackbar && !_shouldSuppressOfflineSnackbar) {
        showAppSnackbar(
          'Error',
          errorMsg,
          backgroundColor: AppColors.errorLight,
          colorText: AppColors.error,
        );
      }
      return ApiResponse<T>(error: errorMsg, isSuccess: false);
    } on FirebaseException catch (e) {
      final errorMsg = switch (e.code) {
        'permission-denied' =>
          'You do not have permission to perform this action',
        'unavailable' => 'Service is currently unavailable. Please try again',
        'not-found' => 'Requested data not found',
        'already-exists' => 'This item already exists',
        'failed-precondition' => e.message ?? 'Action cannot be completed',
        'invalid-argument' => e.message ?? 'Invalid input provided',
        _ => e.message ?? fallbackMessage,
      };
      if (showErrorSnackbar && !_shouldSuppressOfflineSnackbar) {
        showAppSnackbar('Error', errorMsg);
      }
      return ApiResponse<T>(error: errorMsg, isSuccess: false);
    } catch (err) {
      debugPrint('API call unexpected error: ${err.toString()}');
      if (showErrorSnackbar && !_shouldSuppressOfflineSnackbar) {
        showAppSnackbar('Error', fallbackMessage);
      }
      return ApiResponse<T>(error: fallbackMessage, isSuccess: false);
    }
  }
}

class ApiResponse<T> {
  final T? data;
  final String? error;
  final bool isSuccess;
  ApiResponse({this.data, this.error, required this.isSuccess});
}

class OtpMailerErrorHandler {
  static bool get _shouldSuppressOfflineSnackbar {
    if (!Get.isRegistered<ConnectivityWatcherService>()) {
      return false;
    }
    return Get.find<ConnectivityWatcherService>().isOffline;
  }

  static Future<ApiResponse<T>> call<T>(
    Future<T> Function() operation, {
    bool showErrorSnackbar = true,
    String fallbackMessage = 'Failed to process OTP request',
  }) async {
    try {
      final data = await operation();
      return ApiResponse<T>(data: data, isSuccess: true);
    } on MailerException catch (e) {
      final detailedProblems = e.problems
          .map((problem) => problem.toString())
          .join('\n');
      final errorMsg = detailedProblems.isEmpty
          ? 'Failed to send OTP email.\nDetails: ${e.toString()}'
          : 'Failed to send OTP email.\nDetails:\n$detailedProblems';

      debugPrint('OTP mailer failure: ${e.toString()}');
      if (detailedProblems.isNotEmpty) {
        debugPrint('OTP mailer problems:\n$detailedProblems');
      }

      if (showErrorSnackbar && !_shouldSuppressOfflineSnackbar) {
        showAppSnackbar(
          'OTP Error',
          errorMsg,
          backgroundColor: AppColors.errorLight,
          colorText: AppColors.error,
        );
      }
      return ApiResponse<T>(error: errorMsg, isSuccess: false);
    } catch (e, stackTrace) {
      final errorMsg = '$fallbackMessage\nDetails: ${e.toString()}';
      debugPrint('OTP handler unexpected error: ${e.toString()}');
      debugPrintStack(stackTrace: stackTrace);

      if (showErrorSnackbar && !_shouldSuppressOfflineSnackbar) {
        showAppSnackbar(
          'OTP Error',
          errorMsg,
          backgroundColor: AppColors.errorLight,
          colorText: AppColors.error,
        );
      }
      return ApiResponse<T>(error: errorMsg, isSuccess: false);
    }
  }
}
