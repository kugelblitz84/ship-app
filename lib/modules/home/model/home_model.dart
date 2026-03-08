import '../../trip/models/trip_model.dart';
import '../../Transactions/models/transaction_model.dart';

class HomeModel {
  String? name;
  String? organization;
  String? email;
  String? phone;
  int shipCount;
  int companyCount;
  int tripCount;
  int transactionCount;
  int totalFundOwed;
  int totalFundReceived;
  int totalDue;
  int monthlyFundOwed;
  int monthlyFundReceived;
  int monthlyTotalDue;
  List<TripModel> recentTrips;
  List<TransactionModel> recentTransactions;

  HomeModel({
    this.name,
    this.organization,
    this.email,
    this.phone,
    this.shipCount = 0,
    this.companyCount = 0,
    this.tripCount = 0,
    this.transactionCount = 0,
    this.totalFundOwed = 0,
    this.totalFundReceived = 0,
    this.totalDue = 0,
    this.monthlyFundOwed = 0,
    this.monthlyFundReceived = 0,
    this.monthlyTotalDue = 0,
    List<TripModel>? recentTrips,
    List<TransactionModel>? recentTransactions,
  }) : recentTrips = recentTrips ?? const <TripModel>[],
       recentTransactions = recentTransactions ?? const <TransactionModel>[];

  factory HomeModel.fromMap(Map<String, dynamic> map) {
    return HomeModel(
      name: map['username'] as String?,
      organization: map['org'] as String?,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      shipCount: _toInt(map['shipCount']),
      companyCount: _toInt(map['companyCount']),
      tripCount: _toInt(map['tripCount']),
      transactionCount: _toInt(map['transactionCount']),
      totalFundOwed: _toInt(map['totalFundOwed']),
      totalFundReceived: _toInt(map['totalFundReceived']),
      totalDue: _toInt(map['totalDue']),
      monthlyFundOwed: _toInt(map['monthlyFundOwed']),
      monthlyFundReceived: _toInt(map['monthlyFundReceived']),
      monthlyTotalDue: _toInt(map['monthlyTotalDue']),
      recentTrips: _toTripList(map['recentTrips']),
      recentTransactions: _toTransactionList(map['recentTransactions']),
    );
  }

  HomeModel copyWith({
    String? name,
    String? organization,
    String? email,
    String? phone,
    int? shipCount,
    int? companyCount,
    int? tripCount,
    int? transactionCount,
    int? totalFundOwed,
    int? totalFundReceived,
    int? totalDue,
    int? monthlyFundOwed,
    int? monthlyFundReceived,
    int? monthlyTotalDue,
    List<TripModel>? recentTrips,
    List<TransactionModel>? recentTransactions,
  }) {
    return HomeModel(
      name: name ?? this.name,
      organization: organization ?? this.organization,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      shipCount: shipCount ?? this.shipCount,
      companyCount: companyCount ?? this.companyCount,
      tripCount: tripCount ?? this.tripCount,
      transactionCount: transactionCount ?? this.transactionCount,
      totalFundOwed: totalFundOwed ?? this.totalFundOwed,
      totalFundReceived: totalFundReceived ?? this.totalFundReceived,
      totalDue: totalDue ?? this.totalDue,
      monthlyFundOwed: monthlyFundOwed ?? this.monthlyFundOwed,
      monthlyFundReceived: monthlyFundReceived ?? this.monthlyFundReceived,
      monthlyTotalDue: monthlyTotalDue ?? this.monthlyTotalDue,
      recentTrips: recentTrips ?? this.recentTrips,
      recentTransactions: recentTransactions ?? this.recentTransactions,
    );
  }

  static List<TripModel> _toTripList(dynamic value) {
    if (value is List<TripModel>) {
      return List<TripModel>.from(value);
    }
    return const <TripModel>[];
  }

  static List<TransactionModel> _toTransactionList(dynamic value) {
    if (value is List<TransactionModel>) {
      return List<TransactionModel>.from(value);
    }
    return const <TransactionModel>[];
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    if (value is String) {
      final sanitized = value.replaceAll(',', '').trim();
      if (sanitized.isEmpty) return 0;
      return int.tryParse(sanitized) ?? 0;
    }
    return 0;
  }
}
