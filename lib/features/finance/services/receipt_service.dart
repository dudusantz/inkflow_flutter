import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:inkflow/features/finance/domain/financial_record.dart';

class ReceiptService {
  const ReceiptService._();

  static Future<Uint8List> buildReceipt({
    required FinancialRecord payment,
    required Map<String, dynamic>? fiscalProfile,
  }) async {
    final document = pw.Document(
      title: 'Recibo InkFlow',
      author: fiscalProfile?['trade_name']?.toString() ?? 'InkFlow',
    );
    final currency =
        NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$', decimalDigits: 2);
    final issuer = _value(fiscalProfile?['trade_name']) ??
        _value(fiscalProfile?['legal_name']) ??
        'Profissional InkFlow';
    final legalName = _value(fiscalProfile?['legal_name']);
    final taxId = _value(fiscalProfile?['tax_id']);
    final address = _value(fiscalProfile?['fiscal_address']);

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(22),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#111218'),
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('InkFlow.',
                          style: const pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      pw.Text('RECIBO DIGITAL',
                          style: pw.TextStyle(
                              color: PdfColor.fromHex('#63CCC7'),
                              fontSize: 10,
                              letterSpacing: 1.5)),
                    ],
                  ),
                  pw.Text('#${payment.id.substring(0, 8).toUpperCase()}',
                      style: const pw.TextStyle(
                          color: PdfColors.white, fontSize: 10)),
                ],
              ),
            ),
            pw.SizedBox(height: 34),
            pw.Text('Recebimento confirmado',
                style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#202A3A'))),
            pw.SizedBox(height: 8),
            pw.Text(
              'Registramos o recebimento referente ao serviço descrito abaixo.',
              style: pw.TextStyle(
                  fontSize: 11, color: PdfColor.fromHex('#667085')),
            ),
            pw.SizedBox(height: 26),
            _row('Emitente', issuer),
            if (legalName != null && legalName != issuer)
              _row('Nome/Razão social', legalName),
            if (taxId != null) _row('CPF/CNPJ', taxId),
            if (address != null) _row('Endereço', address),
            _row('Descrição', payment.description),
            _row('Forma de pagamento', payment.category),
            _row('Data', DateFormat('dd/MM/yyyy HH:mm').format(payment.date)),
            pw.SizedBox(height: 18),
            pw.Container(
              width: double.infinity,
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#E8F8F7'),
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('VALOR RECEBIDO',
                      style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#376765'))),
                  pw.Text(currency.format(payment.amount),
                      style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#167D7B'))),
                ],
              ),
            ),
            pw.Spacer(),
            pw.Divider(color: PdfColor.fromHex('#D9DDE2')),
            pw.SizedBox(height: 10),
            pw.Text(
              'Este documento é um recibo simples de pagamento e não substitui nota fiscal de serviço.',
              style:
                  pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#7B8491')),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
                'Gerado pelo InkFlow em ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                style: pw.TextStyle(
                    fontSize: 8, color: PdfColor.fromHex('#9AA2AE'))),
          ],
        ),
      ),
    );
    return document.save();
  }

  static Future<void> shareReceipt({
    required FinancialRecord payment,
    required Map<String, dynamic>? fiscalProfile,
  }) async {
    final bytes = await buildReceipt(
      payment: payment,
      fiscalProfile: fiscalProfile,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'recibo-${payment.id.substring(0, 8)}.pdf',
    );
  }

  static pw.Widget _row(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 12),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 120,
              child: pw.Text(label,
                  style: pw.TextStyle(
                      fontSize: 10, color: PdfColor.fromHex('#7B8491'))),
            ),
            pw.Expanded(
              child: pw.Text(value,
                  style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#202A3A'))),
            ),
          ],
        ),
      );

  static String? _value(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
