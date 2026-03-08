import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/download/download_service.dart';
import '../models/transaction_model.dart';

class ExpensesHistoryUtil {
  ExpensesHistoryUtil._();

  static final DownloadService _downloadService = createDownloadService();

  static Future<void> saveExpensesHistoryAndNotify(
    List<TransactionModel> expenses, {
    String dateFilterLabel = 'All Time',
  }) async {
    final context = Get.context;
    if (context == null) return;

    if (expenses.isEmpty) {
      Get.snackbar('No Expenses', 'No filtered expenses found to export.');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final savedFile = await saveExpensesHistoryToFile(
        expenses,
        dateFilterLabel: dateFilterLabel,
      );

      if (context.mounted) {
        Navigator.of(context).pop();
      }

      await _showSaveSuccessModal(context, savedFile, expenses.length);
    } catch (_) {
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      _showErrorDialog(
        context,
        'Unable to save expenses history file. Please try again.',
      );
    }
  }

  static Future<GeneratedFileSaveResult> saveExpensesHistoryToFile(
    List<TransactionModel> expenses, {
    String dateFilterLabel = 'All dates',
  }) async {
    final bytes = await buildExpensesHistoryPdf(
      expenses,
      dateFilterLabel: dateFilterLabel,
    );
    final file = GeneratedFileData(
      bytes: bytes,
      fileName: fileNameFor(),
      mimeType: 'application/pdf',
    );

    return _downloadService.saveFile(file);
  }

  static Future<Uint8List> buildExpensesHistoryPdf(
    List<TransactionModel> expenses, {
    String dateFilterLabel = 'All dates',
  }) async {
    final pdf = pw.Document(
      title: 'Expenses History',
      author: 'Urgent',
      creator: 'Urgent App',
      subject: 'Filtered expenses history export',
    );

    final rows = expenses
        .where((tx) => tx.isExpense)
        .map(_ExpensePdfRow.fromTransaction)
        .toList();
    final totalExpense = rows.fold<double>(
      0,
      (sum, row) => sum + row.amountValue,
    );

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
            rows.length,
            totalExpense: _formatTotalAmount(totalExpense),
            dateFilterLabel: dateFilterLabel,
          ),
          pw.SizedBox(height: 14),
          _buildTable(rows),
          pw.SizedBox(height: 12),
          _buildTotalExpenseSection(totalExpense),
        ],
      ),
    );

    return pdf.save();
  }

  static String fileNameFor() {
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return 'expenses_history_$stamp.pdf';
  }

  static pw.Widget _buildHeader(
    int count, {
    required String totalExpense,
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
                'EXPENSES HISTORY',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Filtered expenses export',
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
              _metaText('Total Expense', totalExpense),
              pw.SizedBox(height: 4),
              _metaText('Showing Expenses For', dateFilterLabel),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTable(List<_ExpensePdfRow> rows) {
    final headerStyle = pw.TextStyle(
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
      fontSize: 9,
    );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.5),
        1: pw.FlexColumnWidth(2.9),
        2: pw.FlexColumnWidth(1.8),
        3: pw.FlexColumnWidth(1.6),
        4: pw.FlexColumnWidth(2.2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
          children: [
            _headerCell('Date', headerStyle),
            _headerCell('Details', headerStyle),
            _headerCell('Type', headerStyle),
            _headerCell('Amount', headerStyle),
            _headerCell('Company', headerStyle),
          ],
        ),
        ...rows.map((row) {
          return pw.TableRow(
            children: [
              _bodyCell(row.date),
              _bodyCell(row.details),
              _bodyCell(row.type),
              _bodyCell(row.amount),
              _bodyCell(row.company),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildTotalExpenseSection(double totalExpense) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.blueGrey200, width: 0.8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Total Expense',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey900,
            ),
          ),
          pw.Text(
            _formatTotalAmount(totalExpense),
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey900,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _headerCell(String text, pw.TextStyle style) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: pw.Text(text, style: style),
    );
  }

  static pw.Widget _bodyCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey900),
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
                  'Expenses PDF Saved',
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
                  title: const Text('Open PDF'),
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

  static Future<void> _openDownloadedFile(
    GeneratedFileSaveResult savedFile,
  ) async {
    final context = Get.context;
    if (context == null) return;

    try {
      final opened = await _downloadService.openSavedFile(
        savedFile: savedFile,
        mimeType: 'application/pdf',
      );

      if (!opened && context.mounted) {
        _showErrorDialog(context, 'Unable to open the saved file.');
      }
    } catch (_) {
      if (context.mounted) {
        _showErrorDialog(context, 'Unable to open the saved file.');
      }
    }
  }

  static void _showErrorDialog(BuildContext context, String message) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _ExpensePdfRow {
  const _ExpensePdfRow({
    required this.date,
    required this.details,
    required this.type,
    required this.amount,
    required this.amountValue,
    required this.company,
  });

  final String date;
  final String details;
  final String type;
  final String amount;
  final double amountValue;
  final String company;

  factory _ExpensePdfRow.fromTransaction(TransactionModel transaction) {
    final companyName = transaction.companyName.trim();
    final companyLabel = transaction.isMainBalanceExpense
        ? 'N/A'
        : (companyName.isNotEmpty ? companyName : 'N/A');

    return _ExpensePdfRow(
      date: _normalizeDate(transaction.date),
      details: _safeText(transaction.description),
      type: _expenseTypeLabel(transaction),
      amount: _formatAmount(transaction.amount),
      amountValue: _parseAmount(transaction.amount),
      company: companyLabel,
    );
  }

  static String _expenseTypeLabel(TransactionModel transaction) {
    final source = transaction.normalizedExpenseSource;
    if (source == 'company') {
      return 'Company Due';
    }
    if (source == 'main-balance') {
      return 'Main Balance Expense';
    }

    return transaction.expenseSourceLabel;
  }

  static String _normalizeDate(String rawDate) {
    final trimmed = rawDate.trim();
    if (trimmed.isEmpty) return 'N/A';

    final direct = DateTime.tryParse(trimmed);
    if (direct != null) {
      return DateFormat('dd MMM yyyy').format(direct);
    }

    final slashParts = trimmed.split('/');
    if (slashParts.length == 3) {
      final first = int.tryParse(slashParts[0]);
      final second = int.tryParse(slashParts[1]);
      final third = int.tryParse(slashParts[2]);
      if (first != null && second != null && third != null) {
        final parsed = first > 31
            ? DateTime(first, second, third)
            : DateTime(third, first, second);
        return DateFormat('dd MMM yyyy').format(parsed);
      }
    }

    final dashParts = trimmed.split('-');
    if (dashParts.length == 3) {
      final first = int.tryParse(dashParts[0]);
      final second = int.tryParse(dashParts[1]);
      final third = int.tryParse(dashParts[2]);
      if (first != null && second != null && third != null) {
        final parsed = first > 31
            ? DateTime(first, second, third)
            : DateTime(third, second, first);
        return DateFormat('dd MMM yyyy').format(parsed);
      }
    }

    return trimmed;
  }

  static String _safeText(String? value) {
    final trimmed = (value ?? '').trim();
    return trimmed.isEmpty ? 'N/A' : trimmed;
  }

  static String _formatAmount(String? raw) {
    final parsed = _parseAmount(raw);
    return parsed.toInt().toString();
  }

  static double _parseAmount(String? raw) {
    final sanitized = (raw ?? '').replaceAll(',', '').trim();
    if (sanitized.isEmpty) return 0;

    return double.tryParse(sanitized) ?? 0;
  }
}

String _formatTotalAmount(double amount) {
  return 'BDT ${amount.toInt()}';
}
