import 'package:get/get.dart';

import '../firebase_auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

      tx.set(userRef, details, SetOptions(merge: true));
    });
  }

  Future<Map<String, dynamic>> getUserDetails() async {
    final snapshot = await _firestore
        .collection('users')
        .doc(_currentUid)
        .get();
    return snapshot.data() ?? <String, dynamic>{};
  }
}
