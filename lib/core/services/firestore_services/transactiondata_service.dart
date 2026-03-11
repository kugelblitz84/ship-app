import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:urgent/modules/Transactions/models/transaction_model.dart';

import 'paginated_result.dart';

class FirestoreTransactionService extends GetxService {
  FirestoreTransactionService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _userDoc {
    final uid = _requireUid();
    return _firestore.collection('users').doc(uid);
  }

  CollectionReference<Map<String, dynamic>> get _transactionsCollection =>
      _userDoc.collection('transactions');

  CollectionReference<Map<String, dynamic>> get _transactionMethodsCollection =>
      _userDoc.collection('transactionMethods');

  CollectionReference<Map<String, dynamic>> get _companiesCollection =>
      _userDoc.collection('companies');

  final List<String> _allowedTypes = <String>[];
  List<String> get allowedTypes => List.unmodifiable(_allowedTypes);
  static const List<String> _allowedTransactionCategories = <String>[
    'payment',
    'expenses',
    'trips',
  ];

  static const List<String> _allowedExpenseSources = <String>[
    'company',
    'main-balance',
  ];

  String createTransactionId() {
    return _transactionsCollection.doc().id;
  }

  Future<void> setTransactionMethods() async {
    final snapshot = await _transactionMethodsCollection.get();

    _allowedTypes
      ..clear()
      ..addAll(snapshot.docs.map((doc) => doc.id.toLowerCase()));
  }

  Future<void> addTransactionMethod(String type) async {
    final normalizedType = type.trim().toLowerCase();

    if (normalizedType.isEmpty) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'invalid-argument',
        message: 'Transaction method cannot be empty.',
      );
    }

    final docRef = _transactionMethodsCollection.doc(normalizedType);

    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (snap.exists) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'already-exists',
            message: 'Transaction method already exists.',
          );
        }

        tx.set(docRef, {
          'name': normalizedType,
          'createdAt': FieldValue.serverTimestamp(), // optional
        });
      });

      _allowedTypes.add(normalizedType);
    } on FirebaseException {
      rethrow;
    }
  }

  Future<void> deleteTransactionMethod(String type) async {
    final normalizedType = type.trim().toLowerCase();

    if (normalizedType.isEmpty) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'invalid-argument',
        message: 'Transaction method cannot be empty.',
      );
    }

    final docRef = _transactionMethodsCollection.doc(normalizedType);

    await _firestore.runTransaction((tx) async {
      final methodSnapshot = await tx.get(docRef);
      if (!methodSnapshot.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'not-found',
          message: 'Transaction method not found.',
        );
      }

      final transactionsSnapshot = await _transactionsCollection.get();
      final isUsed = transactionsSnapshot.docs.any((doc) {
        final method = (doc.data()['type'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        return method == normalizedType;
      });

      if (isUsed) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'failed-precondition',
          message: 'Cannot delete transaction method that is already used.',
        );
      }

      tx.delete(docRef);
    });

    _allowedTypes.removeWhere((item) => item == normalizedType);
  }

  Future<void> addTransaction({required TransactionModel transaction}) async {
    final transactionRef = _transactionsCollection.doc(
      transaction.transactionId,
    );

    final paymentType = transaction.type.trim().toLowerCase();
    final transactionCategory = transaction.transactionType
        .trim()
        .toLowerCase();

    final requiresConfiguredMethod = transactionCategory != 'trips';
    if (requiresConfiguredMethod && !_allowedTypes.contains(paymentType)) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'invalid-argument',
        message: 'Invalid transaction type: ${transaction.type}',
      );
    }

    if (!_allowedTransactionCategories.contains(transactionCategory)) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'invalid-argument',
        message: 'Invalid transaction category: ${transaction.transactionType}',
      );
    }

    final expenseSource = transaction.expenseSource.trim().toLowerCase();
    if (transactionCategory == 'expenses' &&
        !_allowedExpenseSources.contains(expenseSource)) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'invalid-argument',
        message: 'Invalid expense source: ${transaction.expenseSource}',
      );
    }

    final companyName =
        transaction.companyAndShipInfo.companyName?.trim() ?? 'N/A';
    final needsCompanyUpdate =
        transactionCategory == 'payment' ||
        (transactionCategory == 'expenses' && expenseSource == 'company');
    final requiresCompanyName =
        transactionCategory == 'payment' ||
        transactionCategory == 'trips' ||
        (transactionCategory == 'expenses' && expenseSource == 'company');
    final persistedCompanyName = needsCompanyUpdate ? companyName : '';

    if (requiresCompanyName && companyName.isEmpty) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'invalid-argument',
        message: 'Company is required for this transaction.',
      );
    }

    final companyRef = (needsCompanyUpdate || transactionCategory == 'trips')
        ? _companiesCollection.doc(
            _normalizeNameKey(companyName, entityLabel: 'Company'),
          )
        : null;

    final transactionAmount = _toDouble(transaction.amount);
    if (transactionAmount <= 0) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'invalid-argument',
        message: 'Transaction amount must be greater than zero',
      );
    }

    await _firestore.runTransaction((firebaseTransaction) async {
      double companyBilled = 0;
      double companyReceived = 0;
      double companyDue = 0;
      double updatedCompanyReceived = 0;
      double updatedCompanyDue = 0;
      bool updateCompanySummary = false;

      if (companyRef != null) {
        final companySnapshot = await firebaseTransaction.get(companyRef);
        if (!companySnapshot.exists) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'not-found',
            message:
                'Selected company "${transaction.companyAndShipInfo.companyName}" does not exist.',
          );
        }

        final companyData = companySnapshot.data() ?? <String, dynamic>{};
        companyBilled = _toDouble(companyData['totalAmountBilled']);
        companyReceived = _toDouble(companyData['totalAmountReceived']);
        companyDue = _toDouble(companyData['totalAmountDue']);

        if (transactionCategory == 'payment') {
          updatedCompanyReceived = companyReceived + transactionAmount;
          updatedCompanyDue = companyDue - transactionAmount;
          updateCompanySummary = true;
        } else if (expenseSource == 'company') {
          updatedCompanyReceived = companyReceived;
          updatedCompanyDue = companyDue - transactionAmount;
          updateCompanySummary = true;
        }
      }

      final tripId = transaction.tripId.trim();
      final tripFrom = transaction.tripFrom.trim();
      final tripTo = transaction.tripTo.trim();

      final persistedTotalPrice = updateCompanySummary
          ? _formatAmount(companyBilled)
          : transaction.totalPrice;

      final persistedAmountDue = updateCompanySummary
          ? _formatAmount(updatedCompanyDue.toDouble())
          : transaction.amountDue;

      firebaseTransaction.set(transactionRef, {
        'transactionId': transaction.transactionId,
        'transactionType': transactionCategory,
        'expenseSource': expenseSource,
        'tripId': tripId,
        'tripFrom': tripFrom,
        'tripTo': tripTo,
        'tripInfo': {'from': tripFrom, 'to': tripTo},
        'description': transaction.description,
        'amount': _formatAmount(transactionAmount),
        'totalPrice': persistedTotalPrice,
        'amountDue': persistedAmountDue,
        'date': _normalizeTransactionDate(transaction.date),
        'type': paymentType,
        // Persist names only; they are the canonical identifiers now.
        'companyAndShipInfo': {
          'companyName': transactionCategory == 'trips'
              ? companyName
              : persistedCompanyName,
          'shipName': transaction.companyAndShipInfo.shipName,
        },
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (companyRef != null && updateCompanySummary) {
        firebaseTransaction.update(companyRef, {
          'totalAmountReceived': _formatAmount(updatedCompanyReceived),
          'totalAmountDue': _formatAmount(updatedCompanyDue),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> deleteTransaction({required String transactionId}) async {
    final normalizedTransactionId = transactionId.trim();
    if (normalizedTransactionId.isEmpty) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'invalid-argument',
        message: 'Transaction id is required.',
      );
    }

    final transactionRef = _transactionsCollection.doc(normalizedTransactionId);

    await _firestore.runTransaction((firebaseTransaction) async {
      final transactionSnapshot = await firebaseTransaction.get(transactionRef);
      if (!transactionSnapshot.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'not-found',
          message: 'Transaction not found.',
        );
      }

      final transactionData = transactionSnapshot.data() ?? <String, dynamic>{};
      final transactionCategory = (transactionData['transactionType'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final expenseSource = (transactionData['expenseSource'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final amount = _toDouble(transactionData['amount']);

      if (amount <= 0) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'invalid-argument',
          message: 'Transaction amount must be greater than zero.',
        );
      }

      final companyAndShipInfo =
          transactionData['companyAndShipInfo'] is Map<String, dynamic>
          ? transactionData['companyAndShipInfo'] as Map<String, dynamic>
          : <String, dynamic>{};

      final companyName = (companyAndShipInfo['companyName'] ?? '')
          .toString()
          .trim();

      final needsCompanyUpdate =
          transactionCategory == 'payment' ||
          (transactionCategory == 'expenses' && expenseSource == 'company');

      if (needsCompanyUpdate) {
        if (companyName.isEmpty) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'invalid-argument',
            message: 'Company is required for this transaction.',
          );
        }

        final companyRef = _companiesCollection.doc(
          _normalizeNameKey(companyName, entityLabel: 'Company'),
        );
        final companySnapshot = await firebaseTransaction.get(companyRef);

        if (!companySnapshot.exists) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'not-found',
            message: 'Linked company not found for this transaction.',
          );
        }

        final companyData = companySnapshot.data() ?? <String, dynamic>{};
        final currentReceived = _toDouble(companyData['totalAmountReceived']);
        final currentDue = _toDouble(companyData['totalAmountDue']);

        double updatedReceived = currentReceived;
        double updatedDue = currentDue;

        if (transactionCategory == 'payment') {
          updatedReceived = currentReceived - amount;
          updatedDue = currentDue + amount;
        } else if (expenseSource == 'company') {
          updatedDue = currentDue + amount;
        }

        firebaseTransaction.update(companyRef, {
          'totalAmountReceived': _formatAmount(updatedReceived),
          'totalAmountDue': _formatAmount(updatedDue),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      firebaseTransaction.delete(transactionRef);
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

  Future<List<TransactionModel>> getTransactions() async {
    final snapshot = await _transactionsCollection.get();
    final transactions =
        snapshot.docs
            .map((doc) => TransactionModel.fromMap(doc.data()))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    return transactions;
  }

  Future<PaginatedResult<TransactionModel>> getTransactionsPage({
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 10,
  }) async {
    Query<Map<String, dynamic>> query = _transactionsCollection
        .orderBy('date', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    final transactions = snapshot.docs
        .map((doc) => TransactionModel.fromMap(doc.data()))
        .toList();

    return PaginatedResult<TransactionModel>(
      items: transactions,
      lastDocument: snapshot.docs.isEmpty ? startAfter : snapshot.docs.last,
      hasMore: snapshot.docs.length == limit,
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
    return value.toInt().toString();
  }

  String _todayDateString() {
    final now = DateTime.now();
    final year = now.year.toString().padLeft(4, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _normalizeTransactionDate(String rawDate) {
    final trimmed = rawDate.trim();
    if (trimmed.isEmpty) {
      return _todayDateString();
    }

    final parsed = DateTime.tryParse(trimmed);
    if (parsed == null) {
      return _todayDateString();
    }

    final year = parsed.year.toString().padLeft(4, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
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
