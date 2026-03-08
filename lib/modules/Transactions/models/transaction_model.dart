import 'package:flutter/foundation.dart';

class TransactionModel {
  String transactionId;
  String transactionType; //payment, expenses
  String expenseSource; //company, main-balance
  CompanyAndShipInfo companyAndShipInfo;
  String tripId;
  String tripFrom;
  String tripTo;
  String? description;
  String amount;
  // Kept for compatibility, now represent company-level snapshots at payment time.
  String totalPrice;
  String amountDue;
  final String date;
  String type;

  TransactionModel({
    required this.transactionId,
    required this.transactionType,
    this.expenseSource = 'company',
    required this.companyAndShipInfo,
    this.tripId = '',
    this.tripFrom = '',
    this.tripTo = '',
    this.description,
    required this.amount,
    required this.totalPrice,
    required this.amountDue,
    required this.date,
    required this.type,
  });

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    final companyAndShipInfoValue = map['companyAndShipInfo'];
    if (companyAndShipInfoValue is! Map<String, dynamic>) {
      debugPrint(
        'TransactionModel.fromMap: missing/invalid companyAndShipInfo for transactionId=${map['transactionId'] ?? ''}',
      );
    }

    final companyAndShipInfoMap =
        companyAndShipInfoValue is Map<String, dynamic>
        ? companyAndShipInfoValue
        : <String, dynamic>{};

    final tripInfoValue = map['tripInfo'];
    final tripInfoMap = tripInfoValue is Map<String, dynamic>
        ? tripInfoValue
        : <String, dynamic>{};

    String readString(dynamic value) {
      if (value == null) return '';
      return value.toString();
    }

    double parseAmount(dynamic value) {
      final raw = readString(value).replaceAll(',', '').trim();
      if (raw.isEmpty) return 0;
      return double.tryParse(raw) ?? 0;
    }

    String formatAmount(double value) {
      if (value % 1 == 0) {
        return value.toInt().toString();
      }
      return value.toStringAsFixed(2);
    }

    final companyName = readString(companyAndShipInfoMap['companyName']).trim();
    final shipName = readString(companyAndShipInfoMap['shipName']).trim();
    final tripFromValue = readString(tripInfoMap['from']).trim().isNotEmpty
        ? readString(tripInfoMap['from']).trim()
        : readString(map['tripFrom']).trim().isNotEmpty
        ? readString(map['tripFrom']).trim()
        : readString(map['from']).trim();
    final tripToValue = readString(tripInfoMap['to']).trim().isNotEmpty
        ? readString(tripInfoMap['to']).trim()
        : readString(map['tripTo']).trim().isNotEmpty
        ? readString(map['tripTo']).trim()
        : readString(map['to']).trim();
    final tripIdValue = readString(map['tripId']).trim();

    if (companyName.isEmpty) {
      debugPrint(
        'TransactionModel.fromMap: empty company/ship name for transactionId=${readString(map['transactionId'])} (companyName="$companyName", shipName="$shipName")',
      );
    }

    if (tripIdValue.isNotEmpty &&
        (tripFromValue.isEmpty || tripToValue.isEmpty)) {
      debugPrint(
        'TransactionModel.fromMap: missing trip route for transactionId=${readString(map['transactionId'])} (from="$tripFromValue", to="$tripToValue")',
      );
    }

    final paidAmount = parseAmount(map['amount']);
    final rawTotalPrice = parseAmount(map['totalPrice']);
    final amountDueRawValue = map['amountDue'];
    final hasAmountDue = readString(amountDueRawValue).trim().isNotEmpty;
    final rawAmountDue = parseAmount(amountDueRawValue);

    var resolvedTotalPrice = rawTotalPrice;
    if (resolvedTotalPrice <= 0) {
      resolvedTotalPrice = paidAmount + rawAmountDue;
    }
    if (resolvedTotalPrice <= 0) {
      resolvedTotalPrice = paidAmount;
    }

    var resolvedAmountDue = rawAmountDue;
    if (!hasAmountDue) {
      resolvedAmountDue = resolvedTotalPrice - paidAmount;
    }

    return TransactionModel(
      transactionId: readString(map['transactionId']),
      transactionType: readString(map['transactionType']).trim().isEmpty
          ? 'payment'
          : readString(map['transactionType']).trim().toLowerCase(),
      expenseSource: readString(map['expenseSource']).trim().isEmpty
          ? 'company'
          : readString(map['expenseSource']).trim().toLowerCase(),
      companyAndShipInfo: CompanyAndShipInfo(
        companyName: companyName,
        shipName: shipName,
      ),
      tripId: tripIdValue,
      tripFrom: tripFromValue,
      tripTo: tripToValue,
      description: readString(map['description']),
      amount: readString(map['amount']).isEmpty
          ? '0'
          : readString(map['amount']),
      totalPrice: formatAmount(resolvedTotalPrice),
      amountDue: formatAmount(resolvedAmountDue),
      date: readString(map['date']),
      type: readString(map['type']),
    );
  }

  String get companyName => companyAndShipInfo.companyName;

  String get normalizedTransactionType => transactionType.trim().toLowerCase();

  String get normalizedExpenseSource => expenseSource.trim().toLowerCase();

  bool get isExpense => normalizedTransactionType == 'expenses';

  String get transactionTypeLabel {
    if (normalizedTransactionType == 'expenses') {
      return 'Expenses';
    }
    if (normalizedTransactionType == 'payment') {
      return 'Payment';
    }
    if (normalizedTransactionType.isEmpty) {
      return 'Payment';
    }

    return normalizedTransactionType[0].toUpperCase() +
        normalizedTransactionType.substring(1);
  }

  String get expenseSourceLabel {
    final normalized = normalizedExpenseSource;
    if (normalized == 'main-balance') {
      return 'From Main Balance';
    }
    if (normalized == 'company') {
      return 'Company Due';
    }
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

  String get expenseSourceDisplayLabel =>
      isExpense ? expenseSourceLabel : 'N/A';

  bool get hasTrip =>
      tripId.trim().isNotEmpty ||
      (tripFrom.trim().isNotEmpty && tripTo.trim().isNotEmpty);

  String get routeLabel {
    final from = tripFrom.trim();
    final to = tripTo.trim();

    if (from.isNotEmpty && to.isNotEmpty) {
      return '$from - $to';
    }

    final id = tripId.trim();
    if (id.isNotEmpty) {
      return 'Trip: $id';
    }

    return 'No Route';
  }
}

class CompanyAndShipInfo {
  // Names are persisted as the source of identity.
  //company is mandatory but ship is optional.
  String companyName;
  String shipName;

  CompanyAndShipInfo({required this.companyName, required this.shipName});
}
