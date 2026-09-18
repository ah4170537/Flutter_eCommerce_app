import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ProductImageSlider extends StatefulWidget {
  final List<String> effectiveImages;

  const ProductImageSlider({super.key, required this.effectiveImages});

  @override
  State<ProductImageSlider> createState() => _ProductImageSliderState();
}

class _ProductImageSliderState extends State<ProductImageSlider> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final images = widget.effectiveImages;

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        PageView.builder(
          itemCount: images.isNotEmpty ? images.length : 1,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          itemBuilder: (context, index) {
            final imgUrl = images.isNotEmpty ? images[index] : '';
            return CachedNetworkImage(
              imageUrl: imgUrl,
              fit: BoxFit.contain,
              fadeInDuration: const Duration(milliseconds: 100),
              placeholder: (context, url) => Container(color: AppColors.hintGrey),
              errorWidget: (context, url, error) => Container(
                color: AppColors.hintGrey,
                child: const Icon(
                  Icons.image_not_supported,
                  size: 50,
                  color: AppColors.textGrey,
                ),
              ),
            );
          },
        ),
        if (images.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(images.length, (index) {
                return Container(
                  width: 8.0,
                  height: 8.0,
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentIndex == index
                        ? AppColors.primaryDark
                        : Colors.grey.withValues(alpha: 0.5),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}