import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/gradient_button.dart';
import '../widgets/minerva_logo.dart';
import 'main_shell.dart';

/// Launch screen: the brand lockup, the tagline, and the way in.
///
/// The logo fades and lifts into place on first frame, which gives the app a
/// moment of personality before the utilitarian booking flow starts.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.06),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _getStarted() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (_, _, _) => const MainShell(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.softGradient),
        child: Stack(
          children: [
            // Two blurred blobs give the flat gradient some depth.
            const _Blob(
              top: -70,
              right: -60,
              size: 240,
              color: AppColors.pink,
              opacity: 0.28,
            ),
            const _Blob(
              bottom: -90,
              left: -70,
              size: 280,
              color: AppColors.purple,
              opacity: 0.14,
            ),
            SafeArea(
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        const Spacer(flex: 3),
                        const MinervaLogo(markSize: 78, titleSize: 34),
                        const SizedBox(height: 34),
                        Text(
                          'Beautiful nails,\nperfect time.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.purple,
                            fontWeight: FontWeight.w400,
                            fontSize: 17,
                            height: 1.6,
                          ),
                        ),
                        const Spacer(flex: 3),
                        GradientButton(
                          label: 'Get Started',
                          onPressed: _getStarted,
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
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

/// Soft circular colour blob used as background decoration.
class _Blob extends StatelessWidget {
  const _Blob({
    this.top,
    this.left,
    this.right,
    this.bottom,
    required this.size,
    required this.color,
    required this.opacity,
  });

  final double? top;
  final double? left;
  final double? right;
  final double? bottom;
  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
