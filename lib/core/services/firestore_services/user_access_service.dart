import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../firebase_auth_service.dart';
import 'admin_access_service.dart';

class AdminUserSummary {
  AdminUserSummary({
    required this.uid,
    required this.name,
    required this.organization,
    required this.email,
    required this.isBlocked,
    required this.lifetimeEarnings,
  });

  final String uid;
  final String name;
  final String organization;
  final String email;
  final bool isBlocked;
  final double lifetimeEarnings;
}

class UserAccessService extends GetxService {
  UserAccessService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final AuthService _auth = Get.find<AuthService>();
  final AdminAccessService _adminAccess = Get.find<AdminAccessService>();

  DocumentReference<Map<String, dynamic>> _userRef(String uid) {
    return _firestore.collection('users').doc(uid);
  }

  Future<bool> isCurrentUserBlocked(String uid) async {
    if (uid.isEmpty) return false;

    final directSnapshot = await _userRef(uid).get();
    if (directSnapshot.exists) {
      return _isBlockedValue(directSnapshot.data()?['isBlocked']);
    }

    try {
      final byUidField = await _firestore
          .collection('users')
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get();
      if (byUidField.docs.isNotEmpty) {
        return _isBlockedValue(byUidField.docs.first.data()['isBlocked']);
      }

      final currentEmail = _auth.currentUser?.email?.trim();
      if (currentEmail != null && currentEmail.isNotEmpty) {
        final byEmail = await _firestore
            .collection('users')
            .where('email', isEqualTo: currentEmail)
            .limit(1)
            .get();
        if (byEmail.docs.isNotEmpty) {
          return _isBlockedValue(byEmail.docs.first.data()['isBlocked']);
        }
      }
    } on FirebaseException {
      return false;
    }

    return false;
  }

  Future<List<AdminUserSummary>> getAllUsersWithLifetimeEarnings() async {
    await _assertAdminAccess();

    final usersSnapshot = await _firestore.collection('users').get();
    final List<AdminUserSummary> summaries = [];

    for (final userDoc in usersSnapshot.docs) {
      final userData = userDoc.data();
      final txSnapshot = await userDoc.reference
          .collection('transactions')
          .get();

      final lifetimeEarnings = _calculateLifetimeEarnings(
        txSnapshot.docs.map((doc) => doc.data()).toList(),
      );
      final canonicalUid = (userData['uid'] ?? userDoc.id).toString();

      summaries.add(
        AdminUserSummary(
          uid: canonicalUid,
          name: (userData['username'] ?? '').toString(),
          organization: (userData['org'] ?? '').toString(),
          email: (userData['email'] ?? '').toString(),
          isBlocked: _isBlockedValue(userData['isBlocked']),
          lifetimeEarnings: lifetimeEarnings,
        ),
      );
    }

    summaries.sort((a, b) {
      final left = (a.name.isNotEmpty ? a.name : a.email).toLowerCase();
      final right = (b.name.isNotEmpty ? b.name : b.email).toLowerCase();
      return left.compareTo(right);
    });

    return summaries;
  }

  Future<void> setUserBlocked({
    required String userId,
    required bool isBlocked,
    String? email,
  }) async {
    await _assertAdminAccess();

    final currentUid = _auth.currentUser?.uid;
    if (currentUid != null && currentUid == userId) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'failed-precondition',
        message: 'Admins cannot restrict their own account.',
      );
    }

    final userDocRef = await _resolveUserDocForWrite(
      userId: userId,
      email: email,
    );

    await userDocRef.set({
      'isBlocked': isBlocked,
      'uid': userId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<DocumentReference<Map<String, dynamic>>> _resolveUserDocForWrite({
    required String userId,
    String? email,
  }) async {
    final directRef = _userRef(userId);
    final directSnapshot = await directRef.get();
    if (directSnapshot.exists) return directRef;

    final byUidField = await _firestore
        .collection('users')
        .where('uid', isEqualTo: userId)
        .limit(1)
        .get();
    if (byUidField.docs.isNotEmpty) {
      return byUidField.docs.first.reference;
    }

    final normalizedEmail = email?.trim();
    if (normalizedEmail != null && normalizedEmail.isNotEmpty) {
      final byEmail = await _firestore
          .collection('users')
          .where('email', isEqualTo: normalizedEmail)
          .limit(1)
          .get();
      if (byEmail.docs.isNotEmpty) {
        return byEmail.docs.first.reference;
      }
    }

    return directRef;
  }

  Future<void> _assertAdminAccess() async {
    final isAdmin = await _adminAccess.refreshCurrentUserRole();
    if (!isAdmin) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Admin access required.',
      );
    }
  }

  double _calculateLifetimeEarnings(List<Map<String, dynamic>> transactions) {
    double total = 0;

    for (final tx in transactions) {
      final category = (tx['transactionType'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final source = (tx['expenseSource'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final amount = _toDouble(tx['amount']);
      if (amount <= 0) continue;

      if (category == 'payment') {
        total += amount;
      } else if (category == 'expenses' && source == 'main-balance') {
        total -= amount;
      }
    }

    return total.clamp(0, double.infinity);
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) {
      final sanitized = value.replaceAll(',', '').trim();
      if (sanitized.isEmpty) return 0;
      return double.tryParse(sanitized) ?? 0;
    }
    return 0;
  }

  bool _isBlockedValue(dynamic value) {
    if (value == true) return true;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }
}
