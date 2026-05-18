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
  bool _autoPlay = false;
  double _speechRate = 0.5;
  List<m.StoryPage> _pages = [];
  int? _highlightedCharIndex;

  @override
  void initState() {
    super.initState();
    _pages = context.read<BookProvider>().getPagesForBook(widget.book.id!);
    final lastPage = widget.book.lastPageNumber;
    final initialPage = lastPage > 0 && lastPage <= _pages.length ? lastPage - 1 : 0;
    _currentPage = initialPage;
    _pageController = PageController(initialPage: initialPage);
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
      if (!mounted) return;
      setState(() => _isPlaying = false);
      if (_autoPlay && _currentPage < _pages.length - 1) {
        _nextPage();
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted && _autoPlay) {
            final text = _pages[_currentPage].text;
            if (text.isNotEmpty) _speak(text);
          }
        });
      } else {
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

  Future<void> _speakChar(String char) async {
    if (char.trim().isEmpty) return;
    await _tts.stop();
    setState(() => _isPlaying = false);
    await _tts.speak(char);
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

  void _onCharTap(int index, String char) {
    setState(() => _highlightedCharIndex = index);
    _speakChar(char);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _highlightedCharIndex = null);
    });
  }

  List<String> _tokenize(String text) {
    // 一-鿿 = 中文逐字 | [a-zA-Z]+ = 英文单词 | . = 其他逐符
    final tokens = <String>[];
    final regex = RegExp(r'[一-鿿]|[a-zA-Z]+|.');
    for (final match in regex.allMatches(text)) {
      tokens.add(match.group(0)!);
    }
    return tokens;
  }

  static const _punctuation = r''' ，。！？；：、（）""''《》-,.!?;:()[]{}<>''';

  bool _isPunctuation(String char) {
    return char.trim().isEmpty || _punctuation.contains(char);
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
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _pages.length,
              onPageChanged: (i) {
                setState(() {
                  _currentPage = i;
                  _highlightedCharIndex = null;
                });
                _stop();
                context.read<BookProvider>().saveProgress(widget.book.id!, i + 1);
              },
              itemBuilder: (_, i) => _buildPage(_pages[i]),
            ),
          ),
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
                      IconButton(
                        icon: Icon(Icons.autorenew, size: 32,
                            color: _autoPlay ? Theme.of(context).colorScheme.primary : Colors.grey),
                        tooltip: _autoPlay ? '关闭自动翻页' : '开启自动翻页',
                        onPressed: () => setState(() => _autoPlay = !_autoPlay),
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 600;
            final image = InteractiveViewer(
              minScale: 1.0,
              maxScale: 3.0,
              child: Image.file(File(page.imagePath), fit: BoxFit.cover),
            );
            if (isWide) {
              return Row(
                children: [
                  Expanded(child: image),
                  SizedBox(
                    width: constraints.maxWidth * 0.4,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      color: Colors.white,
                      child: SingleChildScrollView(
                        child: _buildTappableText(page.text),
                      ),
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                Expanded(flex: 3, child: image),
                Expanded(
                  flex: 1,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: SingleChildScrollView(
                      child: _buildTappableText(page.text),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTappableText(String text) {
    if (text.isEmpty) {
      return const Text('(无文字)', style: TextStyle(fontSize: 18, color: Colors.grey));
    }

    final tokens = _tokenize(text);
    return Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 22, height: 1.8, color: Colors.black87),
        children: List.generate(tokens.length, (i) {
          final token = tokens[i];
          final isHighlighted = _highlightedCharIndex == i;
          final isPunct = _isPunctuation(token);

          return TextSpan(
            text: token,
            style: TextStyle(
              color: isHighlighted ? Colors.orange : (isPunct ? Colors.grey : Colors.black87),
              backgroundColor: isHighlighted ? Colors.orange.withOpacity(0.2) : Colors.transparent,
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
            ),
            recognizer: isPunct
                ? null
                : (TapGestureRecognizer()
                  ..onTap = () => _onCharTap(i, token)),
          );
        }),
      ),
    );
  }
}
