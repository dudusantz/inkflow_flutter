import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:inkflow/features/finance/domain/financial_record.dart';

class ReceiptService {
  const ReceiptService._();

  static final _accent = PdfColor.fromHex('#167D7B');
  static final _dark = PdfColor.fromHex('#111218');
  static final _muted = PdfColor.fromHex('#667085');
  static final _line = PdfColor.fromHex('#D9DDE2');

  static Future<Uint8List> buildReceipt({
    required FinancialRecord payment,
    required Map<String, dynamic>? fiscalProfile,
  }) async {
    final currency = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
      decimalDigits: 2,
    );
    final issuedAt = DateTime.now();
    final documentNumber = payment.id.substring(0, 8).toUpperCase();
    final issuer = _value(fiscalProfile?['trade_name']) ??
        _value(fiscalProfile?['legal_name']) ??
        'Profissional InkFlow';
    final city = _value(fiscalProfile?['city']);
    final state = _value(fiscalProfile?['state']);
    final location = [city, state].whereType<String>().join(' / ');
    final defaultService =
        _value(fiscalProfile?['default_service_description']);
    final serviceDescription = payment.description == 'Pagamento de sessão'
        ? defaultService ?? payment.description
        : payment.description;
    final rate =
        double.tryParse(fiscalProfile?['tax_rate']?.toString() ?? '') ?? 0;
    final tax = payment.amount * rate / 100;
    final font = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
    );
    final boldFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
    );
    final document = pw.Document(
      title: 'Documento de serviço $documentNumber',
      author: issuer,
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (_) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: _dark,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'InkFlow.',
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'DOCUMENTO AUXILIAR DE SERVIÇO',
                      style: pw.TextStyle(
                        color: PdfColor.fromHex('#63CCC7'),
                        fontSize: 9,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Nº $documentNumber',
                        style: const pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      DateFormat('dd/MM/yyyy HH:mm').format(issuedAt),
                      style: const pw.TextStyle(
                          color: PdfColors.grey400, fontSize: 8),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          _section('IDENTIFICAÇÃO DO DOCUMENTO', [
            _pair('Número', documentNumber, 'Status', 'Recebido'),
            _pair('Emissão', DateFormat('dd/MM/yyyy HH:mm').format(issuedAt),
                'Forma de pagamento', payment.category),
          ]),
          _section('PRESTADOR DO SERVIÇO', [
            _pair('Nome / nome empresarial', issuer, 'CPF / CNPJ',
                _value(fiscalProfile?['tax_id']) ?? 'Não informado'),
            _pair(
              'Razão social',
              _value(fiscalProfile?['legal_name']) ?? issuer,
              'Inscrição municipal',
              _value(fiscalProfile?['municipal_registration']) ??
                  'Não informada',
            ),
            _wide('Endereço',
                _value(fiscalProfile?['fiscal_address']) ?? 'Não informado'),
            _pair(
              'Cidade / UF',
              location.isEmpty ? 'Não informado' : location,
              'CEP',
              _value(fiscalProfile?['postal_code']) ?? 'Não informado',
            ),
            _pair(
              'E-mail',
              _value(fiscalProfile?['email']) ?? 'Não informado',
              'Telefone',
              _value(fiscalProfile?['phone']) ?? 'Não informado',
            ),
          ]),
          _section('TOMADOR DO SERVIÇO', [
            _pair(
              'Nome / nome empresarial',
              payment.clientName ?? 'Cliente não identificado',
              'CPF / CNPJ',
              payment.clientTaxId ?? 'Não informado',
            ),
            _wide('Endereço', payment.clientAddress ?? 'Não informado'),
            _pair(
              'E-mail',
              payment.clientEmail ?? 'Não informado',
              'Telefone',
              payment.clientPhone ?? 'Não informado',
            ),
          ]),
          _section('SERVIÇO PRESTADO', [
            _wide('Descrição do serviço', serviceDescription),
            _pair(
              'Data do serviço',
              DateFormat('dd/MM/yyyy').format(payment.date),
              'Local da prestação',
              location.isEmpty ? 'Não informado' : location,
            ),
          ]),
          _section('TRIBUTAÇÃO E VALORES', [
            _pair('Base de cálculo', currency.format(payment.amount),
                'Alíquota informada', '${rate.toStringAsFixed(2)}%'),
            _pair('Tributos estimados', currency.format(tax), 'Descontos',
                currency.format(0)),
          ]),
          pw.Container(
            width: double.infinity,
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#E8F8F7'),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('VALOR TOTAL DO SERVIÇO',
                    style: pw.TextStyle(
                        color: PdfColor.fromHex('#376765'),
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold)),
                pw.Text(currency.format(payment.amount),
                    style: pw.TextStyle(
                        color: _accent,
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          _section('INFORMAÇÕES COMPLEMENTARES', [
            _wide(
              'Observação',
              '${_value(fiscalProfile?['receipt_notes']) ?? ''}'
                  '${_value(fiscalProfile?['receipt_notes']) == null ? '' : '\n'}'
                  'Documento gerado pelo InkFlow para registro do serviço e do '
                  'pagamento. Não substitui a NFS-e oficial emitida pelo '
                  'município ou por provedor fiscal autorizado.',
            ),
          ]),
        ],
        footer: (_) => pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Divider(color: _line),
            pw.Text('Autenticidade: ${payment.id}',
                style: pw.TextStyle(fontSize: 7, color: _muted)),
          ],
        ),
      ),
    );
    return document.save();
  }

  static Future<void> previewReceipt({
    required FinancialRecord payment,
    required Map<String, dynamic>? fiscalProfile,
  }) async {
    final bytes = await buildReceipt(
      payment: payment,
      fiscalProfile: fiscalProfile,
    );
    final filename = 'documento-servico-${payment.id.substring(0, 8)}.pdf';
    try {
      final opened = await Printing.layoutPdf(
        name: filename,
        onLayout: (_) async => bytes,
      );
      if (opened) return;
    } catch (_) {
      // Alguns navegadores não oferecem a pré-visualização nativa.
    }
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }

  static pw.Widget _section(String title, List<pw.TableRow> rows) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: double.infinity,
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              color: _dark,
              child: pw.Text(title,
                  style: const pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold)),
            ),
            pw.Table(
              border: pw.TableBorder(
                bottom: pw.BorderSide(color: _line, width: 0.6),
                left: pw.BorderSide(color: _line, width: 0.6),
                right: pw.BorderSide(color: _line, width: 0.6),
                horizontalInside: pw.BorderSide(color: _line, width: 0.6),
                verticalInside: pw.BorderSide(color: _line, width: 0.6),
              ),
              children: rows,
            ),
          ],
        ),
      );

  static pw.TableRow _pair(
    String firstLabel,
    String firstValue,
    String secondLabel,
    String secondValue,
  ) =>
      pw.TableRow(children: [
        _cell(firstLabel, firstValue),
        _cell(secondLabel, secondValue),
      ]);

  static pw.TableRow _wide(String label, String value) =>
      pw.TableRow(children: [_cell(label, value), pw.SizedBox()]);

  static pw.Widget _cell(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.all(7),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label.toUpperCase(),
                style: pw.TextStyle(
                    color: _muted,
                    fontSize: 6.5,
                    fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Text(value,
                style: pw.TextStyle(
                    color: _dark,
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold)),
          ],
        ),
      );

  static String? _value(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
