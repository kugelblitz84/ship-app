import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../../../modules/ship/models/ship_model.dart';

class FirestoreShipService extends GetxService {
  FirestoreShipService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _shipsCollection {
    final uid = _requireUid();
    return _firestore.collection('users').doc(uid).collection('ships');
  }

  CollectionReference<Map<String, dynamic>> get _tripsCollection {
    final uid = _requireUid();
    return _firestore.collection('users').doc(uid).collection('trips');
  }

  Future<void> addShip({
    required String shipName,
    String? licenseNumber,
  }) async {
    final normalizedName = _normalizeNameKey(shipName, entityLabel: 'Ship');
    final shipDoc = _shipsCollection.doc(normalizedName);
    final sanitizedLicenseNumber = (licenseNumber ?? '').trim();
    await _firestore.runTransaction((transaction) async {
      final existingDoc = await transaction.get(shipDoc);
      if (existingDoc.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'already-exists',
          message: 'A ship with this name already exists.',
        );
      }

      transaction.set(shipDoc, {
        'name': shipName.trim(),
        'licenseNumber': sanitizedLicenseNumber,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<List<ShipModel>> getShips() async {
    final snapshot = await _shipsCollection.get();
    final ships =
        snapshot.docs.map((doc) => ShipModel.fromMap(doc.data())).toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    return ships;
  }

  Future<void> updateShipDetails({
    required String shipName,
    String? licenseNumber,
  }) async {
    final shipDoc = _shipsCollection.doc(
      _normalizeNameKey(shipName, entityLabel: 'Ship'),
    );

    await _firestore.runTransaction((transaction) async {
      final existingDoc = await transaction.get(shipDoc);
      if (!existingDoc.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'not-found',
          message: 'Ship not found.',
        );
      }

      transaction.update(shipDoc, {
        'licenseNumber': (licenseNumber ?? '').trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> deleteShip({required String shipName}) async {
    final normalizedName = _normalizeNameKey(shipName, entityLabel: 'Ship');
    final shipDoc = _shipsCollection.doc(normalizedName);

    await _firestore.runTransaction((transaction) async {
      final existingDoc = await transaction.get(shipDoc);
      if (!existingDoc.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'not-found',
          message: 'Ship not found.',
        );
      }

      final tripsSnapshot = await _tripsCollection.get();
      final hasLinkedTrips = tripsSnapshot.docs.any((tripDoc) {
        final tripShipName =
            (tripDoc.data()['companyAndShipInfo']?['shipName'] ?? '')
                .toString();
        final normalizedTripShipName = tripShipName
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r'\s+'), ' ');
        return normalizedTripShipName == normalizedName;
      });

      if (hasLinkedTrips) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'failed-precondition',
          message: 'Cannot delete ship with existing trips.',
        );
      }

      transaction.delete(shipDoc);
    });
  }

  String _normalizeNameKey(String input, {required String entityLabel}) {
    final normalized = input.trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    if (normalized.isEmpty) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'invalid-argument',
        message: '$entityLabel name is required.',
      );
    }

    if (normalized == '.' || normalized == '..') {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'invalid-argument',
        message: '$entityLabel name is invalid.',
      );
    }

    if (normalized.contains('/')) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'invalid-argument',
        message: '$entityLabel name cannot contain /.',
      );
    }

    return normalized;
  }

  String _requireUid() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unauthenticated',
        message: 'User must be authenticated.',
      );
    }
    return uid;
  }
}
