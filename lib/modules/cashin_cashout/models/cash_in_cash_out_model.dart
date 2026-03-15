import 'package:cloud_firestore/cloud_firestore.dart';

class CashInCashOutModel {
  CashInCashOutModel({
    required this.entryId,
    required this.flowType,
    required this.transactionType,
    required this.amount,
    required this.date,
    this.note,
    this.createdAt,
  });

  final String entryId;
  final String flowType; // cash-in, cash-out
  final String transactionType;
  final String amount;
  final String date;
  final String? note;
  final DateTime? createdAt;

  factory CashInCashOutModel.fromMap(Map<String, dynamic> map) {
    String readString(dynamic value) {
      if (value == null) return '';
      return value.toString();
    }

    DateTime? parseCreatedAt(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    final flowType = readString(map['flowType']).trim().toLowerCase();
    final normalizedType = flowType == 'cash-out' || flowType == 'cash-in'
        ? flowType
        : 'cash-in';

    return CashInCashOutModel(
      entryId: readString(map['entryId']).trim(),
      flowType: normalizedType,
      transactionType: _normalizeTransactionType(map['transactionType']),
      amount: readString(map['amount']).trim().isEmpty
          ? '0'
          : readString(map['amount']).trim(),
      date: readString(map['date']).trim(),
      note: readString(map['note']).trim().isEmpty
          ? null
          : readString(map['note']).trim(),
      createdAt: parseCreatedAt(map['createdAt']),
    );
  }

  bool get isCashIn => flowType.trim().toLowerCase() == 'cash-in';

  bool get isCashOut => flowType.trim().toLowerCase() == 'cash-out';

  String get flowTypeLabel => isCashOut ? 'Cash Out' : 'Cash In';

  String get transactionTypeLabel {
    final normalized = transactionType.trim().toLowerCase();
    if (normalized.isEmpty) {
      return 'N/A';
    }

    return normalized
        .split(RegExp(r'[-_\s]+'))
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }

  String get signedAmountLabel {
    final amountValue = _toDouble(amount);
    final prefix = isCashOut ? '-' : '+';
    return '$prefix${amountValue.toInt()}';
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) {
      final sanitized = value.replaceAll(',', '').trim();
      if (sanitized.isEmpty) return 0;
      return double.tryParse(sanitized) ?? 0;
    }
    return 0;
  }

  static String _normalizeTransactionType(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    if (normalized.isEmpty) {
      return 'cash';
    }
    return normalized;
  }
}
