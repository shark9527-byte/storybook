import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/book_provider.dart';

class BookCreatorScreen extends StatefulWidget {
  const BookCreatorScreen({super.key});

  @override
  State<BookCreatorScreen> createState() => _BookCreatorScreenState();
}

class _BookCreatorScreenState extends State<BookCreatorScreen> {
  final _titleController = TextEditingController();
  String? _imagePath;
  final _picker = ImagePicker();
  bool _saving = false;

  Future<void> _pickImage(ImageSource source) async {
    final xfile = await _picker.pickImage(source: source, maxWidth: 1024);
    if (xfile != null) {
      setState(() => _imagePath = xfile.path);
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入绘本名称')),
      );
      return;
    }
    if (_imagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择封面图片')),
      );
      return;
    }
    setState(() => _saving = true);
    await context.read<BookProvider>().addBook(title, _imagePath!);
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('创建绘本')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: () => _showImageSourceDialog(),
              child: Container(
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade400, width: 1.5),
                ),
                clipBehavior: Clip.antiAlias,
                child: _imagePath != null
                    ? Image.file(File(_imagePath!), fit: BoxFit.cover)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo, size: 48, color: Colors.grey.shade500),
                          const SizedBox(height: 8),
                          Text('点击选择封面图片', style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '绘本名称',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.book),
              ),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(_saving ? '保存中...' : '保存绘本'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}
