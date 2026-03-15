import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../../../modules/cashin_cashout/models/cash_in_cash_out_model.dart';

class FirestoreCashInCashOutService extends GetxService {
  FirestoreCashInCashOutService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _userDoc {
    final uid = _requireUid();
    return _firestore.collection('users').doc(uid);
  }

  CollectionReference<Map<String, dynamic>> get _cashFlowCollection =>
      _userDoc.collection('cashInCashOut');

  CollectionReference<Map<String, dynamic>> get _cashFlowTransactionTypes =>
      _userDoc.collection('cashFlowTransactionTypes');

  final List<String> _allowedTransactionTypes = <String>[];
  List<String> get allowedTransactionTypes =>
      List.unmodifiable(_allowedTransactionTypes);

  String createEntryId() => _cashFlowCollection.doc().id;

  Future<void> setCashFlowTransactionTypes() async {
    final snapshot = await _cashFlowTransactionTypes.get();

    _allowedTransactionTypes
      ..clear()
      ..addAll(snapshot.docs.map((doc) => doc.id.toLowerCase()));

    if (_allowedTransactionTypes.isEmpty) {
      await addCashFlowTransactionType('cash');
    }
  }

  Future<void> addCashFlowTransactionType(String type) async {
    final normalizedType = type.trim().toLowerCase();

    if (normalizedType.isEmpty) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'invalid-argument',
        message: 'Transaction type cannot be empty.',
      );
    }

    final docRef = _cashFlowTransactionTypes.doc(normalizedType);

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (snap.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'already-exists',
          message: 'Transaction type already exists.',
        );
      }

      tx.set(docRef, {
        'name': normalizedType,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    if (!_allowedTransactionTypes.contains(normalizedType)) {
      _allowedTransactionTypes.add(normalizedType);
    }
  }

  Future<void> deleteCashFlowTransactionType(String type) async {
    final normalizedType = type.trim().toLowerCase();

    if (normalizedType.isEmpty) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'invalid-argument',
        message: 'Transaction type cannot be empty.',
      );
    }

    final docRef = _cashFlowTransactionTypes.doc(normalizedType);

    await _firestore.runTransaction((tx) async {
      final typeSnapshot = await tx.get(docRef);
      if (!typeSnapshot.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'not-found',
          message: 'Transaction type not found.',
        );
      }

      final entriesSnapshot = await _cashFlowCollection.get();
      final inUse = entriesSnapshot.docs.any((doc) {
        final savedType = (doc.data()['transactionType'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        return savedType == normalizedType;
      });

      if (inUse) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'failed-precondition',
          message: 'Cannot delete transaction type that is already used.',
        );
      }

      tx.delete(docRef);
    });

    _allowedTransactionTypes.removeWhere((item) => item == normalizedType);
    if (_allowedTransactionTypes.isEmpty) {
      await addCashFlowTransactionType('cash');
    }
  }

  Future<List<CashInCashOutModel>> getEntriesSortedByDateDesc() async {
    final snapshot = await _cashFlowCollection.orderBy('date').get();
    final entries = snapshot.docs
        .map((doc) => CashInCashOutModel.fromMap(doc.data()))
        .toList();

    entries.sort((left, right) {
      final dateCompare = _safeDate(right.date).compareTo(_safeDate(left.date));
      if (dateCompare != 0) return dateCompare;

      final createdCompare = _safeCreatedAt(
        right,
      ).compareTo(_safeCreatedAt(left));
      if (createdCompare != 0) return createdCompare;

      return right.entryId.compareTo(left.entryId);
    });

    return entries;
  }

  Future<void> addEntry({required CashInCashOutModel entry}) async {
    final entryId = entry.entryId.trim();
    if (entryId.isEmpty) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'invalid-argument',
        message: 'Entry id is required.',
      );
    }

    final flowType = entry.flowType.trim().toLowerCase();
    if (flowType != 'cash-in' && flowType != 'cash-out') {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'invalid-argument',
        message: 'Flow type must be either cash-in or cash-out.',
      );
    }

    final transactionType = entry.transactionType.trim().toLowerCase();
    if (transactionType.isEmpty) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'invalid-argument',
        message: 'Transaction type is required.',
      );
    }

    if (!_allowedTransactionTypes.contains(transactionType)) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'invalid-argument',
        message: 'Invalid transaction type: ${entry.transactionType}',
      );
    }

    final amount = _toDouble(entry.amount);
    if (amount <= 0) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'invalid-argument',
        message: 'Amount must be greater than zero.',
      );
    }

    final date = _normalizeDate(entry.date);
    await _cashFlowCollection.doc(entryId).set({
      'entryId': entryId,
      'flowType': flowType,
      'transactionType': transactionType,
      'amount': _formatAmount(amount),
      'date': date,
      'note': entry.note?.trim() ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateEntry({required CashInCashOutModel entry}) async {
    final entryId = entry.entryId.trim();
    if (entryId.isEmpty) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'invalid-argument',
        message: 'Entry id is required.',
      );
    }

    final ref = _cashFlowCollection.doc(entryId);
    final snapshot = await ref.get();
    if (!snapshot.exists) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'not-found',
        message: 'Cash flow entry not found.',
      );
    }

    final flowType = entry.flowType.trim().toLowerCase();
    if (flowType != 'cash-in' && flowType != 'cash-out') {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'invalid-argument',
        message: 'Flow type must be either cash-in or cash-out.',
      );
    }

    final transactionType = entry.transactionType.trim().toLowerCase();
    if (transactionType.isEmpty) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'invalid-argument',
        message: 'Transaction type is required.',
      );
    }

    if (!_allowedTransactionTypes.contains(transactionType)) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'invalid-argument',
        message: 'Invalid transaction type: ${entry.transactionType}',
      );
    }

    final amount = _toDouble(entry.amount);
    if (amount <= 0) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'invalid-argument',
        message: 'Amount must be greater than zero.',
      );
    }

    final date = _normalizeDate(entry.date);
    await ref.update({
      'flowType': flowType,
      'transactionType': transactionType,
      'amount': _formatAmount(amount),
      'date': date,
      'note': entry.note?.trim() ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteEntry({required String entryId}) async {
    final normalized = entryId.trim();
    if (normalized.isEmpty) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'invalid-argument',
        message: 'Entry id is required.',
      );
    }

    final ref = _cashFlowCollection.doc(normalized);
    final snapshot = await ref.get();

    if (!snapshot.exists) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'not-found',
        message: 'Cash flow entry not found.',
      );
    }

    await ref.delete();
  }

  double computeNetCashFlow(Iterable<CashInCashOutModel> entries) {
    double total = 0;
    for (final entry in entries) {
      final amount = _toDouble(entry.amount);
      if (amount <= 0) continue;
      total += entry.isCashOut ? -amount : amount;
    }
    return total;
  }

  DateTime _safeDate(String value) {
    final parsed = DateTime.tryParse(value.trim());
    return parsed ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime _safeCreatedAt(CashInCashOutModel entry) {
    return entry.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _normalizeDate(String value) {
    final trimmed = value.trim();
    final parsed = DateTime.tryParse(trimmed);
    if (parsed != null) {
      final year = parsed.year.toString().padLeft(4, '0');
      final month = parsed.month.toString().padLeft(2, '0');
      final day = parsed.day.toString().padLeft(2, '0');
      return '$year-$month-$day';
    }

    return trimmed;
  }

  String _formatAmount(double value) {
    return value.toInt().toString();
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

  String _requireUid() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw FirebaseException(
        plugin: 'firebase_auth',
        code: 'not-authenticated',
        message: 'No authenticated user.',
      );
    }
    return uid;
  }
}
