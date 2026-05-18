import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/book.dart';
import '../models/page.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._();
  factory DatabaseService() => _instance;
  DatabaseService._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'storybook.db');
    return openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE books (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        coverImagePath TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE pages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bookId INTEGER NOT NULL,
        pageNumber INTEGER NOT NULL,
        imagePath TEXT NOT NULL,
        text TEXT NOT NULL,
        FOREIGN KEY (bookId) REFERENCES books(id) ON DELETE CASCADE
      )
    ''');
  }

  // === Book CRUD ===

  Future<int> insertBook(Book book) async {
    final db = await database;
    return db.insert('books', book.toMap());
  }

  Future<List<Book>> getBooks() async {
    final db = await database;
    final maps = await db.query('books', orderBy: 'createdAt DESC');
    return maps.map((m) => Book.fromMap(m)).toList();
  }

  Future<int> updateBook(Book book) async {
    final db = await database;
    return db.update('books', book.toMap(), where: 'id = ?', whereArgs: [book.id]);
  }

  Future<int> deleteBook(int bookId) async {
    final db = await database;
    await db.delete('pages', where: 'bookId = ?', whereArgs: [bookId]);
    return db.delete('books', where: 'id = ?', whereArgs: [bookId]);
  }

  // === Page CRUD ===

  Future<int> insertPage(StoryPage page) async {
    final db = await database;
    return db.insert('pages', page.toMap());
  }

  Future<List<StoryPage>> getPages(int bookId) async {
    final db = await database;
    final maps = await db.query(
      'pages',
      where: 'bookId = ?',
      whereArgs: [bookId],
      orderBy: 'pageNumber ASC',
    );
    return maps.map((m) => StoryPage.fromMap(m)).toList();
  }

  Future<int> updatePage(StoryPage page) async {
    final db = await database;
    return db.update('pages', page.toMap(), where: 'id = ?', whereArgs: [page.id]);
  }

  Future<int> deletePage(int pageId) async {
    final db = await database;
    return db.delete('pages', where: 'id = ?', whereArgs: [pageId]);
  }

  Future<int> getPageCount(int bookId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM pages WHERE bookId = ?',
      [bookId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> reorderPages(int bookId, List<int> pageIds) async {
    final db = await database;
    final batch = db.batch();
    for (int i = 0; i < pageIds.length; i++) {
      batch.update('pages', {'pageNumber': i + 1},
          where: 'id = ?', whereArgs: [pageIds[i]]);
    }
    await batch.commit(noResult: true);
  }
}
