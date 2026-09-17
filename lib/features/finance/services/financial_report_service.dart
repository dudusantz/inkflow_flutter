import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:inkflow/features/finance/domain/financial_record.dart';

class FinancialReportService {
  const FinancialReportService._();

  static Future<Uint8List> build({
    required List<FinancialRecord> records,
    required DateTime start,
    required DateTime end,
  }) async {
    final currency = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
      decimalDigits: 2,
    );
    final date = DateFormat('dd/MM/yyyy');
    final generatedAt = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final credits = records
        .where((item) =>
            item.type == FinancialRecordType.payment && item.status == 'PAGO')
        .fold<double>(0, (sum, item) => sum + item.amount);
    final pending = records
        .where((item) =>
            item.type == FinancialRecordType.payment && item.status != 'PAGO')
        .fold<double>(0, (sum, item) => sum + item.amount);
    final debits = records
        .where((item) => item.type == FinancialRecordType.expense)
        .fold<double>(0, (sum, item) => sum + item.amount);
    final font = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
    );
    final document = pw.Document(title: 'Relatório financeiro InkFlow');

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 26, 28, 24),
        theme: pw.ThemeData.withFont(base: font, bold: bold),
        header: (_) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 18),
          padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#111218'),
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('InkFlow.',
                      style: const pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 23,
                          fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 3),
                  pw.Text('RELATÓRIO FINANCEIRO',
                      style: pw.TextStyle(
                          color: PdfColor.fromHex('#63CCC7'),
                          fontSize: 9,
                          letterSpacing: 1.1)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('PERÍODO',
                      style: const pw.TextStyle(
                          color: PdfColors.grey400, fontSize: 7)),
                  pw.SizedBox(height: 3),
                  pw.Text('${date.format(start)} — ${date.format(end)}',
                      style: const pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 7),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              top:
                  pw.BorderSide(color: PdfColor.fromHex('#D9DDE2'), width: 0.6),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Gerado pelo InkFlow em $generatedAt',
                  style: pw.TextStyle(
                      color: PdfColor.fromHex('#667085'), fontSize: 7)),
              pw.Text('Página ${context.pageNumber} de ${context.pagesCount}',
                  style: pw.TextStyle(
                      color: PdfColor.fromHex('#667085'), fontSize: 7)),
            ],
          ),
        ),
        build: (_) => [
          pw.Row(
            children: [
              _summary('Créditos recebidos', currency.format(credits),
                  PdfColor.fromHex('#167D7B')),
              pw.SizedBox(width: 8),
              _summary('Débitos', currency.format(debits),
                  PdfColor.fromHex('#E34F55')),
              pw.SizedBox(width: 8),
              _summary('Resultado', currency.format(credits - debits),
                  PdfColor.fromHex('#111218')),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F4F7F7'),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('${records.length} movimentações no período',
                    style: const pw.TextStyle(
                        fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                pw.Text('Pendente: ${currency.format(pending)}',
                    style: pw.TextStyle(
                        color: PdfColor.fromHex('#A36A00'), fontSize: 8.5)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('EXTRATO DE MOVIMENTAÇÕES',
                  style: const pw.TextStyle(
                      fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.Text('Valores em reais (BRL)',
                  style: pw.TextStyle(
                      color: PdfColor.fromHex('#667085'), fontSize: 7)),
            ],
          ),
          pw.SizedBox(height: 8),
          if (records.isEmpty)
            pw.Text('Nenhuma movimentação registrada no período.')
          else
            pw.TableHelper.fromTextArray(
              headers: const ['Data', 'Descrição', 'Tipo', 'Status', 'Valor'],
              data: records.map((item) {
                final credit = item.type == FinancialRecordType.payment;
                return [
                  date.format(item.date),
                  item.description,
                  credit ? 'Crédito' : 'Débito',
                  credit ? item.status.toUpperCase() : 'PAGO',
                  '${credit ? '+' : '-'} ${currency.format(item.amount)}',
                ];
              }).toList(),
              headerStyle: const pw.TextStyle(
                  fontSize: 8, fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 8),
              headerDecoration:
                  pw.BoxDecoration(color: PdfColor.fromHex('#DDF1EF')),
              oddRowDecoration:
                  pw.BoxDecoration(color: PdfColor.fromHex('#F8FAFA')),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: const {4: pw.Alignment.centerRight},
              columnWidths: const {
                0: pw.FlexColumnWidth(1.1),
                1: pw.FlexColumnWidth(2.6),
                2: pw.FlexColumnWidth(1),
                3: pw.FlexColumnWidth(1),
                4: pw.FlexColumnWidth(1.45),
              },
              cellPadding:
                  const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 8),
              border: pw.TableBorder.all(
                  color: PdfColor.fromHex('#E2E7EA'), width: 0.5),
            ),
        ],
      ),
    );
    return document.save();
  }

  static Future<void> preview({
    required List<FinancialRecord> records,
    required DateTime start,
    required DateTime end,
  }) async {
    final bytes = await build(records: records, start: start, end: end);
    final filename =
        'relatorio-financeiro-${DateFormat('yyyyMMdd').format(start)}-${DateFormat('yyyyMMdd').format(end)}.pdf';
    try {
      final opened = await Printing.layoutPdf(
        name: filename,
        onLayout: (_) async => bytes,
      );
      if (opened) return;
    } catch (_) {
      // Alguns navegadores não oferecem pré-visualização nativa.
    }
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }

  static pw.Widget _summary(String label, String value, PdfColor color) =>
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(13),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#F8FAFA'),
            border: pw.Border.all(color: PdfColor.fromHex('#DDE3E6')),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 22,
                height: 3,
                decoration: pw.BoxDecoration(
                  color: color,
                  borderRadius: pw.BorderRadius.circular(2),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(label.toUpperCase(),
                  style: pw.TextStyle(
                      color: PdfColor.fromHex('#667085'),
                      fontSize: 6.8,
                      letterSpacing: 0.4)),
              pw.SizedBox(height: 4),
              pw.Text(value,
                  style: pw.TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
      );
}
