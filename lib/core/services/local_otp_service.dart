import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

import '../utils/util.dart';

enum OtpValidationStatus { success, invalid, expired, noOtp, emailMismatch }

class OtpValidationResult {
  const OtpValidationResult(this.status);

  final OtpValidationStatus status;

  bool get isSuccess => status == OtpValidationStatus.success;
}

class LocalOtpService extends GetxService {
  static const _otpKey = 'local_otp_code';
  static const _otpExpiryKey = 'local_otp_expiry_ms';
  static const _otpEmailKey = 'local_otp_email';
  static const _otpTtlMinutes = 5;

  static const _smtpEmail = 'shipdata.360@gmail.com';
  static const _smtpAppPassword = 'eiug ybms bsyv tqkz';

  final FlutterSecureStorage _storage;

  LocalOtpService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  Future<void> issueOtp({required String email}) async {
    final otp = Util.generateOtp();
    final expiresAt = DateTime.now()
        .add(const Duration(minutes: _otpTtlMinutes))
        .millisecondsSinceEpoch;

    await _persistOtp(email: email, otp: otp, expiresAt: expiresAt);
    await _sendOtpEmail(email: email, otp: otp);
  }

  Future<OtpValidationResult> verifyOtp({
    required String email,
    required String enteredOtp,
  }) async {
    final storedOtp = await _storage.read(key: _otpKey);
    final storedEmail = await _storage.read(key: _otpEmailKey);
    final storedExpiryRaw = await _storage.read(key: _otpExpiryKey);

    if (storedOtp == null || storedEmail == null || storedExpiryRaw == null) {
      return const OtpValidationResult(OtpValidationStatus.noOtp);
    }

    if (storedEmail.toLowerCase() != email.toLowerCase()) {
      return const OtpValidationResult(OtpValidationStatus.emailMismatch);
    }

    final storedExpiry = int.tryParse(storedExpiryRaw);
    if (storedExpiry == null ||
        DateTime.now().millisecondsSinceEpoch > storedExpiry) {
      await clearOtp();
      return const OtpValidationResult(OtpValidationStatus.expired);
    }

    if (storedOtp != enteredOtp) {
      return const OtpValidationResult(OtpValidationStatus.invalid);
    }

    await clearOtp();
    return const OtpValidationResult(OtpValidationStatus.success);
  }

  Future<void> clearOtp() async {
    await _storage.delete(key: _otpKey);
    await _storage.delete(key: _otpExpiryKey);
    await _storage.delete(key: _otpEmailKey);
  }

  Future<void> _persistOtp({
    required String email,
    required String otp,
    required int expiresAt,
  }) async {
    await _storage.write(key: _otpKey, value: otp);
    await _storage.write(key: _otpEmailKey, value: email);
    await _storage.write(key: _otpExpiryKey, value: expiresAt.toString());
  }

  Future<void> _sendOtpEmail({
    required String email,
    required String otp,
  }) async {
    final smtpServer = gmail(_smtpEmail, _smtpAppPassword);

    final message = Message()
      ..from = Address(_smtpEmail, 'Urgent Security')
      ..recipients.add(email)
      ..subject = 'Your Urgent OTP Code'
      ..text =
          'Your OTP is: $otp\n\nThis code expires in $_otpTtlMinutes minutes.';

    await send(message, smtpServer);
  }
}
