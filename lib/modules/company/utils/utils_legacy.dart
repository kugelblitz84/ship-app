import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/services/download/download_service.dart';
import '../models/company_model.dart';
import '../../trip/models/trip_model.dart' as trip_models;
import '../../Transactions/models/transaction_model.dart' as tx_models;

class CompanyStatementUtil {
  CompanyStatementUtil._();

  static final DownloadService _downloadService = createDownloadService();

  /// Simple method you can call directly from your controller.
  static Future<void> generateAndSavePdf({
    required CompanyModel company,
    required List<trip_models.TripModel> trips,
    required List<tx_models.TransactionModel> transactions,
  }) async {
    await saveCompanyStatementAndNotify(
      company: company,
      trips: trips,
      transactions: transactions,
    );
  }

  static Future<void> saveCompanyStatementAndNotify({
    required CompanyModel company,
    required List<trip_models.TripModel> trips,
    required List<tx_models.TransactionModel> transactions,
  }) async {
    final context = Get.context;
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final savedFile = await saveCompanyStatementToFile(
        company: company,
        trips: trips,
        transactions: transactions,
      );

      if (context.mounted) {
        Navigator.of(context).pop();
      }

      await _showSaveSuccessModal(
        context,
        savedFile,
        company,
        trips,
        transactions,
      );
    } catch (_) {
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      _showErrorDialog(
        context,
        'Unable to save company statement file. Please try again.',
      );
    }
  }

  static Future<GeneratedFileSaveResult> saveCompanyStatementToFile({
    required CompanyModel company,
    required List<trip_models.TripModel> trips,
    required List<tx_models.TransactionModel> transactions,
  }) async {
    final bytes = await buildCompanyStatementPdf(
      company: company,
      trips: trips,
      transactions: transactions,
    );

    final file = GeneratedFileData(
      bytes: bytes,
      fileName: fileNameFor(company),
      mimeType: 'application/pdf',
    );

    return _downloadService.saveFile(file);
  }

  static Future<void> openDownloadedStatement(
    GeneratedFileSaveResult savedFile, {
    CompanyModel? company,
    List<trip_models.TripModel>? trips,
    List<tx_models.TransactionModel>? transactions,
  }) async {
    try {
      final opened = await _downloadService.openSavedFile(
        savedFile: savedFile,
        mimeType: 'application/pdf',
      );

      if (opened) {
        return;
      }

      if (company != null && trips != null && transactions != null) {
        Get.to(
          () => CompanyStatementPreviewPage(
            company: company,
            trips: trips,
            transactions: transactions,
          ),
        );
        return;
      }

      final context = Get.context;
      if (context != null) {
        _showErrorDialog(context, 'Unable to open the saved statement file.');
      }
    } catch (_) {
      if (company != null && trips != null && transactions != null) {
        Get.to(
          () => CompanyStatementPreviewPage(
            company: company,
            trips: trips,
            transactions: transactions,
          ),
        );
        return;
      }

      final context = Get.context;
      if (context != null) {
        _showErrorDialog(context, 'Unable to open the saved statement file.');
      }
    }
  }

  static Future<Uint8List> buildCompanyStatementPdf({
    required CompanyModel company,
    required List<trip_models.TripModel> trips,
    required List<tx_models.TransactionModel> transactions,
  }) async {
    final pdfTheme = await _buildPdfTheme();

    final pdf = pw.Document(
      title: 'Company Statement',
      author: 'Urgent',
      creator: 'Urgent App',
      subject: 'Company statement (ledger)',
    );

    final generatedAt = DateTime.now();
    final ledger = _buildLedger(trips, transactions);

    final storedBilled = _parseAmount(company.totalAmountBilled);
    final storedReceived = _parseAmount(company.totalAmountReceived);
    final storedDue = _parseAmount(company.totalAmountDue);

    // Computed truth from history
    final billed = ledger.totalTripBill;
    final paid = ledger.totalPayments;
    final expenses = ledger.totalExpenses;
    final closingDue = ledger.closingDue;

    final dateRange = ledger.blocks.isEmpty
        ? const _DateRange('--', '--')
        : _DateRange(
            ledger.blocks.first.displayDate,
            ledger.blocks.last.displayDate,
          );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pdfTheme,
        margin: const pw.EdgeInsets.all(24),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (_) => [
          _buildHeader(
            generatedAt: generatedAt,
            companyName: _safe(company.name),
          ),
          pw.SizedBox(height: 14),

          _buildCompanyInfoSection(
            company: company,
            fromDate: dateRange.from,
            toDate: dateRange.to,
            tripCount: trips.length,
            paymentCount: transactions.where((e) => !_isExpense(e)).length,
            expenseCount: transactions
                .where((e) => _isCompanyExpense(e))
                .length,
          ),
          pw.SizedBox(height: 14),

          _buildMinimalSummaryRow(
            billed: _currency(billed),
            paid: _currency(paid),
            expenses: _currency(expenses),
            due: _currency(closingDue),
          ),

          pw.SizedBox(height: 14),

          _buildHistoryTitle(),
          pw.SizedBox(height: 8),
          _buildLedgerHistoryTable(ledger),

          pw.SizedBox(height: 12),

          _buildClosingBox(
            billed: _currency(billed),
            paid: _currency(paid),
            expenses: _currency(expenses),
            closingDue: _currency(closingDue),
          ),

          pw.SizedBox(height: 12),

          _buildNotesSection(
            company: company,
            storedBilled: storedBilled,
            storedReceived: storedReceived,
            storedDue: storedDue,
            computedBilled: billed,
            computedReceived: paid,
            computedDue: closingDue,
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static String fileNameFor(CompanyModel company) {
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final safeCompanyName = company.name
        .trim()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');

    final resolvedName = safeCompanyName.isEmpty ? 'company' : safeCompanyName;
    return 'company_statement_${resolvedName}_$stamp.pdf';
  }

  // ────────────────────────────────────────────────────────────────────────────
  // PDF SECTIONS
  // ────────────────────────────────────────────────────────────────────────────

  static pw.Widget _buildHeader({
    required DateTime generatedAt,
    required String companyName,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey900,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'COMPANY STATEMENT',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.05,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                companyName,
                style: const pw.TextStyle(color: PdfColors.white, fontSize: 11),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Urgent Transport Billing',
                style: const pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              _metaText(
                'Generated',
                DateFormat('dd MMM yyyy').format(generatedAt),
              ),
              pw.SizedBox(height: 4),
              _metaText('Source', 'Urgent App'),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildCompanyInfoSection({
    required CompanyModel company,
    required String fromDate,
    required String toDate,
    required int tripCount,
    required int paymentCount,
    required int expenseCount,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 5,
          child: _infoCard(
            title: 'Company Details',
            rows: [
              'Name: ${_safe(company.name)}',
              'Description: ${_safe(company.description ?? 'N/A')}',
              'Date Range: $fromDate to $toDate',
            ],
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          flex: 4,
          child: _infoCard(
            title: 'Overview',
            rows: [
              'Trips: $tripCount',
              'Payments: $paymentCount',
              'Expenses: $expenseCount',
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildMinimalSummaryRow({
    required String billed,
    required String paid,
    required String expenses,
    required String due,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(child: _miniStat('Billed', billed)),
          pw.SizedBox(width: 10),
          pw.Expanded(child: _miniStat('Paid', paid)),
          pw.SizedBox(width: 10),
          pw.Expanded(child: _miniStat('Expenses', expenses)),
          pw.SizedBox(width: 10),
          pw.Expanded(child: _miniStat('Closing Due', due, bold: true)),
        ],
      ),
    );
  }

  static pw.Widget _miniStat(String label, String value, {bool bold = false}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 12.5,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: PdfColors.blueGrey900,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildHistoryTitle() {
    return pw.Row(
      children: [
        pw.Container(
          width: 26,
          height: 26,
          decoration: pw.BoxDecoration(
            color: PdfColors.blueGrey50,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          alignment: pw.Alignment.center,
          child: pw.Text(
            'H',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey900,
              fontSize: 12,
            ),
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Statement History',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 12,
                color: PdfColors.blueGrey900,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'Date-wise ledger with subtotals and running due balance.',
              style: const pw.TextStyle(
                fontSize: 9.5,
                color: PdfColors.grey700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildLedgerHistoryTable(_LedgerBuildResult ledger) {
    // Columns: SL | Date | Particulars | Bill | Payment | Expense | Balance
    final rows = <pw.TableRow>[];

    // Header
    rows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
        children: [
          _cell('SL', header: true),
          _cell('Date', header: true),
          _cell('Particulars', header: true),
          _cell('Before', header: true, right: true),
          _cell('Bill (+)', header: true, right: true),
          _cell('Pay (-)', header: true, right: true),
          _cell('Exp (+)', header: true, right: true),
          _cell('Balance (Due)', header: true, right: true),
        ],
      ),
    );

    // Opening

    int sl = 0;

    for (final block in ledger.blocks) {
      rows.add(
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _cell(''),
            _cell(block.displayDate, bold: true),
            _cell(''),
            _cell('', right: true),
            _cell('', right: true),
            _cell('', right: true),
            _cell('', right: true),
            _cell('', right: true),
          ],
        ),
      );

      for (final entry in block.entries) {
        sl += 1;

        rows.add(
          pw.TableRow(
            children: [
              _cell(sl.toString()),
              _cell(''),
              _cell(entry.particulars),
              _cell(_currency(entry.balanceBefore), right: true),
              _cell(entry.bill > 0 ? _currency(entry.bill) : '', right: true),
              _cell(
                entry.payment > 0 ? _currency(entry.payment) : '',
                right: true,
              ),
              _cell(
                entry.expense > 0 ? _currency(entry.expense) : '',
                right: true,
              ),
              _cell(_currency(entry.balanceAfter), right: true),
            ],
          ),
        );
      }

      // Subtotal row
      rows.add(
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
          children: [
            _cell(''),
            _cell(''),
            _cell('Subtotal', bold: true),
            _cell('', right: true),
            _cell(_currency(block.billSubtotal), right: true, bold: true),
            _cell(_currency(block.paymentSubtotal), right: true, bold: true),
            _cell(_currency(block.expenseSubtotal), right: true, bold: true),
            _cell(_currency(block.balanceAfter), right: true, bold: true),
          ],
        ),
      );

      rows.add(
        pw.TableRow(
          children: [
            _cell(''),
            _cell(''),
            _cell(''),
            _cell('', right: true),
            _cell('', right: true),
            _cell('', right: true),
            _cell('', right: true),
            _cell('', right: true),
          ],
        ),
      );
    }

    // Closing row
    rows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.blueGrey900),
        children: [
          _cell('', color: PdfColors.white),
          _cell('', color: PdfColors.white),
          _cell('Closing Due', color: PdfColors.white, bold: true),
          _cell('', right: true, color: PdfColors.white),
          _cell('', right: true, color: PdfColors.white),
          _cell('', right: true, color: PdfColors.white),
          _cell('', right: true, color: PdfColors.white),
          _cell(
            _currency(ledger.closingDue),
            right: true,
            color: PdfColors.white,
            bold: true,
          ),
        ],
      ),
    );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.65),
        1: const pw.FlexColumnWidth(1.2),
        2: const pw.FlexColumnWidth(3.7),
        3: const pw.FlexColumnWidth(1.4),
        4: const pw.FlexColumnWidth(1.25),
        5: const pw.FlexColumnWidth(1.25),
        6: const pw.FlexColumnWidth(1.25),
        7: const pw.FlexColumnWidth(1.45),
      },
      children: rows,
    );
  }

  static pw.Widget _buildClosingBox({
    required String billed,
    required String paid,
    required String expenses,
    required String closingDue,
  }) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 280,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
          borderRadius: pw.BorderRadius.circular(10),
        ),
        child: pw.Column(
          children: [
            _amountLine('Total Billed', billed),
            pw.SizedBox(height: 6),
            _amountLine('Total Paid', paid),
            pw.SizedBox(height: 6),
            _amountLine('Total Expenses', expenses),
            pw.Divider(color: PdfColors.grey400, height: 14),
            _amountLine('Closing Due', closingDue, bold: true),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildNotesSection({
    required CompanyModel company,
    required double storedBilled,
    required double storedReceived,
    required double storedDue,
    required double computedBilled,
    required double computedReceived,
    required double computedDue,
  }) {
    final description = (company.description ?? '').trim();

    final mismatch =
        (storedDue - computedDue).abs() > 0.5 ||
        (storedBilled - computedBilled).abs() > 0.5 ||
        (storedReceived - computedReceived).abs() > 0.5;

    final reconcileLine = mismatch
        ? 'Note: Stored totals may differ from computed history (snapshot vs ledger).'
        : 'Totals are consistent with computed ledger history.';

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Notes',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            description.isEmpty
                ? 'This statement is generated from trips and transactions recorded in the Urgent app.'
                : description,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            reconcileLine,
            style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // LEDGER BUILD (date blocks + running balance)
  // ────────────────────────────────────────────────────────────────────────────

  static _LedgerBuildResult _buildLedger(
    List<trip_models.TripModel> trips,
    List<tx_models.TransactionModel> transactions,
  ) {
    final buckets = <String, _LedgerBucket>{};

    _LedgerBucket ensure(String rawDate) {
      final trimmed = rawDate.trim();
      final parsed = _tryParseDate(trimmed);
      final key = parsed != null
          ? DateFormat('yyyy-MM-dd').format(parsed)
          : (trimmed.isEmpty ? 'unknown-date' : 'raw-$trimmed');

      return buckets.putIfAbsent(
        key,
        () => _LedgerBucket(
          key: key,
          rawDate: trimmed,
          parsedDate: parsed,
          displayDate: parsed != null
              ? DateFormat('dd MMM yyyy').format(parsed)
              : (trimmed.isEmpty ? 'Unknown Date' : trimmed),
        ),
      );
    }

    // Trips (bill +)
    for (final trip in trips) {
      ensure(trip.date).trips.add(trip);
    }

    // Transactions (payment - / company-expense +)
    // Main-balance expenses affect cash-at-hand only and are excluded from due.
    for (final tx in transactions) {
      if (_isCompanyExpense(tx)) {
        ensure(tx.date).expenses.add(tx);
      } else if (!_isExpense(tx)) {
        ensure(tx.date).payments.add(tx);
      }
    }

    // Sort buckets ascending for "build-up" narrative
    final blocks = buckets.values.toList()
      ..sort((a, b) {
        final ad = a.parsedDate;
        final bd = b.parsedDate;
        if (ad != null && bd != null) return ad.compareTo(bd);
        if (ad != null) return -1;
        if (bd != null) return 1;
        return a.displayDate.compareTo(b.displayDate);
      });

    double runningDue = 0;

    double totalTripBill = 0;
    double totalPayments = 0;
    double totalExpenses = 0;

    final builtBlocks = <_LedgerDateBlock>[];

    for (final b in blocks) {
      final entries = <_LedgerEntry>[];

      double billSubtotal = 0;
      double paymentSubtotal = 0;
      double expenseSubtotal = 0;

      // Trips first (bill +)
      for (final trip in b.trips) {
        final bill = _parseAmount(trip.totalBill);
        totalTripBill += bill;
        billSubtotal += bill;

        final balanceBefore = runningDue;
        runningDue += bill;

        entries.add(
          _LedgerEntry(
            particulars: _tripParticular(trip),
            bill: bill,
            payment: 0,
            expense: 0,
            balanceBefore: balanceBefore,
            balanceAfter: runningDue,
          ),
        );
      }

      // Expenses ( + )
      for (final tx in b.expenses) {
        final amount = _parseAmount(tx.amount);
        totalExpenses += amount;
        expenseSubtotal += amount;

        final balanceBefore = runningDue;
        runningDue += amount;

        entries.add(
          _LedgerEntry(
            particulars: _expenseParticular(tx),
            bill: 0,
            payment: 0,
            expense: amount,
            balanceBefore: balanceBefore,
            balanceAfter: runningDue,
          ),
        );
      }

      // Payments ( - )
      for (final tx in b.payments) {
        final amount = _parseAmount(tx.amount);
        totalPayments += amount;
        paymentSubtotal += amount;

        final balanceBefore = runningDue;
        runningDue -= amount;

        entries.add(
          _LedgerEntry(
            particulars: _paymentParticular(tx),
            bill: 0,
            payment: amount,
            expense: 0,
            balanceBefore: balanceBefore,
            balanceAfter: runningDue,
          ),
        );
      }

      builtBlocks.add(
        _LedgerDateBlock(
          displayDate: b.displayDate,
          parsedDate: b.parsedDate,
          entries: entries,
          billSubtotal: billSubtotal,
          paymentSubtotal: paymentSubtotal,
          expenseSubtotal: expenseSubtotal,
          balanceAfter: runningDue,
        ),
      );
    }

    return _LedgerBuildResult(
      openingDue: 0,
      blocks: builtBlocks,
      totalTripBill: totalTripBill,
      totalPayments: totalPayments,
      totalExpenses: totalExpenses,
      closingDue: runningDue,
    );
  }

  static String _tripParticular(trip_models.TripModel trip) {
    final from = _safe(trip.from);
    final to = _safe(trip.to);
    final product = (trip.product?.productName ?? '').trim();
    final productLabel = product.isEmpty
        ? ''
        : ' • Product: ${_pdfText(product)}';
    return _pdfText('Trip bill: $from - $to$productLabel');
  }

  static String _paymentParticular(tx_models.TransactionModel tx) {
    final method = _formatType(tx.type);
    final base = tx.hasTrip ? _pdfText(tx.routeLabel) : '';
    final desc = (tx.description ?? '').trim();
    final label = desc.isNotEmpty
        ? _pdfText(desc)
        : (base.isNotEmpty ? base : 'Payment entry');
    return _pdfText('Payment received ($method): $label');
  }

  static String _expenseParticular(tx_models.TransactionModel tx) {
    final source = _formatType(tx.expenseSource);
    final base = tx.hasTrip ? _pdfText(tx.routeLabel) : '';
    final desc = (tx.description ?? '').trim();
    final label = desc.isNotEmpty
        ? _pdfText(desc)
        : (base.isNotEmpty ? base : 'Expense entry');
    return _pdfText('Expense ($source): $label');
  }

  // ────────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ────────────────────────────────────────────────────────────────────────────

  static pw.Widget _metaText(String label, String value) {
    return pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '$label: ',
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.TextSpan(
            text: value,
            style: const pw.TextStyle(color: PdfColors.white, fontSize: 9),
          ),
        ],
      ),
    );
  }

  static pw.Widget _infoCard({
    required String title,
    required List<String> rows,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
          ),
          pw.SizedBox(height: 6),
          ...rows.map(
            (row) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Text(
                row,
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _amountLine(
    String label,
    String value, {
    bool bold = false,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 10,
            color: PdfColors.grey800,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10,
            color: PdfColors.grey900,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    );
  }

  static pw.Widget _cell(
    String text, {
    bool header = false,
    bool right = false,
    bool bold = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      child: pw.Text(
        _pdfText(text),
        textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: header ? 9.2 : 9.0,
          fontWeight: header || bold
              ? pw.FontWeight.bold
              : pw.FontWeight.normal,
          color: color ?? (header ? PdfColors.blueGrey900 : PdfColors.grey900),
        ),
        maxLines: header ? 2 : 4,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }

  static Future<pw.ThemeData> _buildPdfTheme() async {
    try {
      final base = await PdfGoogleFonts.notoSansRegular();
      final bold = await PdfGoogleFonts.notoSansBold();
      final bengaliFallback = await PdfGoogleFonts.notoSansBengaliRegular();
      return pw.ThemeData.withFont(
        base: base,
        bold: bold,
        fontFallback: [bengaliFallback],
      );
    } catch (_) {
      return pw.ThemeData.base();
    }
  }

  static bool _isExpense(tx_models.TransactionModel tx) {
    return tx.transactionType.trim().toLowerCase() == 'expenses';
  }

  static bool _isCompanyExpense(tx_models.TransactionModel tx) {
    if (!_isExpense(tx)) return false;

    final source = tx.expenseSource.trim().toLowerCase().replaceAll('_', '-');
    return source != 'main-balance' && source != 'main balance';
  }

  static DateTime? _tryParseDate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final direct = DateTime.tryParse(trimmed);
    if (direct != null) {
      return DateTime(direct.year, direct.month, direct.day);
    }

    const patterns = [
      'dd MMM yyyy',
      'dd-MM-yyyy',
      'dd/MM/yyyy',
      'yyyy-MM-dd',
      'yyyy/MM/dd',
      'MM/dd/yyyy',
    ];

    for (final pattern in patterns) {
      try {
        final parsed = DateFormat(pattern).parseStrict(trimmed);
        return DateTime(parsed.year, parsed.month, parsed.day);
      } catch (_) {}
    }

    return null;
  }

  static double _parseAmount(String amount) {
    final cleaned = amount.replaceAll(',', '').trim();
    return double.tryParse(cleaned) ?? 0;
  }

  static String _currency(double amount) {
    return 'BDT ${amount.toInt()}';
  }

  static String _safe(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? 'N/A' : trimmed;
  }

  static String _pdfText(String value) {
    if (value.isEmpty) return '';
    final noNewLines = value.replaceAll('\n', ' ').replaceAll('\r', ' ');
    final normalizedSpacing = noNewLines.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalizedSpacing;
  }

  static String _formatType(String type) {
    final normalized = type.trim();
    if (normalized.isEmpty) return 'N/A';

    return normalized
        .split(RegExp(r'[-_\s]+'))
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  static Future<void> _showSaveSuccessModal(
    BuildContext context,
    GeneratedFileSaveResult savedFile,
    CompanyModel company,
    List<trip_models.TripModel> trips,
    List<tx_models.TransactionModel> transactions,
  ) async {
    final fileName = savedFile.fileName;
    final location = savedFile.locationLabel;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green.shade600,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Statement Saved Successfully',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  fileName,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  location,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.open_in_new, color: Colors.blue.shade600),
                  ),
                  title: Text(kIsWeb ? 'Preview Statement' : 'Open Statement'),
                  subtitle: Text(
                    kIsWeb
                        ? 'Open in a browser tab'
                        : 'View with default PDF viewer',
                  ),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await Future<void>.delayed(
                      const Duration(milliseconds: 150),
                    );
                    await openDownloadedStatement(
                      savedFile,
                      company: company,
                      trips: trips,
                      transactions: transactions,
                    );
                  },
                ),
                if (savedFile.supportsExplicitDownload)
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.download_rounded,
                        color: Colors.indigo.shade600,
                      ),
                    ),
                    title: const Text('Download Statement'),
                    subtitle: const Text('Save a copy from the browser'),
                    onTap: () async {
                      final downloaded = await _downloadService.triggerDownload(
                        savedFile,
                      );
                      if (sheetContext.mounted) {
                        Navigator.of(sheetContext).pop();
                      }
                      if (!downloaded && context.mounted) {
                        _showErrorDialog(
                          context,
                          'Unable to trigger browser download.',
                        );
                      }
                    },
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('Done'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  static void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.error_outline, color: Colors.red.shade400, size: 48),
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// PREVIEW PAGE (simple + consistent with ledger)
// ──────────────────────────────────────────────────────────────────────────────

class CompanyStatementPreviewPage extends StatelessWidget {
  const CompanyStatementPreviewPage({
    super.key,
    required this.company,
    required this.trips,
    required this.transactions,
  });

  final CompanyModel company;
  final List<trip_models.TripModel> trips;
  final List<tx_models.TransactionModel> transactions;

  @override
  Widget build(BuildContext context) {
    final ledger = CompanyStatementUtil._buildLedger(trips, transactions);

    final billed = ledger.totalTripBill;
    final paid = ledger.totalPayments;
    final expenses = ledger.totalExpenses;
    final due = ledger.closingDue;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statement Preview'),
        actions: [
          IconButton(
            tooltip: 'Save',
            icon: const Icon(Icons.download_outlined),
            onPressed: () => CompanyStatementUtil.saveCompanyStatementAndNotify(
              company: company,
              trips: trips,
              transactions: transactions,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _previewHeader(company),
          const SizedBox(height: 12),
          _previewSummary(
            billed: billed,
            paid: paid,
            expenses: expenses,
            due: due,
          ),
          const SizedBox(height: 14),
          const Text(
            'History',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (ledger.blocks.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('No history found for this company.'),
            )
          else
            ...ledger.blocks.map((b) => _previewDateBlock(b)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _previewHeader(CompanyModel company) {
    final now = DateTime.now();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF263238),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'COMPANY STATEMENT',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            CompanyStatementUtil._safe(company.name),
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            'Generated: ${DateFormat('dd MMM yyyy').format(now)}',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _previewSummary({
    required double billed,
    required double paid,
    required double expenses,
    required double due,
  }) {
    Widget box(String label, String value) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        box('Billed', CompanyStatementUtil._currency(billed)),
        const SizedBox(width: 8),
        box('Paid', CompanyStatementUtil._currency(paid)),
        const SizedBox(width: 8),
        box('Due', CompanyStatementUtil._currency(due)),
      ],
    );
  }

  Widget _previewDateBlock(_LedgerDateBlock block) {
    final openingBalance = block.entries.isEmpty
        ? block.balanceAfter
        : block.entries.first.balanceBefore;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            block.displayDate,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'Before Date: ${CompanyStatementUtil._currency(openingBalance)}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'After Date: ${CompanyStatementUtil._currency(block.balanceAfter)}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...block.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      e.particulars,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    CompanyStatementUtil._currency(
                      e.bill + e.expense - e.payment,
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: (e.payment > 0)
                          ? Colors.green.shade700
                          : Colors.blueGrey.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 18),
          _smallRow(
            'Subtotal Bill',
            CompanyStatementUtil._currency(block.billSubtotal),
          ),
          _smallRow(
            'Subtotal Paid',
            CompanyStatementUtil._currency(block.paymentSubtotal),
          ),
          _smallRow(
            'Subtotal Expenses',
            CompanyStatementUtil._currency(block.expenseSubtotal),
          ),
          const SizedBox(height: 6),
          _smallRow(
            'Balance After Date',
            CompanyStatementUtil._currency(block.balanceAfter),
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _smallRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// INTERNAL MODELS
// ──────────────────────────────────────────────────────────────────────────────

class _DateRange {
  const _DateRange(this.from, this.to);
  final String from;
  final String to;
}

class _LedgerBuildResult {
  _LedgerBuildResult({
    required this.openingDue,
    required this.blocks,
    required this.totalTripBill,
    required this.totalPayments,
    required this.totalExpenses,
    required this.closingDue,
  });

  final double openingDue;
  final List<_LedgerDateBlock> blocks;

  final double totalTripBill;
  final double totalPayments;
  final double totalExpenses;
  final double closingDue;
}

class _LedgerBucket {
  _LedgerBucket({
    required this.key,
    required this.rawDate,
    required this.parsedDate,
    required this.displayDate,
  });

  final String key;
  final String rawDate;
  final DateTime? parsedDate;
  final String displayDate;

  final List<trip_models.TripModel> trips = [];
  final List<tx_models.TransactionModel> payments = [];
  final List<tx_models.TransactionModel> expenses = [];
}

class _LedgerDateBlock {
  _LedgerDateBlock({
    required this.displayDate,
    required this.parsedDate,
    required this.entries,
    required this.billSubtotal,
    required this.paymentSubtotal,
    required this.expenseSubtotal,
    // required this.balanceBefore,
    required this.balanceAfter,
  });

  final String displayDate;
  final DateTime? parsedDate;

  final List<_LedgerEntry> entries;

  final double billSubtotal;
  final double paymentSubtotal;
  final double expenseSubtotal;
  // final double balanceBefore;
  final double balanceAfter;
}

class _LedgerEntry {
  _LedgerEntry({
    required this.particulars,
    required this.bill,
    required this.payment,
    required this.expense,
    required this.balanceBefore,
    required this.balanceAfter,
  });

  final String particulars;
  final double bill;
  final double payment;
  final double expense;
  final double balanceBefore;
  final double balanceAfter;
}
