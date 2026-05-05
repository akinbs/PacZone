import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

    _scaleAnim = Tween<double>(begin: 0.6, end: 1.0)
        .chain(CurveTween(curve: Curves.elasticOut))
        .animate(_ctrl);

    _opacityAnim = Tween<double>(begin: 0.0, end: 1.0)
        .chain(CurveTween(curve: const Interval(0.0, 0.4)))
        .animate(_ctrl);

    _glowAnim = Tween<double>(begin: 0.3, end: 1.0)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_ctrl);

    _ctrl.forward().then((_) async {
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, a, __) => const OnboardingScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background radial glow
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _glowAnim,
              builder: (_, __) => CustomPaint(
                painter: _SplashBgPainter(glowAlpha: (_glowAnim.value * 80).round()),
              ),
            ),
          ),
          // Content
          Center(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => Opacity(
                opacity: _opacityAnim.value,
                child: Transform.scale(
                  scale: _scaleAnim.value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _LogoWithGlow(glowFraction: _glowAnim.value),
                      const SizedBox(height: 24),
                      Text(
                        'PacZone',
                        style: GoogleFonts.nunito(
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Bulunduğun yeri oyuna çevir',
                        style: GoogleFonts.nunito(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Loading indicator at bottom
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _opacityAnim,
              builder: (_, __) => Opacity(
                opacity: _opacityAnim.value,
                child: Column(
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppColors.primary.withAlpha(120)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Yükleniyor...',
                        style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: AppColors.textHint,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoWithGlow extends StatelessWidget {
  final double glowFraction;
  const _LogoWithGlow({required this.glowFraction});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AlwaysStoppedAnimation(glowFraction),
      builder: (_, __) {
        return Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withAlpha((120 * glowFraction).round()),
                blurRadius: 40 * glowFraction,
                spreadRadius: 8 * glowFraction,
              ),
              BoxShadow(
                color: AppColors.secondary.withAlpha((60 * glowFraction).round()),
                blurRadius: 60 * glowFraction,
                spreadRadius: 4 * glowFraction,
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/logo.png',
              width: 140,
              height: 140,
              fit: BoxFit.cover,
            ),
          ),
        );
      },
    );
  }
}

class _SplashBgPainter extends CustomPainter {
  final int glowAlpha;
  const _SplashBgPainter({required this.glowAlpha});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width * 0.8,
      Paint()
        ..color = AppColors.primary.withAlpha(glowAlpha ~/ 3)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.6),
    );
    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * 0.2),
      size.width * 0.4,
      Paint()
        ..color = AppColors.accent.withAlpha(glowAlpha ~/ 4)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.4),
    );
  }

  @override
  bool shouldRepaint(_SplashBgPainter old) => old.glowAlpha != glowAlpha;
}
