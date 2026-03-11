import 'package:get/get.dart';

import '../firebase_auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../modules/home/model/user_profile_model.dart';

class FirestoreUserService extends GetxService {
  FirestoreUserService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;
  final auth = Get.find<AuthService>();

  String get _currentUid {
    final user = auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user found.');
    }
    return user.uid;
  }

  Future<void> saveUserDetails(
    String username,
    String org,
    String phone,
  ) async {
    final user = auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user found.');
    }

    final userRef = _firestore.collection('users').doc(_currentUid);

    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(userRef);
      final existingData = snapshot.data();

      final details = <String, dynamic>{
        'uid': user.uid,
        'username': username,
        'org': org,
        'phone': phone,
        'email': user.email ?? '',
      };

      if (!snapshot.exists || existingData?['isBlocked'] == null) {
        details['isBlocked'] = false;
      }
      if (!snapshot.exists || existingData?['isVerified'] == null) {
        details['isVerified'] = false;
      }

      tx.set(userRef, details, SetOptions(merge: true));
    });
  }

  Future<void> ensureCurrentUserAccessFlags({required bool isVerified}) async {
    final user = auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user found.');
    }

    final userRef = _firestore.collection('users').doc(_currentUid);
    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(userRef);
      final existingData = snapshot.data();

      final payload = <String, dynamic>{
        'uid': user.uid,
        'email': user.email ?? '',
        'isVerified': isVerified,
      };

      if (!snapshot.exists || existingData?['isBlocked'] == null) {
        payload['isBlocked'] = false;
      }

      tx.set(userRef, payload, SetOptions(merge: true));
    });
  }

  Future<void> setCurrentUserVerified(bool isVerified) async {
    final user = auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user found.');
    }

    await _firestore.collection('users').doc(_currentUid).set({
      'uid': user.uid,
      'email': user.email ?? '',
      'isVerified': isVerified,
    }, SetOptions(merge: true));
  }

  Future<UserProfileModel> getUserDetails() async {
    final snapshot = await _firestore
        .collection('users')
        .doc(_currentUid)
        .get();
    return UserProfileModel.fromMap(snapshot.data() ?? <String, dynamic>{});
  }

  Future<void> updateCurrentUserProfile({
    required String username,
    required String organization,
  }) async {
    final user = auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user found.');
    }

    await _firestore.collection('users').doc(_currentUid).set({
      'uid': user.uid,
      'email': user.email ?? '',
      'username': username,
      'org': organization,
    }, SetOptions(merge: true));
  }
}
