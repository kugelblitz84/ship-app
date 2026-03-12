import 'dart:typed_data';
import 'package:urgent/core/widgets/app_snackbar.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/services/download/download_service.dart';
import '../../../core/services/firestore_services/tripdata_service.dart';
import '../models/transaction_model.dart';
import '../../trip/models/trip_model.dart' as trip_models;

class TransactionLedgerUtil {
  TransactionLedgerUtil._();

  static const int _maxLedgerEntriesPerPage = 7;
  static const double _estimatedLedgerHeaderHeight = 26;
  static const double _estimatedLedgerRowHeight = 24;
  static const double _estimatedNotesBlockHeight = 84;
  static const double _estimatedTrailingGapHeight = 12;

  static final DownloadService _downloadService = createDownloadService();

  static Future<void> saveTransactionLedgerAndNotify(
    List<TransactionModel> transactions, {
    String dateFilterLabel = 'All Time',
    String? appliedFiltersLabel,
  }) async {
    final context = Get.context;
    if (context == null) return;

    if (transactions.isEmpty) {
      showAppSnackbar(
        'No Transactions',
        'No filtered transactions found to export ledger.',
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final savedFile = await saveTransactionLedgerToFile(
        transactions,
        dateFilterLabel: dateFilterLabel,
        appliedFiltersLabel: appliedFiltersLabel,
      );

      if (context.mounted) {
        Navigator.of(context).pop();
      }

      await _showSaveSuccessModal(context, savedFile, transactions.length);
    } catch (_) {
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      _showErrorDialog(
        context,
        'Unable to save transaction ledger file. Please try again.',
      );
    }
  }

  static Future<GeneratedFileSaveResult> saveTransactionLedgerToFile(
    List<TransactionModel> transactions, {
    String dateFilterLabel = 'All dates',
    String? appliedFiltersLabel,
  }) async {
    final bytes = await buildTransactionLedgerPdf(
      transactions,
      dateFilterLabel: dateFilterLabel,
      appliedFiltersLabel: appliedFiltersLabel,
    );

    final file = GeneratedFileData(
      bytes: bytes,
      fileName: fileNameFor(),
      mimeType: 'application/pdf',
    );

    return _downloadService.saveFile(file);
  }

  static Future<Uint8List> buildTransactionLedgerPdf(
    List<TransactionModel> transactions, {
    String dateFilterLabel = 'All dates',
    String? appliedFiltersLabel,
  }) async {
    final theme = await _buildPdfTheme();
    final pdf = pw.Document(
      title: 'Transaction Ledger',
      author: 'MarineLedger',
      creator: 'MarineLedger App',
      subject: 'Filtered transaction debit/credit ledger export',
    );

    final ledger = await _buildLedger(transactions);
    final entryChunks = _chunkLedgerEntries(ledger.entries);
    final resolvedAppliedFilters = (appliedFiltersLabel ?? '').trim().isEmpty
        ? '$dateFilterLabel'
        : appliedFiltersLabel!.trim();

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
            ledger.entries.length,
            appliedFiltersLabel: resolvedAppliedFilters,
          ),
          pw.SizedBox(height: 14),
          _buildSummaryRow(ledger),
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
                ),
              ),
            _buildTable(
              ledger,
              entries: entryChunks[i],
              includeClosingRow: i == entryChunks.length - 1,
            ),
            if (i < entryChunks.length - 1) pw.SizedBox(height: 8),
          ],
          pw.SizedBox(height: 12),
          _buildNotes(),
        ],
      ),
    );

    return pdf.save();
  }

  static String fileNameFor() {
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return 'transaction_ledger_$stamp.pdf';
  }

  static Future<_LedgerBuildResult> _buildLedger(
    List<TransactionModel> transactions,
  ) async {
    final items = <_LedgerRawItem>[];
    final tripById = await _loadTripIndexById(transactions);

    for (final tx in transactions) {
      final trip = _tripForTransaction(tx, tripById);
      final amount = _toDouble(tx.amount);
      final credit = tx.isTrip ? _tripCreditValue(tx, trip) : 0.0;
      final debit = tx.isTrip ? 0.0 : amount;
      final method = _labelType(tx.type);
      final company = _companyLabel(tx, trip);
      final ship = _shipLabel(tx, trip);
      final route = _routeLabel(tx, trip);
      final routePart = route == 'N/A' ? '' : '\nRoute: $route';
      final shipPart = ship == 'N/A' ? '' : '\nShip: $ship';
      final pricingDetails = tx.isTrip ? _tripPricingDetails(trip) : '';
      final pricingPart = pricingDetails.isEmpty ? '' : '\n$pricingDetails';
      final txDescription = _txDescriptionPart(tx);

      final description = tx.isTrip
          ? 'Trip Bill$routePart\nCompany: $company$shipPart$pricingPart$txDescription'
          : '${_entryLabel(tx)} ($method)$routePart\nCompany: $company$shipPart$txDescription';

      items.add(
        _LedgerRawItem(
          dateRaw: tx.date,
          description: description,
          product: _ledgerProductInfo(trip),
          debit: debit,
          credit: credit,
          kindOrder: tx.isTrip ? 0 : 1,
        ),
      );
    }

    items.sort((a, b) {
      final ad = a.parsedDate;
      final bd = b.parsedDate;

      if (ad != null && bd != null) {
        final cmp = ad.compareTo(bd);
        if (cmp != 0) return cmp;
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
    var running = 0.0;
    var totalDebit = 0.0;
    var totalCredit = 0.0;
    var id = 0;

    for (final item in items) {
      id += 1;
      totalDebit += item.debit;
      totalCredit += item.credit;
      running = running + item.debit - item.credit;

      entries.add(
        _LedgerEntry(
          id: id,
          date: item.displayDate,
          description: item.description,
          product: item.product,
          debit: item.debit,
          credit: item.credit,
          balance: running,
        ),
      );
    }

    return _LedgerBuildResult(
      entries: entries,
      totalDebit: totalDebit,
      totalCredit: totalCredit,
      closingBalance: running,
    );
  }

  static String _entryLabel(TransactionModel tx) {
    if (tx.isExpense) return 'Expense';
    if (tx.isPayment) return 'Payment';
    return 'Debit Entry';
  }

  static String _companyLabel(
    TransactionModel tx,
    trip_models.TripModel? trip,
  ) {
    final tripName = (trip?.companyAndShipInfo.companyName ?? '').trim();
    if (tripName.isNotEmpty) return tripName;

    final name = tx.companyAndShipInfo.companyName?.trim() ?? '';
    return name.isEmpty ? 'N/A' : name;
  }

  static String _shipLabel(TransactionModel tx, trip_models.TripModel? trip) {
    final tripShip = (trip?.companyAndShipInfo.shipName ?? '').trim();
    if (tripShip.isNotEmpty) return tripShip;

    final ship = tx.companyAndShipInfo.shipName?.trim() ?? '';
    return ship.isEmpty ? 'N/A' : ship;
  }

  static String _routeLabel(TransactionModel tx, trip_models.TripModel? trip) {
    if (trip != null) {
      final from = trip.from.trim();
      final to = trip.to.trim();
      if (from.isNotEmpty && to.isNotEmpty) {
        return '$from - $to';
      }
    }

    return tx.hasTrip ? tx.routeLabel : 'N/A';
  }

  static double _tripCreditValue(
    TransactionModel tx,
    trip_models.TripModel? trip,
  ) {
    final tripBill = _toDouble(trip?.totalBill ?? '');
    if (tripBill > 0) return tripBill;

    final fromTotalPrice = _toDouble(tx.totalPrice);
    if (fromTotalPrice > 0) return fromTotalPrice;
    return _toDouble(tx.amount);
  }

  static String _ledgerProductInfo(trip_models.TripModel? trip) {
    final tripProductName = (trip?.product?.productName ?? '').trim();
    final tripProductDescription = (trip?.product?.desctription ?? '').trim();

    final name = tripProductName.isEmpty ? 'N/A' : tripProductName;
    final description = tripProductDescription.isEmpty
        ? 'N/A'
        : tripProductDescription;

    return _pdfText('Name: $name\nDescription: $description');
  }

  static String _txDescriptionPart(TransactionModel tx) {
    final description = (tx.description ?? '').trim();
    if (description.isEmpty) return '';
    return '\nDescription: ${_pdfText(description)}';
  }

  static String _tripPricingDetails(trip_models.TripModel? trip) {
    if (trip?.product == null) return '';

    final rateValue = _toDouble(trip?.rate ?? '');
    final quantity = (trip?.product?.quantity ?? '').trim();
    final unit = (trip?.product?.unit ?? '').trim();

    final rateText = rateValue > 0 ? _formatAmount(rateValue) : 'N/A';
    final quantityText = quantity.isEmpty
        ? 'N/A'
        : unit.isEmpty
        ? quantity
        : '$quantity $unit';

    return _pdfText('Rate: $rateText\nQuantity: $quantityText');
  }

  static Future<Map<String, trip_models.TripModel>> _loadTripIndexById(
    List<TransactionModel> transactions,
  ) async {
    final neededIds = transactions
        .map((tx) => tx.tripId.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    if (neededIds.isEmpty || !Get.isRegistered<FirestoreTripService>()) {
      return <String, trip_models.TripModel>{};
    }

    try {
      final allTrips = await Get.find<FirestoreTripService>().getTrips();
      final index = <String, trip_models.TripModel>{};
      for (final trip in allTrips) {
        final id = trip.tripId.trim();
        if (id.isNotEmpty && neededIds.contains(id)) {
          index[id] = trip;
        }
      }
      return index;
    } catch (_) {
      return <String, trip_models.TripModel>{};
    }
  }

  static trip_models.TripModel? _tripForTransaction(
    TransactionModel tx,
    Map<String, trip_models.TripModel> tripById,
  ) {
    final id = tx.tripId.trim();
    if (id.isEmpty) return null;
    return tripById[id];
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

  static String _labelType(String type) {
    final trimmed = type.trim();
    if (trimmed.isEmpty) return 'N/A';
    return trimmed;
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

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) {
      final sanitized = value.replaceAll(',', '').trim();
      return double.tryParse(sanitized) ?? 0;
    }
    return 0;
  }

  static String _formatAmount(double amount) {
    return '${amount.toInt()}';
  }

  static pw.Widget _buildHeader(
    int count, {
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
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'TRANSACTION LEDGER',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.05,
                ),
              ),
              pw.SizedBox(height: 6),
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
                DateFormat('dd MMM yyyy').format(DateTime.now()),
              ),
              pw.SizedBox(height: 4),
              _metaText('Total Rows', '$count'),
              pw.SizedBox(height: 4),
              _metaText('Filters', appliedFiltersLabel),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryRow(_LedgerBuildResult ledger) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: _miniStat('Total Debit', _formatAmount(ledger.totalDebit)),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: _miniStat('Total Credit', _formatAmount(ledger.totalCredit)),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: _miniStat(
              'Closing Balance',
              _formatAmount(ledger.closingBalance),
              bold: true,
            ),
          ),
        ],
      ),
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
        pw.Text(
          'Statement Ledger',
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 12,
            color: PdfColors.blueGrey900,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTable(
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
            _cell(_formatAmount(ledger.closingBalance), right: true),
          ],
        ),
      );
    }

    for (final row in rowsToRender) {
      rows.add(
        pw.TableRow(
          children: [
            _cell('${row.id}'),
            _cell(row.date),
            _cell(row.description, maxLines: 8),
            _cell(row.product, maxLines: 8),
            _cell(row.debit > 0 ? _formatAmount(row.debit) : '', right: true),
            _cell(row.credit > 0 ? _formatAmount(row.credit) : '', right: true),
            _cell(_formatAmount(row.balance), right: true),
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
              _formatAmount(ledger.totalDebit),
              right: true,
              color: PdfColors.white,
              bold: true,
            ),
            _cell(
              _formatAmount(ledger.totalCredit),
              right: true,
              color: PdfColors.white,
              bold: true,
            ),
            _cell(
              _formatAmount(ledger.closingBalance),
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
      columnWidths: const {
        0: pw.FlexColumnWidth(0.8),
        1: pw.FlexColumnWidth(1.3),
        2: pw.FlexColumnWidth(2.9),
        3: pw.FlexColumnWidth(2.2),
        4: pw.FlexColumnWidth(1.25),
        5: pw.FlexColumnWidth(1.25),
        6: pw.FlexColumnWidth(1.3),
      },
      children: rows,
    );
  }

  static double _estimateTrailingLedgerSectionHeight({
    required int trailingRowCount,
    required bool includeClosingRow,
  }) {
    final rowCount = trailingRowCount <= 0 ? 1 : trailingRowCount;
    final closingRows = includeClosingRow ? 1 : 0;

    return _estimatedLedgerHeaderHeight +
        ((rowCount + closingRows) * _estimatedLedgerRowHeight) +
        _estimatedTrailingGapHeight +
        _estimatedNotesBlockHeight;
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

  static pw.Widget _buildNotes() {
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
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey900,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'This statement is generated from filtered transactions only. Trip entries are credit; all other entries are debit.',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
          ),
        ],
      ),
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
            color: PdfColors.blueGrey900,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
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

  static pw.Widget _metaText(String label, String value) {
    return pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '$label: ',
            style: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
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

  static Future<void> _showSaveSuccessModal(
    BuildContext context,
    GeneratedFileSaveResult savedFile,
    int rowCount,
  ) async {
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
                  'Transaction Ledger Saved',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '${savedFile.fileName} ($rowCount rows)',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  savedFile.locationLabel,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.open_in_new, color: Colors.blue.shade600),
                  ),
                  title: const Text('Open Ledger PDF'),
                  subtitle: const Text('View with default PDF viewer'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await Future<void>.delayed(
                      const Duration(milliseconds: 150),
                    );
                    await _openDownloadedFile(savedFile);
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
                    title: const Text('Download PDF'),
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
                          'Unable to trigger browser download for this ledger.',
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

  static Future<void> _openDownloadedFile(GeneratedFileSaveResult file) async {
    final opened = await _downloadService.openSavedFile(
      savedFile: file,
      mimeType: 'application/pdf',
    );

    if (!opened) {
      final context = Get.context;
      if (context != null) {
        _showErrorDialog(context, 'Unable to open the saved ledger PDF file.');
      }
    }
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

class _LedgerRawItem {
  _LedgerRawItem({
    required this.dateRaw,
    required this.description,
    required this.product,
    required this.debit,
    required this.credit,
    required this.kindOrder,
  });

  final String dateRaw;
  final String description;
  final String product;
  final double debit;
  final double credit;
  final int kindOrder;

  DateTime? get parsedDate => TransactionLedgerUtil._tryParseDate(dateRaw);

  String get displayDate {
    final parsed = parsedDate;
    if (parsed != null) {
      return DateFormat('dd MMM yyyy').format(parsed);
    }
    final trimmed = dateRaw.trim();
    return trimmed.isEmpty ? 'Unknown Date' : trimmed;
  }
}

class _LedgerEntry {
  _LedgerEntry({
    required this.id,
    required this.date,
    required this.description,
    required this.product,
    required this.debit,
    required this.credit,
    required this.balance,
  });

  final int id;
  final String date;
  final String description;
  final String product;
  final double debit;
  final double credit;
  final double balance;
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
