class UserProfileModel {
  final String uid;
  final String username;
  final String organization;
  final String phone;
  final String email;
  final bool isVerified;
  final bool isBlocked;

  const UserProfileModel({
    this.uid = '',
    this.username = '',
    this.organization = '',
    this.phone = '',
    this.email = '',
    this.isVerified = false,
    this.isBlocked = false,
  });

  factory UserProfileModel.fromMap(Map<String, dynamic> map) {
    return UserProfileModel(
      uid: _readString(map['uid']),
      username: _readString(map['username']),
      organization: _readString(map['org']),
      phone: _readString(map['phone']),
      email: _readString(map['email']),
      isVerified: _readBool(map['isVerified']),
      isBlocked: _readBool(map['isBlocked']),
    );
  }

  UserProfileModel copyWith({
    String? uid,
    String? username,
    String? organization,
    String? phone,
    String? email,
    bool? isVerified,
    bool? isBlocked,
  }) {
    return UserProfileModel(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      organization: organization ?? this.organization,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      isVerified: isVerified ?? this.isVerified,
      isBlocked: isBlocked ?? this.isBlocked,
    );
  }

  static String _readString(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  static bool _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }
    return false;
  }
}
