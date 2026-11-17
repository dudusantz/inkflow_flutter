import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/finance/presentation/document_preview.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

void main() {
  testWidgets('abre o PDF no app sem disparar impressão nem compartilhamento',
      (tester) async {
    final bytes = Uint8List.fromList([37, 80, 68, 70]);
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('net.nfet.printing'),
      (call) async {
        calls.add(call.method);
        return {'canRaster': false, 'canPrint': true, 'canShare': true};
      },
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDocumentPreview(
              context,
              title: 'Relatório financeiro',
              filename: 'relatorio.pdf',
              bytes: bytes,
            ),
            child: const Text('Abrir PDF'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Abrir PDF'));
    await tester.pumpAndSettle();

    final preview = tester.widget<PdfPreview>(find.byType(PdfPreview));
    expect(find.text('Relatório financeiro'), findsOneWidget);
    expect(preview.pdfFileName, 'relatorio.pdf');
    expect(await preview.build(PdfPageFormat.a4), same(bytes));
    expect(calls, everyElement('printingInfo'));
  });
}
