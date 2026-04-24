import 'package:flutter/material.dart';
import 'package:miritalk_app/core/theme/app_theme.dart';

class NetworkImageStrip extends StatelessWidget {
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

  void _openFullscreen(BuildContext context, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _NetworkFullscreenViewer(
          imageUrls: imageUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = maxCount != null
        ? imageUrls.length.clamp(0, maxCount!)
        : imageUrls.length;

    return SizedBox(
      height: size,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: count,
        itemBuilder: (context, i) {
          final url = imageUrls[i];
          return GestureDetector(
            key: ValueKey(url),
            onTap: () => _openFullscreen(context, i),
            child: Container(
              width: size,
              height: size,
              margin: EdgeInsets.only(right: itemSpacing),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDeep,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  cacheWidth: (size * 2).round(),
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
              bottom: 24,
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