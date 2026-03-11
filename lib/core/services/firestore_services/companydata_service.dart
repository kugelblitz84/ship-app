import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'paginated_result.dart';
import '../../../modules/company/models/company_model.dart';

class FirestoreCompanyService extends GetxService {
  FirestoreCompanyService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _companiesCollection {
    final uid = _requireUid();
    return _firestore.collection('users').doc(uid).collection('companies');
  }

  CollectionReference<Map<String, dynamic>> get _tripsCollection {
    final uid = _requireUid();
    return _firestore.collection('users').doc(uid).collection('trips');
  }

  CollectionReference<Map<String, dynamic>> get _transactionsCollection {
    final uid = _requireUid();
    return _firestore.collection('users').doc(uid).collection('transactions');
  }

  Future<String> AddCompany(Map<String, dynamic> companyData) async {
    final companyName = (companyData['name'] as String? ?? '').trim();
    final normalizedName = _normalizeNameKey(
      companyName,
      entityLabel: 'Company',
    );
    final companyDoc = _companiesCollection.doc(normalizedName);
    final payload = <String, dynamic>{...companyData};
    payload['name'] = companyName;
    payload['totalAmountBilled'] = '0';
    payload['totalAmountReceived'] = '0';
    payload['totalAmountDue'] = '0';
    payload['createdAt'] = FieldValue.serverTimestamp();

    await _firestore.runTransaction((transaction) async {
      final existingDoc = await transaction.get(companyDoc);
      if (existingDoc.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'already-exists',
          message: 'A company with this name already exists.',
        );
      }

      transaction.set(companyDoc, payload);
    });

    return companyDoc.id;
  }

  Future<List<CompanyModel>> getCompanies() async {
    final snapshot = await _companiesCollection.get();
    return snapshot.docs
        .map((doc) => CompanyModel.fromMap(doc.data()))
        .toList();
  }

  Future<PaginatedResult<CompanyModel>> getCompaniesPage({
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 10,
  }) async {
    Query<Map<String, dynamic>> query = _companiesCollection
        .orderBy(FieldPath.documentId)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    final companies = snapshot.docs
        .map((doc) => CompanyModel.fromMap(doc.data()))
        .toList();

    return PaginatedResult<CompanyModel>(
      items: companies,
      lastDocument: snapshot.docs.isEmpty ? startAfter : snapshot.docs.last,
      hasMore: snapshot.docs.length == limit,
    );
  }

  Future<List<CompanyModel>> getCompaniesSortedByName() async {
    final companies = await getCompanies();
    companies.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return companies;
  }

  Future<void> updateCompanyDetails({
    required String companyName,
    String? description,
  }) async {
    final companyDoc = _companiesCollection.doc(
      _normalizeNameKey(companyName, entityLabel: 'Company'),
    );

    await _firestore.runTransaction((transaction) async {
      final existingDoc = await transaction.get(companyDoc);
      if (!existingDoc.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'not-found',
          message: 'Company not found.',
        );
      }

      transaction.update(companyDoc, {
        'description': (description ?? '').trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> deleteCompany({required String companyName}) async {
    final normalizedName = _normalizeNameKey(
      companyName,
      entityLabel: 'Company',
    );
    final companyDoc = _companiesCollection.doc(normalizedName);

    await _firestore.runTransaction((transaction) async {
      final existingDoc = await transaction.get(companyDoc);
      if (!existingDoc.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'not-found',
          message: 'Company not found.',
        );
      }

      final tripsSnapshot = await _tripsCollection.get();
      final hasLinkedTrips = tripsSnapshot.docs.any((tripDoc) {
        final tripCompanyName =
            (tripDoc.data()['companyAndShipInfo']?['companyName'] ?? '')
                .toString();
        final normalizedTripCompanyName = tripCompanyName
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r'\s+'), ' ');
        return normalizedTripCompanyName == normalizedName;
      });

      if (hasLinkedTrips) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'failed-precondition',
          message: 'Cannot delete company with existing trips.',
        );
      }

      final transactionsSnapshot = await _transactionsCollection.get();
      final hasLinkedTransactions = transactionsSnapshot.docs.any((txDoc) {
        final txCompanyName =
            (txDoc.data()['companyAndShipInfo']?['companyName'] ?? '')
                .toString();
        final normalizedTxCompanyName = txCompanyName
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r'\s+'), ' ');
        return normalizedTxCompanyName == normalizedName;
      });

      if (hasLinkedTransactions) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'failed-precondition',
          message: 'Cannot delete company with existing transactions.',
        );
      }

      transaction.delete(companyDoc);
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
