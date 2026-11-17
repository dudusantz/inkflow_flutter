import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:inkflow/core/theme/app_theme.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

Future<void> showDocumentPreview(
  BuildContext context, {
  required String title,
  required String filename,
  required Uint8List bytes,
}) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: InkFlowColors.background,
          appBar: AppBar(title: Text(title)),
          body: SafeArea(
            top: false,
            child: PdfPreview(
              build: (_) => bytes,
              pdfFileName: filename,
              initialPageFormat: PdfPageFormat.a4,
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              onError: (_, __) => const Center(
                child: Text('Não foi possível exibir a prévia do PDF.'),
              ),
            ),
          ),
        ),
      ),
    );
