import 'dart:io';
import 'package:flutter/gestures.dart';
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
      _pageController.nextPage(
          duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
          duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    }
  }

  void _jumpToPage(int index) {
    _pageController.animateToPage(index,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    Navigator.pop(context);
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

  void _showContents() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ContentsSheet(
        pages: _pages,
        currentPage: _currentPage,
        onTap: _jumpToPage,
      ),
    );
  }

  void _showSpeedSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              const Text('朗读语速', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Slider(
                value: _speechRate,
                min: 0.0,
                max: 1.0,
                divisions: 10,
                label: '${(_speechRate * 10).round()}',
                onChanged: (v) => setSheetState(() => _speechRate = v),
                onChangeEnd: _setRate,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('慢', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                  Text('快', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tokenizer ──

  List<String> _tokenize(String text) {
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

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    if (_pages.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.book.title)),
        body: const Center(child: Text('这本绘本还没有页面')),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8), // 米黄色书卷背景

      // ── 顶栏 ──
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.book.title,
          style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt, size: 22),
            tooltip: '目录',
            onPressed: _showContents,
          ),
          IconButton(
            icon: const Icon(Icons.speed, size: 22),
            tooltip: '语速',
            onPressed: _showSpeedSheet,
          ),
          const SizedBox(width: 4),
        ],
      ),

      // ── 书本区域 ──
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

          // ── 底部控制栏 ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 页码指示器
                  _buildPageDots(),
                  const SizedBox(height: 12),
                  // 控制按钮
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 上一页
                      _ControlButton(
                        icon: Icons.skip_previous,
                        size: 28,
                        onTap: _currentPage > 0 ? _prevPage : null,
                      ),
                      const SizedBox(width: 20),
                      // 播放/暂停 (主按钮)
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            color: colorScheme.onPrimary,
                            size: 32,
                          ),
                          onPressed: _togglePlay,
                        ),
                      ),
                      const SizedBox(width: 20),
                      // 下一页
                      _ControlButton(
                        icon: Icons.skip_next,
                        size: 28,
                        onTap: _currentPage < _pages.length - 1 ? _nextPage : null,
                      ),
                      const SizedBox(width: 28),
                      // 自动翻页
                      _ControlButton(
                        icon: Icons.autorenew,
                        size: 24,
                        active: _autoPlay,
                        onTap: () => setState(() => _autoPlay = !_autoPlay),
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

  Widget _buildPageDots() {
    final count = _pages.length;
    if (count <= 1) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  // ── 单页内容 ──

  Widget _buildPage(m.StoryPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 底层：绘本图片，可缩放
            InteractiveViewer(
              minScale: 1.0,
              maxScale: 3.0,
              child: Image.file(
                File(page.imagePath),
                fit: BoxFit.cover,
              ),
            ),
            // 顶层：文字浮在图片上
            if (page.text.isNotEmpty) _buildTextOverlay(page.text),
          ],
        ),
      ),
    );
  }

  Widget _buildTextOverlay(String text) {
    final tokens = _tokenize(text);
    return Column(
      children: [
        const Spacer(),
        // 渐变遮罩 + 文字
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Color(0xBB000000),
              ],
            ),
          ),
          child: Text.rich(
            TextSpan(
              style: const TextStyle(
                fontSize: 22,
                height: 1.8,
                color: Colors.white,
                letterSpacing: 2,
                shadows: [
                  Shadow(color: Colors.black54, blurRadius: 4),
                ],
              ),
              children: List.generate(tokens.length, (i) {
                final token = tokens[i];
                final isHighlighted = _highlightedCharIndex == i;
                final isPunct = _isPunctuation(token);

                return TextSpan(
                  text: token,
                  style: TextStyle(
                    color: isHighlighted ? Colors.orangeAccent : Colors.white,
                    backgroundColor: isHighlighted
                        ? Colors.orange.withOpacity(0.3)
                        : Colors.transparent,
                    fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                  ),
                  recognizer: isPunct
                      ? null
                      : (TapGestureRecognizer()..onTap = () => _onCharTap(i, token)),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}

// ── 控制按钮 ──

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback? onTap;
  final bool active;

  const _ControlButton({
    required this.icon,
    required this.size,
    this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = onTap == null
        ? Colors.grey.shade400
        : (active ? Theme.of(context).colorScheme.primary : Colors.grey.shade700);

    return IconButton(
      icon: Icon(icon, size: size, color: color),
      onPressed: onTap,
      splashRadius: 22,
    );
  }
}

// ── 目录弹窗 ──

class _ContentsSheet extends StatelessWidget {
  final List<m.StoryPage> pages;
  final int currentPage;
  final void Function(int) onTap;

  const _ContentsSheet({
    required this.pages,
    required this.currentPage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          const Text('目录', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.85,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: pages.length,
              itemBuilder: (_, i) {
                final isActive = i == currentPage;
                return GestureDetector(
                  onTap: () => onTap(i),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isActive
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade200,
                        width: isActive ? 2.5 : 1,
                      ),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        Expanded(
                          child: Image.file(
                            File(pages[i].imagePath),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey.shade100,
                              child: const Icon(Icons.image, color: Colors.grey),
                            ),
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                          color: isActive
                              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                              : Colors.grey.shade50,
                          child: Text(
                            '第${i + 1}页',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                              color: isActive
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
