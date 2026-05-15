// lib/core/widgets/network_image_strip.dart
import 'package:flutter/material.dart';
import 'package:miritalk_app/core/theme/app_theme.dart';

class NetworkImageStrip extends StatefulWidget {
  final List<String> imageUrls;
  final double size;
  final int? maxCount;
  final double itemSpacing;

  const NetworkImageStrip({
    super.key,
    required this.imageUrls,
    this.size = 72,
    this.maxCount,
    this.itemSpacing = 6,
  });

  @override
  State<NetworkImageStrip> createState() => _NetworkImageStripState();
}

class _NetworkImageStripState extends State<NetworkImageStrip> {
  // 빠른 다중 탭으로 동일 풀스크린 뷰어가 stack 되는 것을 막는다.
  bool _navigating = false;

  Future<void> _openFullscreen(int initialIndex) async {
    if (_navigating) return;
    _navigating = true;
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _NetworkFullscreenViewer(
            imageUrls: widget.imageUrls,
            initialIndex: initialIndex,
          ),
        ),
      );
    } finally {
      if (mounted) _navigating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.maxCount != null
        ? widget.imageUrls.length.clamp(0, widget.maxCount!)
        : widget.imageUrls.length;

    return SizedBox(
      height: widget.size,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: count,
        itemBuilder: (context, i) {
          final url = widget.imageUrls[i];
          return GestureDetector(
            key: ValueKey(url),
            onTap: () => _openFullscreen(i),
            child: Container(
              width: widget.size,
              height: widget.size,
              margin: EdgeInsets.only(right: widget.itemSpacing),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDeep,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  cacheWidth: (widget.size * 2).round(),
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.image_not_supported_outlined,
                    color: AppTheme.textHint,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NetworkFullscreenViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  const _NetworkFullscreenViewer({
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  State<_NetworkFullscreenViewer> createState() => _NetworkFullscreenViewerState();
}

class _NetworkFullscreenViewerState extends State<_NetworkFullscreenViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${_currentIndex + 1} / ${widget.imageUrls.length}',
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.imageUrls.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, index) => InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.0,
              child: Center(
                child: Image.network(
                  widget.imageUrls[index],
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white38,
                    size: 60,
                  ),
                ),
              ),
            ),
          ),
          if (widget.imageUrls.length > 1)
            Positioned(
              bottom: 24 + MediaQuery.of(context).padding.bottom,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: widget.imageUrls.asMap().entries.map((entry) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: _currentIndex == entry.key ? 16 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: _currentIndex == entry.key
                          ? AppTheme.primary
                          : Colors.white30,
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}