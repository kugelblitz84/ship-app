import '../../trip/models/trip_model.dart';
import '../../Transactions/models/transaction_model.dart';
import 'user_profile_model.dart';

class HomeModel {
  UserProfileModel profile;
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

  String get name => profile.username;
  String get organization => profile.organization;
  String get email => profile.email;
  String get phone => profile.phone;
  bool get isVerified => profile.isVerified;

  HomeModel({
    UserProfileModel? profile,
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
  }) : profile = profile ?? const UserProfileModel(),
       recentTrips = recentTrips ?? const <TripModel>[],
       recentTransactions = recentTransactions ?? const <TransactionModel>[];

  factory HomeModel.fromMap(Map<String, dynamic> map) {
    return HomeModel(
      profile: UserProfileModel.fromMap(map),
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
    UserProfileModel? profile,
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
    bool? isVerified,
    List<TripModel>? recentTrips,
    List<TransactionModel>? recentTransactions,
  }) {
    var nextProfile = profile ?? this.profile;
    if (name != null ||
        organization != null ||
        email != null ||
        phone != null ||
        isVerified != null) {
      nextProfile = nextProfile.copyWith(
        username: name,
        organization: organization,
        email: email,
        phone: phone,
        isVerified: isVerified,
      );
    }

    return HomeModel(
      profile: nextProfile,
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
