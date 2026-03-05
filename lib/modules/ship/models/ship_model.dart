import 'package:flutter/foundation.dart';

class ShipModel {
  // Name is the display identity.
  String name;
  String? licenseNumber;

  ShipModel({required this.name, this.licenseNumber});

  factory ShipModel.fromMap(Map<String, dynamic> map) {
    final name = (map['name'] as String?)?.trim() ?? '';

    if (name.isEmpty) {
      debugPrint('ShipModel.fromMap: missing/empty name field.');
    }

    return ShipModel(
      name: name,
      licenseNumber: map['licenseNumber'] as String?,
    );
  }
}
