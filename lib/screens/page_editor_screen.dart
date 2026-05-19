import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/book_provider.dart';
import '../models/page.dart' as m;

class PageEditorScreen extends StatefulWidget {
  final int bookId;
  final m.StoryPage? page;

  const PageEditorScreen({super.key, required this.bookId, this.page});

  @override
  State<PageEditorScreen> createState() => _PageEditorScreenState();
}

class _PageEditorScreenState extends State<PageEditorScreen> {
  final _textController = TextEditingController();
  final FlutterTts _tts = FlutterTts();
  String? _imagePath;
  final _picker = ImagePicker();
  bool _saving = false;
  bool _isPreviewing = false;
  bool _isRecognizing = false;
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.chinese);

  Future<void> _preview() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isPreviewing = true);
    await _tts.setLanguage('zh-CN');
    await _tts.setSpeechRate(0.5);
    await _tts.speak(text);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isPreviewing = false);
    });
  }

  bool get _isEditing => widget.page != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _textController.text = widget.page!.text;
      _imagePath = widget.page!.imagePath;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final xfile = await _picker.pickImage(source: source, maxWidth: 1024);
    if (xfile == null) return;

    setState(() {
      _imagePath = xfile.path;
      _isRecognizing = true;
    });

    try {
      final inputImage = InputImage.fromFilePath(xfile.path);
      final recognized = await _textRecognizer.processImage(inputImage);
      if (recognized.text.isNotEmpty && _imagePath == xfile.path) {
        _textController.text = recognized.text;
      }
    } catch (_) {
      // OCR 失败不阻塞流程
    }

    if (mounted) setState(() => _isRecognizing = false);
  }

  Future<void> _save() async {
    final text = _textController.text.trim();
    if (_imagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择页面图片')),
      );
      return;
    }
    setState(() => _saving = true);
    final provider = context.read<BookProvider>();
    if (_isEditing) {
      await provider.updatePage(widget.page!.copyWith(text: text));
    } else {
      await provider.addPage(widget.bookId, text, _imagePath!);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _tts.stop();
    _textRecognizer.close();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? '编辑页面' : '添加页面')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: () => _showImageSourceDialog(),
              child: Container(
                height: 200,
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
                          Text('点击选择页面图片', style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _textController,
              decoration: InputDecoration(
                labelText: '页面文字（朗读内容）',
                border: const OutlineInputBorder(),
                prefixIcon: _isRecognizing
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : const Icon(Icons.text_fields),
                suffixIcon: IconButton(
                  icon: Icon(_isPreviewing ? Icons.volume_up : Icons.volume_up_outlined),
                  color: _isPreviewing ? Theme.of(context).colorScheme.primary : null,
                  tooltip: '试听',
                  onPressed: _preview,
                ),
                alignLabelWithHint: true,
              ),
              maxLines: 5,
              minLines: 3,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(_saving ? '保存中...' : '保存页面'),
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
