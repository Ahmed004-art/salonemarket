import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/product_model.dart';

/// Responsive image gallery with dots page indicator for Product Details.
class ProductImageGallery extends StatefulWidget {
  const ProductImageGallery({
    super.key,
    required this.images,
  });

  final List<ProductImage> images;

  @override
  State<ProductImageGallery> createState() => _ProductImageGalleryState();
}

class _ProductImageGalleryState extends State<ProductImageGallery> {
  int _currentIndex = 0;
  final _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return Container(
        height: 320,
        color: SaloneMarketTheme.background,
        child: const Center(
          child: Icon(
            Icons.image_outlined,
            size: 64,
            color: SaloneMarketTheme.muted,
          ),
        ),
      );
    }

    return SizedBox(
      height: 340,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (idx) {
              setState(() {
                _currentIndex = idx;
              });
            },
            itemBuilder: (context, index) {
              final img = widget.images[index];
              return CachedNetworkImage(
                imageUrl: img.url,
                fit: BoxFit.cover,
                placeholder: (context, url) => const ColoredBox(
                  color: SaloneMarketTheme.background,
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        SaloneMarketTheme.accent,
                      ),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => const ColoredBox(
                  color: SaloneMarketTheme.background,
                  child: Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      size: 48,
                      color: SaloneMarketTheme.muted,
                    ),
                  ),
                ),
              );
            },
          ),
          if (widget.images.length > 1)
            Positioned(
              bottom: 12,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(widget.images.length, (idx) {
                  final isSelected = _currentIndex == idx;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isSelected ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? SaloneMarketTheme.accent
                          : Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}
