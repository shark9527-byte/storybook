import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/book_provider.dart';
import '../widgets/book_card.dart';
import 'book_creator_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的绘本'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BookCreatorScreen()),
          );
          if (context.mounted) {
            context.read<BookProvider>().loadBooks();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('创建绘本'),
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
                  Text('还没有绘本\n点击下方按钮创建第一本吧',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                ],
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
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
      ),
    );
  }
}
