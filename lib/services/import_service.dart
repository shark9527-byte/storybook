import 'dart:io';
import 'package:pdfx/pdfx.dart';

class ImportService {
  Future<ImportResult> importPdf(String pdfPath, String outputDir) async {
    final document = await PdfDocument.openFile(pdfPath);
    final pageCount = await document.pagesCount;
    final title = pdfPath.split('/').last.replaceAll('.pdf', '');
    final paths = <String>[];

    for (int i = 1; i <= pageCount; i++) {
      final page = await document.getPage(i);
      final image = await page.render(
        width: page.width,
        height: page.height,
        format: PdfPageImageFormat.png,
      );
      final imagePath = '$outputDir/page_${i}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(imagePath);
      await file.writeAsBytes(image.bytes);
      paths.add(imagePath);
      page.close();
    }

    document.close();
    return ImportResult(title: title, pageImagePaths: paths);
  }
}

class ImportResult {
  final String title;
  final List<String> pageImagePaths;

  ImportResult({required this.title, required this.pageImagePaths});
}
