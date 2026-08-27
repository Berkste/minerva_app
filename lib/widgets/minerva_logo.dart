import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The Minerva mark: five petals fanning out from a single point, washed from
/// pink on the outside to purple in the centre.
///
/// Drawn rather than shipped as an image so it stays crisp at any size and the
/// app needs no asset bundle.
class MinervaMark extends StatelessWidget {
  const MinervaMark({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _PetalFanPainter()),
    );
  }
}

class _PetalFanPainter extends CustomPainter {
  /// Fan angles in degrees, measured from straight up.
  static const List<double> _angles = [-52, -26, 0, 26, 52];

  @override
  void paint(Canvas canvas, Size size) {
    // Petals radiate from just below the bottom edge of the box.
    final origin = Offset(size.width / 2, size.height * 0.98);
    final length = size.height * 0.86;
    final width = size.width * 0.20;

    for (var i = 0; i < _angles.length; i++) {
      // Outer petals lean pink, the centre petal is fully purple.
      final distanceFromCentre = (i - (_angles.length - 1) / 2).abs() /
          ((_angles.length - 1) / 2);
      final color = Color.lerp(
        AppColors.purple,
        AppColors.pink,
        distanceFromCentre * 0.85,
      )!;

      // Side petals are slightly shorter, which gives the fan its rounded top.
      final scale = 1 - distanceFromCentre * 0.18;

      canvas.save();
      canvas.translate(origin.dx, origin.dy);
      canvas.rotate(_angles[i] * math.pi / 180);
      canvas.drawPath(
        _petalPath(length * scale, width * scale),
        Paint()
          ..color = color.withValues(alpha: 0.92)
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
      canvas.restore();
    }
  }

  /// A leaf shape pointing up: two mirrored curves meeting at tip and base.
  Path _petalPath(double length, double width) {
    return Path()
      ..moveTo(0, 0)
      ..cubicTo(width, -length * 0.35, width, -length * 0.75, 0, -length)
      ..cubicTo(-width, -length * 0.75, -width, -length * 0.35, 0, 0)
      ..close();
  }

  @override
  bool shouldRepaint(covariant _PetalFanPainter oldDelegate) => false;
}

/// Full lockup: the mark above the "MINERVA / NAIL ART" wordmark.
class MinervaLogo extends StatelessWidget {
  const MinervaLogo({
    super.key,
    this.markSize = 56,
    this.titleSize = 30,
  });

  final double markSize;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MinervaMark(size: markSize),
        SizedBox(height: markSize * 0.28),
        Text(
          'MINERVA',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontSize: titleSize,
            fontWeight: FontWeight.w500,
            letterSpacing: titleSize * 0.16,
            color: AppColors.purple,
            height: 1,
          ),
        ),
        SizedBox(height: titleSize * 0.28),
        Text(
          'NAIL ART',
          style: theme.textTheme.labelMedium?.copyWith(
            fontSize: titleSize * 0.36,
            fontWeight: FontWeight.w400,
            letterSpacing: titleSize * 0.22,
            color: AppColors.pink,
            height: 1,
          ),
        ),
      ],
    );
  }
}
