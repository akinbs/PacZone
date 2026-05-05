import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_state.dart';
import '../models/result_model.dart';
import '../theme/app_colors.dart';
import '../widgets/stat_card.dart';
import 'home_map_screen.dart';
import 'leaderboard_screen.dart';

class ResultScreen extends StatefulWidget {
  final ResultModel result;
  const ResultScreen({super.key, required this.result});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scoreAnim;
  late Animation<double> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _scoreAnim = Tween<double>(begin: 0, end: 1.0)
        .chain(CurveTween(curve: Curves.easeOut))
        .animate(_ctrl);
    _slideAnim = Tween<double>(begin: 40, end: 0)
        .chain(CurveTween(curve: const Interval(0.3, 1.0, curve: Curves.easeOut)))
        .animate(_ctrl);
    _fadeAnim = Tween<double>(begin: 0, end: 1.0)
        .chain(CurveTween(curve: const Interval(0.3, 1.0)))
        .animate(_ctrl);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _formatDist(double m) {
    if (m >= 1000) return '${(m / 1000).toStringAsFixed(1)} km';
    return '${m.round()} m';
  }

  String _formatDur(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final avatar = AppState.user.avatar;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background glow
          Positioned.fill(
            child: CustomPaint(
              painter: _ResultBgPainter(color: avatar.primaryColor),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),

                // Title
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, __) => Opacity(
                    opacity: _scoreAnim.value,
                    child: Column(
                      children: [
                        if (r.isNewRecord)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 5),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                AppColors.secondary.withAlpha(60),
                                AppColors.primary.withAlpha(40),
                              ]),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: AppColors.secondary.withAlpha(100),
                                  width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.emoji_events_rounded,
                                    color: AppColors.secondary, size: 16),
                                const SizedBox(width: 6),
                                Text('Yeni Rekor!',
                                    style: GoogleFonts.nunito(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.secondary)),
                              ],
                            ),
                          ),
                        Text(
                          'PacZone\nTamamlandı',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Big score
                AnimatedBuilder(
                  animation: _scoreAnim,
                  builder: (_, __) {
                    final displayed =
                        (r.finalScore * _scoreAnim.value).round();
                    return Text(
                      _formatScore(displayed),
                      style: GoogleFonts.nunito(
                        fontSize: 64,
                        fontWeight: FontWeight.w900,
                        color: avatar.primaryColor,
                        letterSpacing: -2,
                        shadows: [
                          Shadow(
                            color: avatar.primaryColor.withAlpha(100),
                            blurRadius: 30,
                          ),
                        ],
                      ),
                    );
                  },
                ),

                Text('PUAN',
                    style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textHint,
                        letterSpacing: 3)),

                const SizedBox(height: 28),

                // Stat cards
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, __) => Transform.translate(
                    offset: Offset(0, _slideAnim.value),
                    child: Opacity(
                      opacity: _fadeAnim.value,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                    child: StatCard(
                                        label: 'Coin',
                                        value: '${r.coinsCollected}',
                                        icon: Icons.circle,
                                        iconColor: AppColors.coin)),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: StatCard(
                                        label: 'Mesafe',
                                        value: _formatDist(r.distanceWalkedMeters),
                                        icon: Icons.directions_walk_rounded,
                                        iconColor: AppColors.primary)),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: StatCard(
                                        label: 'Süre',
                                        value: _formatDur(r.duration),
                                        icon: Icons.timer_rounded,
                                        iconColor: AppColors.success)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                    child: StatCard(
                                        label: 'Maks Combo',
                                        value: 'x${r.maxCombo}',
                                        icon: Icons.bolt,
                                        iconColor: AppColors.secondary)),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: StatCard(
                                        label: 'XP Kazanıldı',
                                        value: '+${r.xpEarned}',
                                        icon: Icons.star_rounded,
                                        iconColor: AppColors.accent)),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: _rankCard(r.rank)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // Buttons
                AnimatedBuilder(
                  animation: _fadeAnim,
                  builder: (_, __) => Opacity(
                    opacity: _fadeAnim.value,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _actionBtn(
                                  'Tekrar Dene',
                                  Icons.refresh_rounded,
                                  AppColors.primary,
                                  () => Navigator.of(context).pop(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _actionBtn(
                                  'Haritaya Dön',
                                  Icons.map_rounded,
                                  AppColors.card,
                                  () => Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(
                                        builder: (_) => const HomeMapScreen()),
                                    (_) => false,
                                  ),
                                  textColor: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _outlineBtn(
                                  'Leaderboard',
                                  Icons.leaderboard_rounded,
                                  () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const LeaderboardScreen()),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _outlineBtn(
                                  'Paylaş',
                                  Icons.share_rounded,
                                  () {},
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rankCard(int rank) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.leaderboard_rounded, color: AppColors.accent, size: 20),
          const SizedBox(height: 8),
          Text('#$rank',
              style: GoogleFonts.nunito(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text('Sıralama',
              style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, IconData icon, Color bg, VoidCallback onTap,
      {Color? textColor}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: textColor ?? AppColors.background, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: textColor ?? AppColors.background)),
          ],
        ),
      ),
    );
  }

  Widget _outlineBtn(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.textHint, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 17),
            const SizedBox(width: 7),
            Text(label,
                style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  String _formatScore(int s) {
    if (s >= 1000) {
      return '${(s / 1000).toStringAsFixed(s % 1000 == 0 ? 0 : 1)}K';
    }
    return s.toString();
  }
}

class _ResultBgPainter extends CustomPainter {
  final Color color;
  const _ResultBgPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.25),
      size.width * 0.7,
      Paint()
        ..color = color.withAlpha(18)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.5),
    );
  }

  @override
  bool shouldRepaint(_ResultBgPainter old) => old.color != color;
}
