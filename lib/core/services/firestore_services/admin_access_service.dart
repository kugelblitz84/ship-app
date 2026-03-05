import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../firebase_auth_service.dart';

class AdminAccessService extends GetxService {
  AdminAccessService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final AuthService _auth = Get.find<AuthService>();

  final RxBool _isAdmin = false.obs;

  bool get isAdmin => _isAdmin.value;

  Future<bool> refreshCurrentUserRole() async {
    final userEmail = _auth.currentUser?.email;
    final hasAdminAccess = await checkByEmail(userEmail);
    _isAdmin.value = hasAdminAccess;
    return hasAdminAccess;
  }

  Future<bool> checkByEmail(String? email) async {
    final rawEmail = email?.trim();
    if (rawEmail == null || rawEmail.isEmpty) {
      return false;
    }

    final normalizedEmail = rawEmail.toLowerCase();
    final doc = await _firestore
        .collection('admins')
        .doc(normalizedEmail)
        .get();
    if (doc.exists && doc.data() != null) {
      final data = doc.data();
      return data?['isAdmin'] == true;
    }

    if (normalizedEmail != rawEmail) {
      final fallbackDoc = await _firestore
          .collection('admins')
          .doc(rawEmail)
          .get();
      if (fallbackDoc.exists && fallbackDoc.data() != null) {
        final data = fallbackDoc.data();
        return data?['isAdmin'] == true;
      }
    }

    return false;
  }

  void clear() {
    _isAdmin.value = false;
  }
}
