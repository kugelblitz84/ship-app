import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../../../modules/trip/models/trip_model.dart';

class FirestoreTripService extends GetxService {
  FirestoreTripService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _userDoc {
    final uid = _requireUid();
    return _firestore.collection('users').doc(uid);
  }

  CollectionReference<Map<String, dynamic>> get _tripsCollection =>
      _userDoc.collection('trips');

  CollectionReference<Map<String, dynamic>> get _companiesCollection =>
      _userDoc.collection('companies');

  CollectionReference<Map<String, dynamic>> get _shipsCollection =>
      _userDoc.collection('ships');

  String createTripId() {
    return _tripsCollection.doc().id;
  }

  Future<void> addTrip({required TripModel trip}) async {
    final payload = trip.toMap();
    payload['createdAt'] = FieldValue.serverTimestamp();
    final tripBillAmount = _toDouble(trip.totalBill);

    final tripDoc = _tripsCollection.doc(trip.tripId);
    final companyDoc = await _resolveDocByName(
      collection: _companiesCollection,
      name: trip.companyAndShipInfo.companyName,
      entityLabel: 'Company',
    );
    final shipDoc = await _resolveDocByName(
      collection: _shipsCollection,
      name: trip.companyAndShipInfo.shipName,
      entityLabel: 'Ship',
    );

    await _firestore.runTransaction((transaction) async {
      final companySnapshot = await transaction.get(companyDoc);
      if (!companySnapshot.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'not-found',
          message:
              'Selected company "${trip.companyAndShipInfo.companyName}" does not exist.',
        );
      }

      final shipSnapshot = await transaction.get(shipDoc);
      if (!shipSnapshot.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'not-found',
          message:
              'Selected ship "${trip.companyAndShipInfo.shipName}" does not exist.',
        );
      }

      final companyData = companySnapshot.data() ?? <String, dynamic>{};
      final currentBilled = _toDouble(companyData['totalAmountBilled']);
      final currentDue = _toDouble(companyData['totalAmountDue']);

      transaction.set(tripDoc, payload);
      transaction.update(companyDoc, {
        'totalAmountBilled': _formatAmount(currentBilled + tripBillAmount),
        'totalAmountDue': _formatAmount(currentDue + tripBillAmount),
      });
    });
  }

  Future<List<TripModel>> getTrips() async {
    final snapshot = await _tripsCollection.get();
    return snapshot.docs.map((doc) => TripModel.fromMap(doc.data())).toList();
  }

  Future<List<TripModel>> getTripsSortedByDateDesc() async {
    final trips = await getTrips();
    trips.sort((a, b) => b.date.compareTo(a.date));
    return trips;
  }

  Future<void> updateTrip({
    required TripModel trip,
    required String previousFrom,
    required String previousTo,
    required String previousDate,
  }) async {
    final tripRef = _tripsCollection.doc(trip.tripId);
    final companyRef = await _resolveDocByName(
      collection: _companiesCollection,
      name: trip.companyAndShipInfo.companyName,
      entityLabel: 'Company',
    );
    final shipRef = await _resolveDocByName(
      collection: _shipsCollection,
      name: trip.companyAndShipInfo.shipName,
      entityLabel: 'Ship',
    );

    await _firestore.runTransaction((transaction) async {
      final tripSnapshot = await transaction.get(tripRef);
      if (!tripSnapshot.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'not-found',
          message: 'Trip not found.',
        );
      }

      final companySnapshot = await transaction.get(companyRef);
      if (!companySnapshot.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'not-found',
          message:
              'Selected company "${trip.companyAndShipInfo.companyName}" does not exist.',
        );
      }

      final shipSnapshot = await transaction.get(shipRef);
      if (!shipSnapshot.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'not-found',
          message:
              'Selected ship "${trip.companyAndShipInfo.shipName}" does not exist.',
        );
      }

      final payload = trip.toMap();
      payload['updatedAt'] = FieldValue.serverTimestamp();

      final existingData = tripSnapshot.data() ?? <String, dynamic>{};
      final previousBill = _toDouble(
        existingData['totalBill'] ?? existingData['fundOwed'],
      );
      final currentBill = _toDouble(trip.totalBill);
      final delta = currentBill - previousBill;

      final companyData = companySnapshot.data() ?? <String, dynamic>{};
      final companyBilled = _toDouble(companyData['totalAmountBilled']);
      final companyDue = _toDouble(companyData['totalAmountDue']);

      transaction.update(tripRef, payload);

      if (delta != 0) {
        transaction.update(companyRef, {
          'totalAmountBilled': _formatAmount(companyBilled + delta),
          'totalAmountDue': _formatAmount(companyDue + delta),
        });
      }
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

  Future<DocumentReference<Map<String, dynamic>>> _resolveDocByName({
    required CollectionReference<Map<String, dynamic>> collection,
    required String name,
    required String entityLabel,
  }) async {
    final normalizedName = _normalizeNameKey(name, entityLabel: entityLabel);

    final byIdRef = collection.doc(normalizedName);
    final byIdSnapshot = await byIdRef.get();
    if (byIdSnapshot.exists) {
      return byIdRef;
    }

    final allDocs = await collection.get();
    final matchedDoc = allDocs.docs.firstWhereOrNull((doc) {
      final data = doc.data();
      final rawName = (data['name'] ?? '').toString();
      final normalizedFieldName = rawName.trim().toLowerCase().replaceAll(
        RegExp(r'\s+'),
        ' ',
      );

      return doc.id == normalizedName || normalizedFieldName == normalizedName;
    });

    if (matchedDoc != null) {
      return matchedDoc.reference;
    }

    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'not-found',
      message: 'Selected $entityLabel "$name" does not exist.',
    );
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) {
      final sanitized = value.replaceAll(',', '').trim();
      return double.tryParse(sanitized) ?? 0;
    }
    return 0;
  }

  String _formatAmount(double value) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
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
