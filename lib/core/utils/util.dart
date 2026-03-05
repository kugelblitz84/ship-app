import 'dart:math';

class Util {
  static String generateOtp() {
    final random = Random();
    return List.generate(6, (_) => random.nextInt(10)).join();
  }
}
