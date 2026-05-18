import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import '../models/book.dart';
import '../models/page.dart' as m;
import '../providers/book_provider.dart';

class ReaderScreen extends StatefulWidget {
  final Book book;

  const ReaderScreen({super.key, required this.book});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late PageController _pageController;
  final FlutterTts _tts = FlutterTts();
  int _currentPage = 0;
  bool _isPlaying = false;
  double _speechRate = 0.5;
  List<m.StoryPage> _pages = [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pages = context.read<BookProvider>().getPagesForBook(widget.book.id!);
    _initTTS();
  }

  Future<void> _initTTS() async {
    await _tts.setLanguage('zh-CN');
    await _tts.setSpeechRate(_speechRate);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);

    _tts.setStartHandler(() {
      if (mounted) setState(() => _isPlaying = true);
    });
    _tts.setCompletionHandler(() {
      if (mounted) {
        setState(() => _isPlaying = false);
        _nextPage();
      }
    });
    _tts.setErrorHandler((msg) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  Future<void> _speak(String text) async {
    if (text.isEmpty) return;
    if (_isPlaying) await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _tts.pause();
      setState(() => _isPlaying = false);
    } else {
      final text = _pages[_currentPage].text;
      if (text.isNotEmpty) {
        await _tts.speak(text);
      }
    }
  }

  Future<void> _stop() async {
    await _tts.stop();
    setState(() => _isPlaying = false);
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    }
  }

  Future<void> _setRate(double rate) async {
    _speechRate = rate;
    await _tts.setSpeechRate(rate);
    if (_isPlaying) {
      final text = _pages[_currentPage].text;
      await _tts.stop();
      await _tts.speak(text);
    }
  }

  @override
  void dispose() {
    _tts.stop();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_pages.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.book.title)),
        body: const Center(child: Text('这本绘本还没有页面')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book.title),
        actions: [
          Text('${_currentPage + 1} / ${_pages.length}',
              style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // 绘本页面
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _pages.length,
              onPageChanged: (i) {
                setState(() => _currentPage = i);
                _stop();
              },
              itemBuilder: (_, i) => _buildPage(_pages[i]),
            ),
          ),
          // 控制栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 进度条
                  Slider(
                    value: _speechRate,
                    min: 0.0,
                    max: 1.0,
                    divisions: 10,
                    label: '语速 ${(_speechRate * 10).round()}',
                    onChanged: _setRate,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('慢', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      const SizedBox(width: 8),
                      const Text('语速', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 8),
                      Text('快', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // 播放控制
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.skip_previous, size: 36),
                        onPressed: _currentPage > 0 ? _prevPage : null,
                      ),
                      IconButton(
                        icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, size: 56),
                        color: Theme.of(context).colorScheme.primary,
                        onPressed: _togglePlay,
                      ),
                      IconButton(
                        icon: const Icon(Icons.stop_circle_outlined, size: 36),
                        onPressed: _stop,
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next, size: 36),
                        onPressed: _currentPage < _pages.length - 1 ? _nextPage : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(m.StoryPage page) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Image.file(File(page.imagePath), fit: BoxFit.cover, width: double.infinity),
            ),
            Expanded(
              flex: 1,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: SingleChildScrollView(
                  child: Text(
                    page.text.isEmpty ? '(无文字)' : page.text,
                    style: const TextStyle(fontSize: 18, height: 1.6),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
