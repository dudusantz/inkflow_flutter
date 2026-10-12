import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:inkflow/features/finance/domain/dre_summary.dart';

class DreReportService {
  const DreReportService._();

  static Future<Uint8List> build({
    required DreSummary dre,
    required DateTime start,
    required DateTime end,
    String? studioName,
  }) async {
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
    );
    final currency = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
      decimalDigits: 2,
    );
    final date = DateFormat('dd/MM/yyyy');
    final document = pw.Document(title: 'DRE gerencial InkFlow');

    pw.Widget row(String label, double value, {bool total = false}) =>
        pw.Container(
          color: total ? PdfColor.fromHex('#F1F5F4') : PdfColors.white,
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label,
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight:
                          total ? pw.FontWeight.bold : pw.FontWeight.normal)),
              pw.Text(currency.format(value),
                  style: pw.TextStyle(
                      fontSize: 9,
                      color: value < 0
                          ? PdfColor.fromHex('#D94646')
                          : PdfColor.fromHex('#111116'),
                      fontWeight:
                          total ? pw.FontWeight.bold : pw.FontWeight.normal)),
            ],
          ),
        );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('DRE gerencial — não substitui escrituração contábil.',
                style:
                    const pw.TextStyle(color: PdfColors.grey600, fontSize: 7)),
            pw.Text('Página ${context.pageNumber} de ${context.pagesCount}',
                style:
                    const pw.TextStyle(color: PdfColors.grey600, fontSize: 7)),
          ],
        ),
        build: (_) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#111116'),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      studioName?.trim().isNotEmpty == true
                          ? studioName!
                          : 'InkFlow.',
                      style: const pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text('DEMONSTRAÇÃO DO RESULTADO GERENCIAL',
                        style: pw.TextStyle(
                            color: PdfColor.fromHex('#62C8C0'), fontSize: 9)),
                  ],
                ),
                pw.Text('${date.format(start)} — ${date.format(end)}',
                    style: const pw.TextStyle(
                        color: PdfColors.white, fontSize: 9)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          row('Receita bruta', dre.grossRevenue, total: true),
          row('(-) Impostos${dre.taxesAreEstimated ? ' estimados' : ''}',
              -dre.taxes),
          row('(=) Receita líquida', dre.netRevenue, total: true),
          row('(-) Custos variáveis', -dre.serviceCosts),
          row('(=) Lucro bruto', dre.grossProfit, total: true),
          row('(-) Despesas operacionais', -dre.operatingExpenses),
          row('(=) Resultado líquido', dre.netResult, total: true),
          pw.SizedBox(height: 16),
          pw.Text('Margem líquida: ${dre.netMargin.toStringAsFixed(1)}%',
              style: const pw.TextStyle(
                  fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),
          pw.Text(
              'Investimentos fora do resultado: ${currency.format(dre.investments)}',
              style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 9)),
          pw.Text(
              'Recebimentos pendentes: ${currency.format(dre.pendingRevenue)}',
              style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 9)),
        ],
      ),
    );
    return document.save();
  }

  static Future<void> preview({
    required DreSummary dre,
    required DateTime start,
    required DateTime end,
    String? studioName,
  }) async {
    final bytes = await build(
      dre: dre,
      start: start,
      end: end,
      studioName: studioName,
    );
    final filename =
        'dre-${DateFormat('yyyyMMdd').format(start)}-${DateFormat('yyyyMMdd').format(end)}.pdf';
    try {
      if (await Printing.layoutPdf(
          name: filename, onLayout: (_) async => bytes)) {
        return;
      }
    } catch (_) {
      // Alguns navegadores não oferecem pré-visualização nativa.
    }
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }
}
