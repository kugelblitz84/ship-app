import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:urgent/modules/Transactions/models/transaction_model.dart';

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
    if (!_allowedTypes.contains(paymentType)) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'invalid-argument',
        message: 'Invalid transaction type: ${transaction.type}',
      );
    }

    final transactionCategory = transaction.transactionType
        .trim()
        .toLowerCase();
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
        transactionCategory == 'payment' || expenseSource == 'company';
    final persistedCompanyName = needsCompanyUpdate ? companyName : '';

    if (needsCompanyUpdate && companyName.isEmpty) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'invalid-argument',
        message: 'Company is required for this transaction.',
      );
    }

    final companyRef = needsCompanyUpdate
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
          updatedCompanyDue = companyDue + transactionAmount;
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
          'companyName': persistedCompanyName,
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
