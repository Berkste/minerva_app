import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/appointment.dart';
import '../../models/salon_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatting.dart';
import '../../widgets/gradient_button.dart';

/// Confirmation screen shown once the booking has been written to storage.
class SuccessScreen extends StatefulWidget {
  const SuccessScreen({super.key, required this.appointment});

  final Appointment appointment;

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  /// The tick pops in with a slight overshoot.
  late final Animation<double> _checkScale = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.45, curve: Curves.easeOutBack),
  );

  /// Confetti flies outward over the first two-thirds of the animation.
  late final Animation<double> _confetti = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.05, 0.75, curve: Curves.easeOut),
  );

  /// Copy fades up after the tick has landed.
  late final Animation<double> _textFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.35, 0.8, curve: Curves.easeOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Unwinds the whole booking stack back to the home shell.
  void _backToHome() =>
      Navigator.of(context).popUntil((route) => route.isFirst);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Back navigation is intentionally absent: the booking is already saved,
      // so there is nothing behind this screen to return to.
      body: SafeArea(
        // Centred with flexible spacers when there is room; scrolls rather
        // than clipping on short screens or at large accessibility text sizes.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(child: _buildContent(context)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final appointment = widget.appointment;
    final service = SalonService.byId(appointment.serviceId);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const Spacer(flex: 2),
          _buildCelebration(),

          // --- Copy ----------------------------------------------------
          FadeTransition(
            opacity: _textFade,
            child: Column(
              children: [
                Text(
                  l10n.appointmentConfirmed,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: AppColors.purple,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  Fmt.of(context).fullDate(appointment.start),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  Fmt.timeRange(appointment.start),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 13.5,
                  ),
                ),
                if (service != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    service.name(l10n),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 13.5,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                Text(
                  l10n.thankYouMessage(appointment.firstName),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.6,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(flex: 3),
          GradientButton(label: l10n.backToHome, onPressed: _backToHome),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// The tick badge with the confetti burst behind it.
  Widget _buildCelebration() {
    return SizedBox(
      width: 220,
      height: 220,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(220, 220),
                painter: _ConfettiPainter(_confetti.value),
              ),
              ScaleTransition(scale: _checkScale, child: child),
            ],
          );
        },
        child: Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.white,
            border: Border.all(color: AppColors.purple, width: 2.2),
            boxShadow: [
              BoxShadow(
                color: AppColors.purple.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 42,
            color: AppColors.purple,
          ),
        ),
      ),
    );
  }
}

/// Draws small ribbons flying out from the centre.
///
/// [progress] runs 0 -> 1: pieces travel outward, spin, and fade as they go.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.progress);

  final double progress;

  static const int _pieceCount = 26;
  static const List<Color> _palette = [
    AppColors.purple,
    AppColors.pink,
    AppColors.purpleLight,
    Color(0xFFFFD6E7),
    Color(0xFFD9C7FF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final centre = Offset(size.width / 2, size.height / 2);
    // Fixed seed: the burst looks random but is identical every run, so it
    // never flickers between frames.
    final random = math.Random(7);
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < _pieceCount; i++) {
      final angle =
          (i / _pieceCount) * 2 * math.pi + random.nextDouble() * 0.35;
      final maxDistance = size.width * (0.30 + random.nextDouble() * 0.20);
      final distance = maxDistance * progress;

      final position = centre +
          Offset(math.cos(angle) * distance, math.sin(angle) * distance);

      // Fade out over the final third of the flight.
      final opacity = progress < 0.65 ? 1.0 : (1 - progress) / 0.35;

      paint.color = _palette[i % _palette.length]
          .withValues(alpha: opacity.clamp(0, 1) * 0.85);

      final pieceWidth = 3.0 + random.nextDouble() * 2;
      final pieceHeight = 7.0 + random.nextDouble() * 5;

      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(angle + progress * 4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: pieceWidth,
            height: pieceHeight,
          ),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
