import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/book.dart';
import '../providers/book_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/book_card.dart';
import 'book_creator_screen.dart';
import 'book_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的绘本'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: Icon(context.watch<ThemeProvider>().isDark ? Icons.light_mode : Icons.dark_mode),
            tooltip: '切换主题',
            onPressed: () => context.read<ThemeProvider>().toggle(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateOptions(context),
        icon: const Icon(Icons.add),
        label: const Text('添加绘本'),
      ),
      body: Consumer<BookProvider>(
        builder: (context, provider, _) {
          if (provider.books.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.menu_book, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('还没有绘本\n点击下方按钮创建或导入吧',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                ],
              ),
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 600 ? 3 : 2);
              return GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  childAspectRatio: 0.72,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: provider.books.length,
                itemBuilder: (_, i) => BookCard(
                  book: provider.books[i],
                  onDelete: () => provider.deleteBook(provider.books[i].id!),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showCreateOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('添加绘本', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('手动创建'),
              subtitle: const Text('拍照或选图，逐页制作绘本'),
              onTap: () {
                Navigator.pop(ctx);
                _createBook(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('导入PDF'),
              subtitle: const Text('从PDF文件自动生成绘本'),
              onTap: () {
                Navigator.pop(ctx);
                _importPdf(context);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _createBook(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BookCreatorScreen()),
    );
    if (context.mounted) {
      context.read<BookProvider>().loadBooks();
    }
  }

  Future<void> _importPdf(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.isEmpty) return;

    final pdfPath = result.files.single.path!;
    if (!context.mounted) return;

    Book? importedBook;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('导入中...'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LinearProgressIndicator(),
                  const SizedBox(height: 16),
                  Consumer<BookProvider>(
                    builder: (_, __, ___) => const Text('正在解析PDF页面...'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    try {
      importedBook = await context.read<BookProvider>().importPdf(
        pdfPath,
        (current, total) {
          // progress callback - could update dialog
        },
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // dismiss dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败：$e')),
        );
      }
      return;
    }

    if (context.mounted) {
      Navigator.pop(context); // dismiss dialog
      if (importedBook != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BookDetailScreen(book: importedBook!),
          ),
        );
      }
    }
  }
}
