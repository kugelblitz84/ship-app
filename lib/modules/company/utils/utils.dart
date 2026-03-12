import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/services/download/download_service.dart';
import '../../../core/services/firestore_services/userdata_service.dart';
import '../../Transactions/models/transaction_model.dart' as tx_models;
import '../../trip/models/trip_model.dart' as trip_models;
import '../models/company_model.dart';

class CompanyStatementUtil {
  CompanyStatementUtil._();

  static const int _maxLedgerEntriesPerPage = 6;
  static const double _estimatedLedgerHeaderHeight = 26;
  static const double _estimatedLedgerRowHeight = 24;
  static const double _estimatedClosingBoxHeight = 92;
  static const double _estimatedNotesBlockHeight = 88;
  static const double _estimatedTrailingGapHeight = 24;

  static final DownloadService _downloadService = createDownloadService();

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
    String? appliedFiltersLabel,
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
        appliedFiltersLabel: appliedFiltersLabel,
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
    String? appliedFiltersLabel,
  }) async {
    final bytes = await buildCompanyStatementPdf(
      company: company,
      trips: trips,
      transactions: transactions,
      appliedFiltersLabel: appliedFiltersLabel,
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
    String? appliedFiltersLabel,
  }) async {
    final ledger = _buildLedger(trips, transactions);
    final generatedAt = DateTime.now();
    final theme = await _buildPdfTheme();
    final companyName = _safe(company.name);
    final organizationName = await _resolveOrganizationName(companyName);

    final pdf = pw.Document(
      title: 'Company Statement',
      author: 'MarineLedger',
      creator: 'MarineLedger App',
      subject: 'Company statement ledger (debit/credit/balance)',
    );

    final dateRange = ledger.entries.isEmpty
        ? const _DateRange('--', '--')
        : _DateRange(
            ledger.entries.first.displayDate,
            ledger.entries.last.displayDate,
          );
    final resolvedAppliedFilters = (appliedFiltersLabel ?? '').trim().isEmpty
        ? '${_safe(company.name)} | Date Range: ${dateRange.from} to ${dateRange.to}'
        : appliedFiltersLabel!.trim();
    final entryChunks = _chunkLedgerEntries(ledger.entries);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
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
            organizationName: organizationName,
            appliedFiltersLabel: resolvedAppliedFilters,
          ),
          pw.SizedBox(height: 14),
          _buildCompanyInfoSection(
            company: company,
            fromDate: dateRange.from,
            toDate: dateRange.to,
            totalEntries: ledger.entries.length,
          ),
          pw.SizedBox(height: 14),
          _buildSummaryRow(
            totalDebit: _currency(ledger.totalDebit),
            totalCredit: _currency(ledger.totalCredit),
            closingBalance: _currency(ledger.closingBalance),
          ),
          pw.SizedBox(height: 14),
          _buildLedgerTitle(),
          pw.SizedBox(height: 8),
          for (var i = 0; i < entryChunks.length; i++) ...[
            if (i > 0) pw.NewPage(),
            if (i == entryChunks.length - 1)
              pw.NewPage(
                freeSpace: _estimateTrailingLedgerSectionHeight(
                  trailingRowCount: entryChunks[i].length,
                  includeClosingRow: true,
                  includeClosingBox: true,
                ),
              ),
            _buildLedgerTable(
              ledger,
              entries: entryChunks[i],
              includeClosingRow: i == entryChunks.length - 1,
            ),
            if (i < entryChunks.length - 1) pw.SizedBox(height: 8),
          ],
          pw.SizedBox(height: 12),
          _buildClosingBox(
            totalDebit: _currency(ledger.totalDebit),
            totalCredit: _currency(ledger.totalCredit),
            closingBalance: _currency(ledger.closingBalance),
          ),
          pw.SizedBox(height: 12),
          _buildNotesSection(company, ledger),
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

  static pw.Widget _buildHeader({
    required DateTime generatedAt,
    required String organizationName,
    required String appliedFiltersLabel,
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
                organizationName,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.05,
                ),
              ),
              pw.SizedBox(height: 6),
              // pw.Text(
              //   companyName,
              //   style: const pw.TextStyle(color: PdfColors.white, fontSize: 11),
              // ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Debit / Credit / Balance Ledger',
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
              _metaText('Source', 'MarineLedger App'),
              pw.SizedBox(height: 4),
              _metaText('Filters', appliedFiltersLabel),
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
    required int totalEntries,
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
        // pw.SizedBox(width: 12),
        // pw.Expanded(
        //   flex: 4,
        //   child: _infoCard(
        //     title: 'Overview',
        //     rows: [
        //       'Entries: $totalEntries',
        //       'Formula: previous + debit - credit',
        //       'Credit is bill + due-expense, debit is payment',
        //     ],
        //   ),
        // ),
      ],
    );
  }

  static pw.Widget _buildSummaryRow({
    required String totalDebit,
    required String totalCredit,
    required String closingBalance,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: _miniStat('Total Debit (Payment + Due Expense)', totalDebit),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: _miniStat('Total Credit (Trip Bill)', totalCredit),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: _miniStat('Closing Balance', closingBalance, bold: true),
          ),
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

  static pw.Widget _buildLedgerTitle() {
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
            'L',
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
              'Statement Ledger',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 12,
                color: PdfColors.blueGrey900,
              ),
            ),
            //pw.SizedBox(height: 2),
            // pw.Text(
            //   'Running balance using debit and credit only.',
            //   style: const pw.TextStyle(
            //     fontSize: 9.5,
            //     color: PdfColors.grey700,
            //   ),
            // ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildLedgerTable(
    _LedgerBuildResult ledger, {
    List<_LedgerEntry>? entries,
    bool includeClosingRow = true,
  }) {
    final rowsToRender = entries ?? ledger.entries;
    final rows = <pw.TableRow>[];

    rows.add(
      pw.TableRow(
        repeat: true,
        decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
        children: [
          _cell('ID', header: true),
          _cell('Date', header: true),
          _cell('Description', header: true),
          _cell('Product Info', header: true),
          _cell('Debit', header: true, right: true),
          _cell('Credit', header: true, right: true),
          _cell('Balance', header: true, right: true),
        ],
      ),
    );

    if (rowsToRender.isEmpty) {
      rows.add(
        pw.TableRow(
          children: [
            _cell(''),
            _cell(''),
            _cell('No ledger entries found.'),
            _cell(''),
            _cell('', right: true),
            _cell('', right: true),
            _cell(_currency(ledger.closingBalance), right: true),
          ],
        ),
      );
    }

    for (final entry in rowsToRender) {
      rows.add(
        pw.TableRow(
          children: [
            _cell(entry.id.toString()),
            _cell(entry.displayDate),
            _cell(entry.description, maxLines: 8),
            _cell(entry.product, maxLines: 8),
            _cell(entry.debit > 0 ? _currency(entry.debit) : '', right: true),
            _cell(entry.credit > 0 ? _currency(entry.credit) : '', right: true),
            _cell(_currency(entry.balance), right: true),
          ],
        ),
      );
    }

    if (includeClosingRow) {
      rows.add(
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blueGrey900),
          children: [
            _cell('', color: PdfColors.white),
            _cell('', color: PdfColors.white),
            _cell('Closing Balance', color: PdfColors.white, bold: true),
            _cell('', color: PdfColors.white),
            _cell(
              _currency(ledger.totalDebit),
              right: true,
              color: PdfColors.white,
              bold: true,
            ),
            _cell(
              _currency(ledger.totalCredit),
              right: true,
              color: PdfColors.white,
              bold: true,
            ),
            _cell(
              _currency(ledger.closingBalance),
              right: true,
              color: PdfColors.white,
              bold: true,
            ),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.75),
        1: const pw.FlexColumnWidth(1.35),
        2: const pw.FlexColumnWidth(2.8),
        3: const pw.FlexColumnWidth(2.2),
        4: const pw.FlexColumnWidth(1.45),
        5: const pw.FlexColumnWidth(1.45),
        6: const pw.FlexColumnWidth(1.5),
      },
      children: rows,
    );
  }

  static double _estimateTrailingLedgerSectionHeight({
    required int trailingRowCount,
    required bool includeClosingRow,
    required bool includeClosingBox,
  }) {
    final rowCount = trailingRowCount <= 0 ? 1 : trailingRowCount;
    final closingRows = includeClosingRow ? 1 : 0;

    var height =
        _estimatedLedgerHeaderHeight +
        ((rowCount + closingRows) * _estimatedLedgerRowHeight) +
        _estimatedTrailingGapHeight +
        _estimatedNotesBlockHeight;

    if (includeClosingBox) {
      height += _estimatedClosingBoxHeight;
    }

    return height;
  }

  static List<List<_LedgerEntry>> _chunkLedgerEntries(
    List<_LedgerEntry> entries,
  ) {
    if (entries.isEmpty) {
      return [<_LedgerEntry>[]];
    }

    final chunks = <List<_LedgerEntry>>[];
    for (var i = 0; i < entries.length; i += _maxLedgerEntriesPerPage) {
      var end = i + _maxLedgerEntriesPerPage;
      if (end > entries.length) {
        end = entries.length;
      }
      chunks.add(entries.sublist(i, end));
    }
    return chunks;
  }

  static pw.Widget _buildClosingBox({
    required String totalDebit,
    required String totalCredit,
    required String closingBalance,
  }) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 320,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
          borderRadius: pw.BorderRadius.circular(10),
        ),
        child: pw.Column(
          children: [
            _amountLine('Total Debit', totalDebit),
            pw.SizedBox(height: 6),
            _amountLine('Total Credit', totalCredit),
            pw.Divider(color: PdfColors.grey400, height: 14),
            _amountLine('Closing Balance', closingBalance, bold: true),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildNotesSection(
    CompanyModel company,
    _LedgerBuildResult ledger,
  ) {
    final description = (company.description ?? '').trim();

    final interpretation = ledger.closingBalance < 0
        ? 'Negative balance means receivable remains against the company.'
        : ledger.closingBalance > 0
        ? 'Positive balance means extra payment is available.'
        : 'Zero balance means the account is settled.';

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
                ? 'This statement is generated from trip bills (credit) and company due deductions + payments (debit).'
                : description,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
          ),
          pw.SizedBox(height: 8),
          // pw.Text(
          //   interpretation,
          //   style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700),
          // ),
        ],
      ),
    );
  }

  static _LedgerBuildResult _buildLedger(
    List<trip_models.TripModel> trips,
    List<tx_models.TransactionModel> transactions,
  ) {
    final items = <_LedgerRawItem>[];
    final tripById = <String, trip_models.TripModel>{
      for (final trip in trips) trip.tripId.trim(): trip,
    };

    for (final trip in trips) {
      items.add(
        _LedgerRawItem(
          dateRaw: trip.date,
          description: _tripDescription(trip),
          product: _tripProductWithDescription(trip),
          debit: 0,
          credit: _parseAmount(trip.totalBill),
          kindOrder: 0,
        ),
      );
    }

    for (final tx in transactions) {
      if (_isTripTransaction(tx)) {
        continue;
      }

      if (_isMainBalanceExpense(tx)) {
        continue;
      }

      if (_isCompanyAddedToDueExpense(tx)) {
        items.add(
          _LedgerRawItem(
            dateRaw: tx.date,
            description: _dueExpenseDescription(tx),
            product: _txProductOrDescription(tx, tripById),
            debit: _parseAmount(tx.amount),
            credit: 0,
            kindOrder: 0,
          ),
        );
        continue;
      }

      items.add(
        _LedgerRawItem(
          dateRaw: tx.date,
          description: _paymentDescription(tx, tripById),
          product: _txProductOrDescription(tx, tripById),
          debit: _parseAmount(tx.amount),
          credit: 0,
          kindOrder: 1,
        ),
      );
    }

    items.sort((a, b) {
      final ad = a.parsedDate;
      final bd = b.parsedDate;

      if (ad != null && bd != null) {
        final dateCmp = ad.compareTo(bd);
        if (dateCmp != 0) return dateCmp;
      } else if (ad != null) {
        return -1;
      } else if (bd != null) {
        return 1;
      }

      final kindCmp = a.kindOrder.compareTo(b.kindOrder);
      if (kindCmp != 0) return kindCmp;
      return a.description.compareTo(b.description);
    });

    final entries = <_LedgerEntry>[];
    var runningBalance = 0.0;
    var totalDebit = 0.0;
    var totalCredit = 0.0;

    var id = 0;
    for (final item in items) {
      id += 1;
      totalDebit += item.debit;
      totalCredit += item.credit;
      runningBalance = runningBalance + item.debit - item.credit;

      entries.add(
        _LedgerEntry(
          id: id,
          displayDate: item.displayDate,
          description: item.description,
          product: item.product,
          debit: item.debit,
          credit: item.credit,
          balance: runningBalance,
        ),
      );
    }

    return _LedgerBuildResult(
      entries: entries,
      totalDebit: totalDebit,
      totalCredit: totalCredit,
      closingBalance: runningBalance,
    );
  }

  static String _tripDescription(trip_models.TripModel trip) {
    final pricingDetails = _tripPricingDetails(trip);
    final from = _safe(trip.from);
    final to = _safe(trip.to);
    final company = _safe(trip.companyAndShipInfo.companyName);
    final shipPart = _optionalShipLine(trip.companyAndShipInfo.shipName);
    return _pdfText(
      'Trip bill: $from - $to\nCompany: $company$shipPart\n$pricingDetails',
    );
  }

  static String _tripPricingDetails(trip_models.TripModel trip) {
    if (trip.product == null) return '';

    final rateValue = _parseAmount(trip.rate);
    final quantity = (trip.product?.quantity ?? '').trim();
    final unit = (trip.product?.unit ?? '').trim();

    final rateText = rateValue > 0 ? _currency(rateValue) : 'N/A';
    final productAmountText = quantity.isEmpty
        ? 'N/A'
        : unit.isEmpty
        ? quantity
        : '$quantity $unit';

    return '\nRate: $rateText\nQuantity: $productAmountText';
  }

  static String _tripProductWithDescription(trip_models.TripModel trip) {
    final productName = (trip.product?.productName ?? '').trim();
    final productDescription = (trip.product?.desctription ?? '').trim();
    // final pricingDetails = _tripPricingDetails(trip);

    if (productName.isNotEmpty && productDescription.isNotEmpty) {
      return _pdfText('Name: $productName,\nDescription: $productDescription');
    }

    if (productName.isNotEmpty) {
      return _pdfText('Name: $productName');
    }

    if (productDescription.isNotEmpty) {
      return _pdfText('Description: $productDescription');
    }

    // if (pricingDetails.isNotEmpty) {
    //   return _pdfText(pricingDetails.trim());
    // }

    return _pdfText('Name: N/A\nDescription: N/A');
  }

  static String _paymentDescription(
    tx_models.TransactionModel tx,
    Map<String, trip_models.TripModel> tripById,
  ) {
    final method = _formatType(tx.type);
    final company = _safe(tx.companyAndShipInfo.companyName ?? 'N/A');
    final shipPart = _optionalShipLine(tx.companyAndShipInfo.shipName);
    final route = tx.hasTrip ? _pdfText(tx.routeLabel) : '';
    final routePart = route.isNotEmpty ? '\nRoute: $route' : '';
    return _pdfText('Payment ($method)$routePart\nCompany: $company$shipPart');
  }

  static String _dueExpenseDescription(tx_models.TransactionModel tx) {
    final company = _safe(tx.companyAndShipInfo.companyName ?? 'N/A');
    // final source = _formatType(tx.expenseSource);
    final method = _formatType(tx.type);
    final shipPart = _optionalShipLine(tx.companyAndShipInfo.shipName);
    final route = tx.hasTrip ? _pdfText(tx.routeLabel) : '';
    final routePart = route.isNotEmpty ? '\nRoute: $route' : '';
    return _pdfText(
      'Due Expense ($method)$routePart\nCompany: $company$shipPart',
    );
  }

  static String _txProductOrDescription(
    tx_models.TransactionModel tx,
    Map<String, trip_models.TripModel> tripById,
  ) {
    final desc = (tx.description ?? '').trim();

    final tripId = tx.tripId.trim();
    if (tripId.isNotEmpty) {
      final trip = tripById[tripId];
      if (trip != null) {
        return _tripProductWithDescription(trip);
      }
    }

    final resolvedDescription = desc.isEmpty ? 'N/A' : desc;
    return _pdfText('Name: N/A\nDescription: $resolvedDescription');
  }

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
    int? maxLines,
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
        maxLines: maxLines ?? (header ? 2 : 4),
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

  static bool _isTripTransaction(tx_models.TransactionModel tx) {
    return tx.transactionType.trim().toLowerCase() == 'trips';
  }

  static bool _isExpense(tx_models.TransactionModel tx) {
    return tx.transactionType.trim().toLowerCase() == 'expenses';
  }

  static bool _isMainBalanceExpense(tx_models.TransactionModel tx) {
    if (!_isExpense(tx)) return false;

    final normalizedSource = tx.expenseSource
        .trim()
        .toLowerCase()
        .replaceAll('_', '-')
        .replaceAll(' ', '-');

    return normalizedSource == 'main-balance';
  }

  static bool _isCompanyAddedToDueExpense(tx_models.TransactionModel tx) {
    return _isExpense(tx) && !_isMainBalanceExpense(tx);
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
    return '${amount.toInt()}';
  }

  static String _safe(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? 'N/A' : trimmed;
  }

  static String _pdfText(String value) {
    if (value.isEmpty) return '';

    final normalizedLineBreaks = value
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');

    final lines = normalizedLineBreaks
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((line) => line.isNotEmpty)
        .toList();

    return lines.join('\n');
  }

  static String _optionalShipLine(String? shipName) {
    final trimmed = (shipName ?? '').trim();
    if (trimmed.isEmpty) return '';
    return '\nShip: $trimmed';
  }

  static Future<String> _resolveOrganizationName(String fallback) async {
    try {
      if (!Get.isRegistered<FirestoreUserService>()) return fallback;

      final userData = await Get.find<FirestoreUserService>().getUserDetails();
      final org = userData.organization.trim();
      return org.isEmpty ? fallback : org;
    } catch (_) {
      return fallback;
    }
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
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.download,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    title: const Text('Download Statement'),
                    subtitle: const Text('Save a copy from the browser'),
                    onTap: () async {
                      final ok = await _downloadService.triggerDownload(
                        savedFile,
                      );
                      if (!ok && context.mounted) {
                        _showErrorDialog(
                          context,
                          'Unable to trigger download for this statement.',
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
          _previewSummary(ledger),
          const SizedBox(height: 14),
          const Text(
            'Ledger',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (ledger.entries.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('No ledger entries found for this company.'),
            )
          else
            ...ledger.entries.map(_previewEntryCard),
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

  Widget _previewSummary(_LedgerBuildResult ledger) {
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
        box('Debit', CompanyStatementUtil._currency(ledger.totalDebit)),
        const SizedBox(width: 8),
        box('Credit', CompanyStatementUtil._currency(ledger.totalCredit)),
        const SizedBox(width: 8),
        box('Balance', CompanyStatementUtil._currency(ledger.closingBalance)),
      ],
    );
  }

  Widget _previewEntryCard(_LedgerEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${entry.id}. ${entry.displayDate}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            entry.description,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _miniValue(
                  'Product',
                  entry.product.isEmpty ? '-' : entry.product,
                ),
              ),
              Expanded(
                child: _miniValue(
                  'Debit',
                  entry.debit > 0
                      ? CompanyStatementUtil._currency(entry.debit)
                      : '-',
                ),
              ),
              Expanded(
                child: _miniValue(
                  'Credit',
                  entry.credit > 0
                      ? CompanyStatementUtil._currency(entry.credit)
                      : '-',
                ),
              ),
              Expanded(
                child: _miniValue(
                  'Balance',
                  CompanyStatementUtil._currency(entry.balance),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _DateRange {
  const _DateRange(this.from, this.to);
  final String from;
  final String to;
}

class _LedgerRawItem {
  _LedgerRawItem({
    required this.dateRaw,
    required this.description,
    required this.product,
    required this.debit,
    required this.credit,
    required this.kindOrder,
  }) : parsedDate = CompanyStatementUtil._tryParseDate(dateRaw),
       displayDate = _resolveDisplayDate(dateRaw);

  final String dateRaw;
  final String description;
  final String product;
  final double debit;
  final double credit;
  final int kindOrder;
  final DateTime? parsedDate;
  final String displayDate;

  static String _resolveDisplayDate(String rawDate) {
    final parsed = CompanyStatementUtil._tryParseDate(rawDate);
    if (parsed != null) {
      return DateFormat('dd MMM yyyy').format(parsed);
    }

    final trimmed = rawDate.trim();
    return trimmed.isEmpty ? 'Unknown Date' : trimmed;
  }
}

class _LedgerBuildResult {
  _LedgerBuildResult({
    required this.entries,
    required this.totalDebit,
    required this.totalCredit,
    required this.closingBalance,
  });

  final List<_LedgerEntry> entries;
  final double totalDebit;
  final double totalCredit;
  final double closingBalance;
}

class _LedgerEntry {
  _LedgerEntry({
    required this.id,
    required this.displayDate,
    required this.description,
    required this.product,
    required this.debit,
    required this.credit,
    required this.balance,
  });

  final int id;
  final String displayDate;
  final String description;
  final String product;
  final double debit;
  final double credit;
  final double balance;
}
