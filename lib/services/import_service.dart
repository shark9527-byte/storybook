import 'dart:io';
import 'package:pdfx/pdfx.dart';
import 'package:pdf_text/pdf_text.dart';

class ImportService {
  Future<ImportResult> importPdf(String pdfPath, String outputDir) async {
    // pdfx 渲染图片
    final document = await PdfDocument.openFile(pdfPath);
    final pageCount = await document.pagesCount;
    final title = pdfPath.split('/').last.replaceAll('.pdf', '');
    final pageImages = <String>[];
    final pageTexts = <String>[];

    // pdf_text_extract 提取文字
    final textDoc = await PDFDoc.fromPath(pdfPath);

    for (int i = 1; i <= pageCount; i++) {
      // 渲染图片
      final page = await document.getPage(i);
      final image = await page.render(
        width: page.width,
        height: page.height,
        format: PdfPageImageFormat.png,
      );
      if (image == null) {
        page.close();
        continue;
      }
      final imagePath = '$outputDir/page_${i}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(imagePath);
      await file.writeAsBytes(image.bytes);
      pageImages.add(imagePath);
      page.close();

      // 提取文字
      String text = '';
      try {
        if (i <= textDoc.length) {
          text = (await textDoc.pageAt(i).text).trim();
        }
      } catch (_) {}
      pageTexts.add(text);
    }

    document.close();
    return ImportResult(title: title, pageImagePaths: pageImages, pageTexts: pageTexts);
  }
}

class ImportResult {
  final String title;
  final List<String> pageImagePaths;
  final List<String> pageTexts;

  ImportResult({
    required this.title,
    required this.pageImagePaths,
    required this.pageTexts,
  });
}
