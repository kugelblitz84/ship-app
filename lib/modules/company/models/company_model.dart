import 'package:flutter/foundation.dart';

class CompanyModel {
  // Name is the display identity.
  String name;
  String? description;
  String? logoUrl;
  String totalAmountBilled;
  String totalAmountReceived;
  String totalAmountDue;
  String? openingDueAmount;
  String? openingDueDate;

  CompanyModel({
    required this.name,
    this.description,
    this.logoUrl,
    this.totalAmountBilled = '0',
    this.totalAmountReceived = '0',
    this.totalAmountDue = '0',
    this.openingDueAmount,
    this.openingDueDate,
  });

  factory CompanyModel.fromMap(Map<String, dynamic> map) {
    String readString(dynamic value) {
      if (value == null) return '';
      return value.toString();
    }

    final name = readString(map['name']).trim();

    if (name.isEmpty) {
      debugPrint('CompanyModel.fromMap: missing/empty name field.');
    }

    return CompanyModel(
      name: name,
      description: readString(map['description']).trim().isEmpty
          ? null
          : readString(map['description']),
      logoUrl: readString(map['logoUrl']).trim().isEmpty
          ? null
          : readString(map['logoUrl']),
      totalAmountBilled: readString(map['totalAmountBilled']).trim().isNotEmpty
          ? readString(map['totalAmountBilled']).trim()
          : '0',
      totalAmountReceived:
          readString(map['totalAmountReceived']).trim().isNotEmpty
          ? readString(map['totalAmountReceived']).trim()
          : '0',
      totalAmountDue: readString(map['totalAmountDue']).trim().isNotEmpty
          ? readString(map['totalAmountDue']).trim()
          : '0',
      openingDueAmount: readString(map['openingDueAmount']).trim().isEmpty
          ? null
          : readString(map['openingDueAmount']).trim(),
      openingDueDate: readString(map['openingDueDate']).trim().isEmpty
          ? null
          : readString(map['openingDueDate']).trim(),
    );
  }
}
