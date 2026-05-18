import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/book.dart';
import '../models/page.dart' as m;
import '../providers/book_provider.dart';
import 'page_editor_screen.dart';
import 'reader_screen.dart';

class BookDetailScreen extends StatelessWidget {
  final Book book;

  const BookDetailScreen({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BookProvider>();
    final pages = provider.getPagesForBook(book.id!);

    return Scaffold(
      appBar: AppBar(
        title: Text(book.title),
        actions: [
          if (pages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.play_circle_filled),
              tooltip: '开始阅读',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ReaderScreen(book: book)),
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PageEditorScreen(bookId: book.id!),
            ),
          );
          if (context.mounted) {
            context.read<BookProvider>().loadPages(book.id!);
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('添加页面'),
      ),
      body: pages.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_stories, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text('还没有页面\n点击下方按钮添加', textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                ],
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: pages.length,
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex--;
                final reordered = List<m.StoryPage>.from(pages);
                final item = reordered.removeAt(oldIndex);
                reordered.insert(newIndex, item);
                final ids = reordered.map((p) => p.id!).toList();
                provider.loadPages(book.id!);
              },
              itemBuilder: (_, i) => _PageTile(
                key: ValueKey(pages[i].id),
                page: pages[i],
                onEdit: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PageEditorScreen(bookId: book.id!, page: pages[i]),
                    ),
                  );
                  if (context.mounted) {
                    context.read<BookProvider>().loadPages(book.id!);
                  }
                },
                onDelete: () => provider.deletePage(pages[i]),
              ),
            ),
    );
  }
}

class _PageTile extends StatelessWidget {
  final m.StoryPage page;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PageTile({super.key, required this.page, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: SizedBox(
          height: 80,
          child: Row(
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: Image.file(
                  File(page.imagePath),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.orange.shade100,
                    child: Center(
                      child: Text('${page.pageNumber}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 3,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.orange.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('第 ${page.pageNumber} 页',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      const SizedBox(height: 2),
                      Text(page.text.isEmpty ? '(无文字)' : page.text,
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15)),
                    ],
                  ),
                ),
              ),
              IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: onEdit),
              IconButton(
                  icon: const Icon(Icons.delete, size: 20, color: Colors.red), onPressed: onDelete),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}
