import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_theme.dart';

/// Generic shimmer skeleton card
class ShimmerCard extends StatelessWidget {
  final double height;
  final double? width;
  final double borderRadius;

  const ShimmerCard({
    super.key,
    this.height = 80,
    this.width,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceElevated,
      highlightColor: AppColors.surfaceCard.withOpacity(0.3),
      child: Container(
        height: height,
        width: width ?? double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Shimmer list — stacked skeleton cards for loading state
class ShimmerList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final double spacing;
  final double borderRadius;

  const ShimmerList({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 80,
    this.spacing = 12,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (i) => Padding(
          padding: EdgeInsets.only(bottom: spacing),
          child: ShimmerCard(
            height: itemHeight,
            borderRadius: borderRadius,
          ),
        ),
      ),
    );
  }
}

/// Horizontal shimmer carousel (for campaign cards)
class ShimmerCarousel extends StatelessWidget {
  final int itemCount;
  final double itemWidth;
  final double itemHeight;

  const ShimmerCarousel({
    super.key,
    this.itemCount = 3,
    this.itemWidth = 280,
    this.itemHeight = 160,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: itemHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => ShimmerCard(
          width: itemWidth,
          height: itemHeight,
          borderRadius: 16,
        ),
      ),
    );
  }
}

/// Shimmer avatar circle
class ShimmerAvatar extends StatelessWidget {
  final double size;
  const ShimmerAvatar({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceElevated,
      highlightColor: AppColors.surfaceCard.withOpacity(0.3),
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: AppColors.surfaceElevated,
      ),
    );
  }
}

/// Single shimmer line (for text placeholders)
class ShimmerLine extends StatelessWidget {
  final double width;
  final double height;
  const ShimmerLine({super.key, this.width = 120, this.height = 14});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceElevated,
      highlightColor: AppColors.surfaceCard.withOpacity(0.3),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
