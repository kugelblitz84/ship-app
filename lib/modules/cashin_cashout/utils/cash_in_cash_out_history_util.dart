import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/services/download/download_service.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../models/cash_in_cash_out_model.dart';

class CashInCashOutHistoryUtil {
  CashInCashOutHistoryUtil._();

  static final DownloadService _downloadService = createDownloadService();

  static Future<void> saveCashInCashOutHistoryAndNotify(
    List<CashInCashOutModel> entries,
  ) async {
    final context = Get.context;
    if (context == null) return;

    if (entries.isEmpty) {
      showAppSnackbar(
        'No Entries',
        'No cash in/cash out records found to export history.',
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final savedFile = await saveCashInCashOutHistoryToFile(entries);

      if (context.mounted) {
        Navigator.of(context).pop();
      }

      await _showSaveSuccessModal(context, savedFile, entries.length);
    } catch (_) {
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      _showErrorDialog(
        context,
        'Unable to save cash in/cash out history file. Please try again.',
      );
    }
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
                  'Cash In/Cash Out History Saved',
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
                  title: const Text('Open History PDF'),
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
                          'Unable to trigger browser download for this history PDF.',
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
        _showErrorDialog(
          context,
          'Unable to open the saved cash in/cash out history PDF file.',
        );
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

  static Future<GeneratedFileSaveResult> saveCashInCashOutHistoryToFile(
    List<CashInCashOutModel> entries,
  ) async {
    final bytes = await buildCashInCashOutHistoryPdf(entries);

    final file = GeneratedFileData(
      bytes: bytes,
      fileName: fileNameFor(),
      mimeType: 'application/pdf',
    );

    return _downloadService.saveFile(file);
  }

  static Future<Uint8List> buildCashInCashOutHistoryPdf(
    List<CashInCashOutModel> entries,
  ) async {
    final sortedEntries = [...entries]
      ..sort((a, b) {
        final ad = _tryParseDate(a.date);
        final bd = _tryParseDate(b.date);

        if (ad != null && bd != null) {
          final cmp = ad.compareTo(bd);
          if (cmp != 0) return cmp;
        }

        return a.entryId.compareTo(b.entryId);
      });

    final theme = pw.ThemeData.withFont(
      base: await PdfGoogleFonts.nunitoRegular(),
      bold: await PdfGoogleFonts.nunitoBold(),
    );

    final pdf = pw.Document(
      title: 'Cash In Cash Out History',
      author: 'MarineLedger',
      creator: 'MarineLedger App',
      subject: 'Main balance cash in cash out history export',
    );

    double totalIn = 0;
    double totalOut = 0;
    double finalBalance = 0;

    final rows = <List<String>>[];
    var index = 0;
    for (final entry in sortedEntries) {
      index += 1;
      final amount = _toDouble(entry.amount);
      if (entry.isCashOut) {
        totalOut += amount;
      } else {
        totalIn += amount;
      }

      final cashIn = entry.isCashIn ? _amount(amount) : '';
      final cashOut = entry.isCashOut ? _amount(amount) : '';
      final noteText = (entry.note ?? '').trim();
      final description = noteText.isEmpty ? '-' : noteText;

      rows.add([
        '$index',
        _displayDate(entry.date),
        description,
        entry.transactionTypeLabel,
        entry.flowTypeLabel,
        cashIn,
        cashOut,
      ]);
    }

    rows.add(['', '', 'Total', '', '', _amount(totalIn), _amount(totalOut)]);
    finalBalance = totalIn - totalOut;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => [
          pw.Text(
            'Cash In Cash Out History',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey900,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Main balance only. This report does not include transaction ledger items.',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _summaryBox('Total Cash In', _amount(totalIn)),
              _summaryBox('Total Cash Out', _amount(totalOut)),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Table.fromTextArray(
            headers: const [
              'ID',
              'Date',
              'Description',
              'Transaction Type',
              'Flow Type',
              'Cash-in BDT',
              'Cash-out BDT',
            ],
            data: rows,
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blueGrey700,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
            headerAlignment: pw.Alignment.centerLeft,
          ),
          pw.SizedBox(height: 12),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: _finalBalanceBox(finalBalance),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static String fileNameFor() {
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return 'cash_in_cash_out_history_$stamp.pdf';
  }

  static pw.Widget _summaryBox(String title, String value) {
    return pw.Container(
      width: 165,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  static pw.Widget _finalBalanceBox(double finalBalance) {
    final label = 'Final Balance (Cash In - Cash Out)';
    return pw.Container(
      width: 260,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey50,
        border: pw.Border.all(color: PdfColors.blueGrey300, width: 0.8),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            _amount(finalBalance),
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey900,
            ),
          ),
        ],
      ),
    );
  }

  static DateTime? _tryParseDate(String rawDate) {
    final trimmed = rawDate.trim();
    if (trimmed.isEmpty) return null;
    return DateTime.tryParse(trimmed);
  }

  static String _displayDate(String rawDate) {
    final parsed = _tryParseDate(rawDate);
    if (parsed == null) return rawDate;
    return DateFormat('dd MMM yyyy').format(parsed);
  }

  static String _amount(double value) {
    return value.toInt().toString();
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) {
      final sanitized = value.replaceAll(',', '').trim();
      if (sanitized.isEmpty) return 0;
      return double.tryParse(sanitized) ?? 0;
    }
    return 0;
  }
}
