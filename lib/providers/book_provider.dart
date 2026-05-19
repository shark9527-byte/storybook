import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/book.dart';
import '../models/page.dart';
import '../services/database_service.dart';
import '../services/import_service.dart';

class BookProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  List<Book> _books = [];
  Map<int, List<StoryPage>> _pagesCache = {};

  List<Book> get books => _books;
  List<StoryPage> getPagesForBook(int bookId) => _pagesCache[bookId] ?? [];

  Future<void> loadBooks() async {
    _books = await _db.getBooks();
    notifyListeners();
  }

  Future<void> loadPages(int bookId) async {
    _pagesCache[bookId] = await _db.getPages(bookId);
    notifyListeners();
  }

  Future<void> deleteBook(int bookId) async {
    final book = _books.firstWhere((b) => b.id == bookId);
    await _db.deleteBook(bookId);
    _pagesCache.remove(bookId);
    try {
      await File(book.coverImagePath).delete();
    } catch (_) {}
    await loadBooks();
  }

  Future<Book> importPdf(String pdfPath, void Function(int current, int total) onProgress) async {
    final appDir = (await getApplicationDocumentsDirectory()).path;
    final pageDir = Directory('$appDir/pages/import_${DateTime.now().millisecondsSinceEpoch}');
    if (!await pageDir.exists()) await pageDir.create(recursive: true);

    final importService = ImportService();
    final result = await importService.importPdf(pdfPath, pageDir.path);

    if (result.pageImagePaths.isEmpty) {
      throw Exception('PDF 没有页面');
    }

    final coverDir = Directory('$appDir/covers');
    if (!await coverDir.exists()) await coverDir.create(recursive: true);
    final coverPath = '${coverDir.path}/cover_${DateTime.now().millisecondsSinceEpoch}.png';
    await File(result.pageImagePaths.first).copy(coverPath);

    final book = Book(title: result.title, coverImagePath: coverPath);
    final bookId = await _db.insertBook(book);
    final savedBook = book.copyWith(id: bookId);

    for (int i = 0; i < result.pageImagePaths.length; i++) {
      onProgress(i + 1, result.pageImagePaths.length);
      final text = i < result.pageTexts.length ? result.pageTexts[i] : '';
      final page = StoryPage(
        bookId: bookId,
        pageNumber: i + 1,
        imagePath: result.pageImagePaths[i],
        text: text,
      );
      final pageId = await _db.insertPage(page);
      _pagesCache[bookId] ??= [];
      _pagesCache[bookId]!.add(page.copyWith(id: pageId));
    }

    _books.insert(0, savedBook);
    notifyListeners();
    return savedBook;
  }

  Future<void> deletePage(StoryPage page) async {
    await _db.deletePage(page.id!);
    _pagesCache[page.bookId]?.removeWhere((p) => p.id == page.id);
    try {
      await File(page.imagePath).delete();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> saveProgress(int bookId, int pageNumber) async {
    await _db.saveProgress(bookId, pageNumber);
    final idx = _books.indexWhere((b) => b.id == bookId);
    if (idx >= 0) {
      _books[idx] = _books[idx].copyWith(lastPageNumber: pageNumber);
      notifyListeners();
    }
  }
}
