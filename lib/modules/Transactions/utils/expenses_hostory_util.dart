import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/download/download_service.dart';
import '../../../core/services/firestore_services/tripdata_service.dart';
import '../models/transaction_model.dart';
import '../../trip/models/trip_model.dart' as trip_models;

class TransactionLedgerHistoryUtil {
  TransactionLedgerHistoryUtil._();

  static final DownloadService _downloadService = createDownloadService();

  static Future<void> saveTransactionLedgerAndNotify(
    List<TransactionModel> transactions, {
    String dateFilterLabel = 'All Time',
  }) async {
    final context = Get.context;
    if (context == null) return;

    if (transactions.isEmpty) {
      Get.snackbar(
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
  }) async {
    final bytes = await buildTransactionLedgerPdf(
      transactions,
      dateFilterLabel: dateFilterLabel,
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
  }) async {
    final pdf = pw.Document(
      title: 'Transaction Ledger',
      author: 'MarineLedger',
      creator: 'MarineLedger App',
      subject: 'Filtered transaction ledger export',
    );

    final ledger = await _buildLedger(transactions);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
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
            totalDebit: _formatAmount(ledger.totalDebit),
            totalCredit: _formatAmount(ledger.totalCredit),
            closingBalance: _formatAmount(ledger.closingBalance),
            dateFilterLabel: dateFilterLabel,
          ),
          pw.SizedBox(height: 14),
          _buildSummaryRow(ledger),
          pw.SizedBox(height: 10),
          _buildTable(ledger),
          pw.SizedBox(height: 12),
          //_buildNotes(),
        ],
      ),
    );

    return pdf.save();
  }

  static String fileNameFor() {
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return 'transaction_ledger_$stamp.pdf';
  }

  static pw.Widget _buildHeader(
    int count, {
    required String totalDebit,
    required String totalCredit,
    required String closingBalance,
    required String dateFilterLabel,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
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
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Debit / Credit / Balance ledger',
                style: const pw.TextStyle(color: PdfColors.white, fontSize: 10),
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
              _metaText('Total Debit', totalDebit),
              pw.SizedBox(height: 4),
              _metaText('Total Credit', totalCredit),
              pw.SizedBox(height: 4),
              _metaText('Closing Balance', closingBalance),
              pw.SizedBox(height: 4),
              _metaText('Showing Transactions For', dateFilterLabel),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryRow(_LedgerBuildResult ledger) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: _miniStat('Total Debit', _formatAmount(ledger.totalDebit)),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: _miniStat('Total Credit', _formatAmount(ledger.totalCredit)),
          ),
          pw.SizedBox(width: 8),
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

  static pw.Widget _buildTable(_LedgerBuildResult ledger) {
    final rows = <pw.TableRow>[];

    rows.add(
      pw.TableRow(
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

    if (ledger.entries.isEmpty) {
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

    for (final row in ledger.entries) {
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

    rows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.blueGrey900),
        children: [
          _cell('', color: PdfColors.white),
          _cell('', color: PdfColors.white),
          _cell('Closing Balance', color: PdfColors.white, bold: true),
          _cell('', color: PdfColors.white),
          _cell('', right: true, color: PdfColors.white),
          _cell('', right: true, color: PdfColors.white),
          _cell(
            _formatAmount(ledger.closingBalance),
            right: true,
            color: PdfColors.white,
            bold: true,
          ),
        ],
      ),
    );

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

  static pw.Widget _buildNotes() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.blueGrey200, width: 0.8),
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
          pw.SizedBox(height: 4),
          pw.Text(
            'Balance formula: previous + debit - credit. Debit includes payment and company due expense. Credit includes trip bill. Main-balance expense rows are listed as memo-only and do not affect balance.',
            style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey800),
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
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 11,
            color: PdfColors.blueGrey900,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    );
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

  static String _formatAmount(double amount) {
    final value = amount.toInt();
    return 'BDT $value';
  }

  static Future<_LedgerBuildResult> _buildLedger(
    List<TransactionModel> transactions,
  ) async {
    final items = <_LedgerRawItem>[];
    final tripById = await _loadTripIndexById(transactions);

    for (final tx in transactions) {
      final trip = _tripForTransaction(tx, tripById);
      final amount = _toDouble(tx.amount);
      final date = tx.date;
      final source = tx.normalizedExpenseSource;
      final company = _companyLabel(tx, trip);
      final route = _routeLabel(tx, trip);
      final product = _ledgerProductInfo(tx, trip);
      final pricingDetails = _pricingSnapshot(tx, trip);

      if (tx.isTrip) {
        final tripCredit = _tripCreditValue(tx, trip);
        items.add(
          _LedgerRawItem(
            dateRaw: date,
            description:
                'Trip Bill: $route\nCompany: $company\n$pricingDetails',
            product: product,
            debit: 0,
            credit: tripCredit,
            kindOrder: 0,
          ),
        );
        continue;
      }

      if (tx.isExpense && source == 'main-balance') {
        // Match company statement behavior: main-balance expense does not
        // participate in due ledger calculation.
        continue;
      }

      final label = tx.isExpense ? 'Due Expense' : 'Payment';
      final method = _labelType(tx.type);
      final sourceLabel = tx.isExpense
          ? '\nSource: ${tx.expenseSourceLabel}'
          : '';
      items.add(
        _LedgerRawItem(
          dateRaw: date,
          description:
              '$label ($method)$sourceLabel\nRoute: $route\nCompany: $company\n$pricingDetails',
          product: product,
          debit: amount,
          credit: 0,
          kindOrder: tx.isExpense ? 1 : 2,
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
    final normalized = type.trim().toLowerCase();
    if (normalized.isEmpty) return 'N/A';

    return normalized
        .split(RegExp(r'[-_\s]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
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

  static String _companyLabel(
    TransactionModel tx,
    trip_models.TripModel? trip,
  ) {
    final tripCompany = (trip?.companyAndShipInfo.companyName ?? '').trim();
    if (tripCompany.isNotEmpty) return tripCompany;

    final txCompany = tx.companyName.trim();
    return txCompany.isEmpty ? 'N/A' : txCompany;
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

    final txTotalPrice = _toDouble(tx.totalPrice);
    if (txTotalPrice > 0) return txTotalPrice;

    return _toDouble(tx.amount);
  }

  static String _ledgerProductInfo(
    TransactionModel tx,
    trip_models.TripModel? trip,
  ) {
    final tripProductName = (trip?.product?.productName ?? '').trim();
    final tripDescription = (trip?.product?.desctription ?? '').trim();
    final description = (tx.description ?? '').trim();

    final name = tripProductName.isEmpty ? 'N/A' : tripProductName;
    final resolvedDescription = tripDescription.isNotEmpty
        ? tripDescription
        : (description.isEmpty ? 'N/A' : description);

    return _pdfText('Name: $name\nDescription: $resolvedDescription');
  }

  static String _pricingSnapshot(
    TransactionModel tx,
    trip_models.TripModel? trip,
  ) {
    final tripRate = _toDouble(trip?.rate ?? '');
    final tripQuantity = (trip?.product?.quantity ?? '').trim();
    final tripUnit = (trip?.product?.unit ?? '').trim();

    final totalPrice = _toDouble(tx.totalPrice);
    final quantity = _toDouble(tx.amount);

    final computedRate = quantity > 0 ? totalPrice / quantity : 0;
    final resolvedRate = tripRate > 0 ? tripRate : computedRate;
    final rateText = resolvedRate > 0
        ? _formatAmount(resolvedRate.toDouble())
        : 'N/A';

    final amountRaw = tripQuantity.isNotEmpty
        ? (tripUnit.isEmpty ? tripQuantity : '$tripQuantity $tripUnit')
        : (tx.amount.trim().isEmpty ? 'N/A' : tx.amount.trim());

    return _pdfText('Rate: $rateText\nAmount: $amountRaw');
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

  DateTime? get parsedDate =>
      TransactionLedgerHistoryUtil._tryParseDate(dateRaw);

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
