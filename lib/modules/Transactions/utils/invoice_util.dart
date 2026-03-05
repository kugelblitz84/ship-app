import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/download/download_service.dart';

import '../models/transaction_model.dart';

class InvoiceUtil {
  InvoiceUtil._();

  static final DownloadService _downloadService = createDownloadService();

  static Future<void> saveInvoiceAndNotify(TransactionModel transaction) async {
    final context = Get.context;
    if (context == null) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final savedFile = await saveInvoiceToFile(transaction);
      if (context.mounted) Navigator.of(context).pop(); // dismiss loading
      await _showSaveSuccessModal(context, savedFile, transaction);
    } catch (_) {
      if (context.mounted) Navigator.of(context).pop(); // dismiss loading
      _showErrorDialog(
        context,
        'Unable to save invoice file. Please try again.',
      );
    }
  }

  static Future<void> _showSaveSuccessModal(
    BuildContext context,
    GeneratedFileSaveResult savedFile,
    TransactionModel transaction,
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
                // Success icon and title
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
                  'Invoice Saved Successfully',
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
                const SizedBox(height: 12),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.open_in_new, color: Colors.blue.shade600),
                  ),
                  title: Text(kIsWeb ? 'Preview Invoice' : 'Open Invoice'),
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
                    await openDownloadedInvoice(
                      savedFile,
                      transaction: transaction,
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
                    title: const Text('Download Invoice'),
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

  static Future<GeneratedFileSaveResult> saveInvoiceToFile(
    TransactionModel transaction,
  ) async {
    final bytes = await buildInvoicePdf(transaction);
    final file = GeneratedFileData(
      bytes: bytes,
      fileName: fileNameFor(transaction),
      mimeType: 'application/pdf',
    );
    return _downloadService.saveFile(file);
  }

  static Future<void> openDownloadedInvoice(
    GeneratedFileSaveResult savedFile, {
    TransactionModel? transaction,
  }) async {
    try {
      final opened = await _downloadService.openSavedFile(
        savedFile: savedFile,
        mimeType: 'application/pdf',
      );

      if (opened) {
        return;
      }

      if (transaction != null) {
        Get.to(() => InvoicePreviewPage(transaction: transaction));
        return;
      }

      final context = Get.context;
      if (context != null) {
        _showErrorDialog(context, 'Unable to open the saved invoice file.');
      }
    } catch (_) {
      if (transaction != null) {
        Get.to(() => InvoicePreviewPage(transaction: transaction));
        return;
      }

      final context = Get.context;
      if (context != null) {
        _showErrorDialog(context, 'Unable to open the saved invoice file.');
      }
    }
  }

  static Future<Uint8List> buildInvoicePdf(TransactionModel transaction) async {
    final pdf = pw.Document(
      title: 'Invoice',
      author: 'Urgent',
      creator: 'Urgent App',
      subject: 'Transaction invoice',
    );

    final generatedAt = DateTime.now();
    final displayDate = _formatDate(transaction.date);
    final amount = _parseAmount(transaction.amount);
    final totalPrice = _parseAmount(transaction.totalPrice);
    final amountDue = _parseAmount(transaction.amountDue);
    const taxRate = 0.0;
    final taxAmount = amount * taxRate;
    final total = amount + taxAmount;
    final amountFormatted = _currency(amount);
    final taxFormatted = _currency(taxAmount);
    final totalFormatted = _currency(total);
    final totalPriceFormatted = _currency(totalPrice);
    final amountDueFormatted = _currency(amountDue);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 12),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (_) => [
          _buildHeader(generatedAt: generatedAt, transactionDate: displayDate),
          pw.SizedBox(height: 18),
          _buildCompanyAndTripSection(transaction),
          pw.SizedBox(height: 18),
          _buildPaymentMetaRow(transaction),
          pw.SizedBox(height: 18),
          _buildItemsTable(
            transaction: transaction,
            amountFormatted: amountFormatted,
          ),
          pw.SizedBox(height: 16),
          _buildTotals(
            subtotal: amountFormatted,
            tax: taxFormatted,
            total: totalFormatted,
            totalPrice: totalPriceFormatted,
            amountDue: amountDueFormatted,
          ),
          pw.SizedBox(height: 16),
          _buildNotesSection(transaction),
        ],
      ),
    );

    return pdf.save();
  }

  static String fileNameFor(TransactionModel transaction) {
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return 'invoice_$stamp.pdf';
  }

  static pw.Widget _buildHeader({
    required DateTime generatedAt,
    required String transactionDate,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey900,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'INVOICE',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 26,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'Urgent Transport Billing',
                style: const pw.TextStyle(color: PdfColors.white, fontSize: 10),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              _metaText(
                'Invoice Date',
                _formatDate(generatedAt.toIso8601String()),
              ),
              pw.SizedBox(height: 4),
              _metaText('Transaction Date', transactionDate),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildCompanyAndTripSection(TransactionModel transaction) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _infoCard(
            title: 'Billed To',
            rows: [
              _safe(transaction.companyAndShipInfo.companyName),
              'Ship: ${_safe(transaction.companyAndShipInfo.shipName ?? 'null')}',
            ],
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: _infoCard(
            title: 'Trip Details',
            rows: [
              'From: ${_safe(transaction.tripFrom)}',
              'To: ${_safe(transaction.tripTo)}',
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildPaymentMetaRow(TransactionModel transaction) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: _pill(
            title: 'Transaction Type',
            value: _formatTransactionCategory(transaction.transactionType),
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: _pill(
            title:
                transaction.transactionType.trim().toLowerCase() == 'expenses'
                ? 'Expense Source'
                : 'Payment Method',
            value:
                transaction.transactionType.trim().toLowerCase() == 'expenses'
                ? _formatExpenseSource(transaction.expenseSource)
                : _formatType(transaction.type),
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: _pill(title: 'Source', value: 'Urgent App'),
        ),
      ],
    );
  }

  static pw.Widget _buildItemsTable({
    required TransactionModel transaction,
    required String amountFormatted,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.2),
        1: const pw.FlexColumnWidth(4),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
          children: [
            _tableCell('Item', isHeader: true),
            _tableCell('Description', isHeader: true),
            _tableCell('Qty', isHeader: true),
            _tableCell('Amount', isHeader: true, alignRight: true),
          ],
        ),
        pw.TableRow(
          children: [
            _tableCell('1'),
            _tableCell(
              transaction.transactionType.trim().toLowerCase() == 'expenses'
                  ? 'Transport expense (${_formatExpenseSource(transaction.expenseSource)}) for ${_safe(transaction.tripFrom)} to ${_safe(transaction.tripTo)}'
                  : 'Transport payment for ${_safe(transaction.tripFrom)} to ${_safe(transaction.tripTo)} (${_formatType(transaction.type)})',
            ),
            _tableCell('1'),
            _tableCell(amountFormatted, alignRight: true),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildTotals({
    required String subtotal,
    required String tax,
    required String total,
    required String totalPrice,
    required String amountDue,
  }) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 230,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          children: [
            _amountLine('Subtotal', subtotal),
            pw.SizedBox(height: 6),
            _amountLine('Tax', tax),
            pw.Divider(color: PdfColors.grey400, height: 14),
            _amountLine('Total', total, bold: true),
            pw.SizedBox(height: 6),
            _amountLine('Total Price', totalPrice),
            pw.SizedBox(height: 6),
            _amountLine('Amount Due', amountDue, bold: true),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildNotesSection(TransactionModel transaction) {
    final description = (transaction.description ?? '').trim();
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
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
                ? 'This invoice is generated from transaction records in the Urgent app.'
                : description,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
          ),
        ],
      ),
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
        borderRadius: pw.BorderRadius.circular(8),
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
              padding: const pw.EdgeInsets.only(bottom: 2),
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

  static pw.Widget _pill({required String title, required String value}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(20),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            title,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.SizedBox(width: 6),
          pw.Expanded(
            child: pw.Text(
              value,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _tableCell(
    String value, {
    bool isHeader = false,
    bool alignRight = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Text(
        value,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: 9.5,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.blueGrey900 : PdfColors.grey900,
        ),
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

  static String _safe(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? 'N/A' : trimmed;
  }

  static double _parseAmount(String amount) {
    final cleaned = amount.replaceAll(',', '').trim();
    return double.tryParse(cleaned) ?? 0;
  }

  static String _currency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_US',
      symbol: 'BDT ',
      decimalDigits: amount % 1 == 0 ? 0 : 2,
    );
    return formatter.format(amount);
  }

  static String _formatDate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return '--';
    }

    final parsed = DateTime.tryParse(trimmed);
    if (parsed == null) {
      return trimmed;
    }

    return DateFormat('dd MMM yyyy').format(parsed);
  }

  static String _formatType(String type) {
    final normalized = type.trim();
    if (normalized.isEmpty) {
      return 'N/A';
    }

    return normalized
        .split('-')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  static String _formatTransactionCategory(String transactionType) {
    final normalized = transactionType.trim().toLowerCase();
    if (normalized == 'expenses') {
      return 'Expenses';
    }
    return 'Payment';
  }

  static String _formatExpenseSource(String expenseSource) {
    final normalized = expenseSource.trim().toLowerCase();
    if (normalized == 'main-balance') {
      return 'From Main Balance';
    }
    if (normalized == 'company') {
      return 'Added to Due';
    }
    if (normalized.isEmpty) {
      return 'N/A';
    }

    return normalized
        .split(RegExp(r'[-_\s]+'))
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
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

class InvoicePreviewPage extends StatelessWidget {
  const InvoicePreviewPage({super.key, required this.transaction});

  final TransactionModel transaction;

  String _safe(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? 'N/A' : trimmed;
  }

  String _formatDate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '--';
    final parsed = DateTime.tryParse(trimmed);
    if (parsed == null) return trimmed;
    return DateFormat('dd MMM yyyy').format(parsed);
  }

  String _formatType(String type) {
    final normalized = type.trim();
    if (normalized.isEmpty) return 'N/A';
    return normalized
        .split('-')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  String _formatTransactionCategory(String transactionType) {
    final normalized = transactionType.trim().toLowerCase();
    if (normalized == 'expenses') return 'Expenses';
    return 'Payment';
  }

  static String _formatExpenseSource(String expenseSource) {
    final normalized = expenseSource.trim().toLowerCase();
    if (normalized == 'main-balance') {
      return 'From Main Balance';
    }
    if (normalized == 'company') {
      return 'Added to Due';
    }
    if (normalized.isEmpty) {
      return 'N/A';
    }

    return normalized
        .split(RegExp(r'[-_\s]+'))
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  String _currency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_US',
      symbol: 'BDT ',
      decimalDigits: amount % 1 == 0 ? 0 : 2,
    );
    return formatter.format(amount);
  }

  double _parseAmount(String amount) {
    final cleaned = amount.replaceAll(',', '').trim();
    return double.tryParse(cleaned) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final displayDate = _formatDate(transaction.date);
    final amount = _parseAmount(transaction.amount);
    const taxRate = 0.0;
    final taxAmount = amount * taxRate;
    final total = amount + taxAmount;
    final totalPrice = _parseAmount(transaction.totalPrice);
    final amountDue = _parseAmount(transaction.amountDue);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Preview'),
        actions: [
          IconButton(
            tooltip: 'Save',
            icon: const Icon(Icons.download_outlined),
            onPressed: () => InvoiceUtil.saveInvoiceAndNotify(transaction),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF263238), // blueGrey900
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'INVOICE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Urgent Transport Billing',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _headerMeta(
                            'Invoice Date',
                            _formatDate(now.toIso8601String()),
                          ),
                          const SizedBox(height: 3),
                          _headerMeta('Transaction Date', displayDate),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Billed To / Trip Details ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _infoCard(
                    context,
                    title: 'Billed To',
                    rows: [
                      _safe(transaction.companyAndShipInfo.companyName),
                      'Ship: ${_safe(transaction.companyAndShipInfo.shipName ?? 'null')}',
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _infoCard(
                    context,
                    title: 'Trip Details',
                    rows: [
                      'From: ${_safe(transaction.tripFrom)}',
                      'To: ${_safe(transaction.tripTo)}',
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Payment Meta Pills ──
            Row(
              children: [
                Expanded(
                  child: _pill(
                    context,
                    'Transaction Type',
                    _formatTransactionCategory(transaction.transactionType),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _pill(
                    context,
                    transaction.transactionType.trim().toLowerCase() ==
                            'expenses'
                        ? 'Expense Source'
                        : 'Payment Method',
                    transaction.transactionType.trim().toLowerCase() ==
                            'expenses'
                        ? _formatExpenseSource(transaction.expenseSource)
                        : _formatType(transaction.type),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: _pill(context, 'Source', 'Urgent App')),
              ],
            ),
            const SizedBox(height: 16),

            // ── Items Table ──
            Table(
              border: TableBorder.all(color: Colors.grey.shade300, width: 0.5),
              columnWidths: const {
                0: FlexColumnWidth(1.2),
                1: FlexColumnWidth(4),
                2: FlexColumnWidth(1.5),
                3: FlexColumnWidth(1.5),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.blueGrey.shade50),
                  children: [
                    _tableCell('Item', isHeader: true),
                    _tableCell('Description', isHeader: true),
                    _tableCell('Qty', isHeader: true),
                    _tableCell('Amount', isHeader: true, alignRight: true),
                  ],
                ),
                TableRow(
                  children: [
                    _tableCell('1'),
                    _tableCell(
                      transaction.transactionType.trim().toLowerCase() ==
                              'expenses'
                          ? 'Transport expense (${_formatExpenseSource(transaction.expenseSource)}) for ${_safe(transaction.tripFrom)} to ${_safe(transaction.tripTo)}'
                          : 'Transport payment for ${_safe(transaction.tripFrom)} to ${_safe(transaction.tripTo)} (${_formatType(transaction.type)})',
                    ),
                    _tableCell('1'),
                    _tableCell(_currency(amount), alignRight: true),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Totals ──
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: 230,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300, width: 0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _amountRow('Subtotal', _currency(amount)),
                    const SizedBox(height: 6),
                    _amountRow('Tax', _currency(taxAmount)),
                    const Divider(height: 14),
                    _amountRow('Total', _currency(total), bold: true),
                    const SizedBox(height: 6),
                    _amountRow('Total Price', _currency(totalPrice)),
                    const SizedBox(height: 6),
                    _amountRow('Amount Due', _currency(amountDue), bold: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Notes ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notes',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    (transaction.description ?? '').trim().isEmpty
                        ? 'This invoice is generated from transaction records in the Urgent app.'
                        : transaction.description!.trim(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Helper widgets ──

  Widget _headerMeta(String label, String value) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(
    BuildContext context, {
    required String title,
    required List<String> rows,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300, width: 0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 6),
          ...rows.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                r,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              title,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(width: 2),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableCell(
    String text, {
    bool isHeader = false,
    bool alignRight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Text(
        text,
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: TextStyle(
          fontSize: 10,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          color: isHeader ? Colors.blueGrey.shade900 : Colors.grey.shade800,
        ),
      ),
    );
  }

  Widget _amountRow(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade700,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade900,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
