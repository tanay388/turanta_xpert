import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../core/theme/xpert_tokens.dart';

/// Read-only PDF viewer — no download/share action, matches the requirement
/// that legal documents can only be viewed in-app.
class PdfViewerScreen extends StatelessWidget {
  const PdfViewerScreen({super.key, required this.title, required this.url});

  final String title;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: XpertColors.background,
      appBar: AppBar(title: Text(title)),
      body: SfPdfViewer.network(url),
    );
  }
}
