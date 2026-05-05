import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/avatar_widget.dart';
import 'avatar_creation_screen.dart';
import 'leaderboard_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AppState.user;
    final xpPct = user.xp / user.xpToNextLevel;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context, user, xpPct)),
            SliverToBoxAdapter(child: _buildStats(user)),
            SliverToBoxAdapter(child: _buildBadges(user.badges)),
            const SliverToBoxAdapter(child: SizedBox(height: 30)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, user, double xpPct) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.surface, AppColors.background],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_ios_rounded,
                    color: AppColors.textSecondary, size: 20),
                padding: EdgeInsets.zero,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const LeaderboardScreen(),
                )),
                icon: const Icon(Icons.leaderboard_rounded,
                    color: AppColors.textSecondary, size: 18),
                label: Text('Sıralama',
                    style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              AvatarWidget(avatar: user.avatar, size: 90, showAura: true),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) =>
                          const AvatarCreationScreen(editMode: true)),
                ),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.background, width: 2),
                  ),
                  child: const Icon(Icons.edit_rounded,
                      color: AppColors.background, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(user.username,
              style: GoogleFonts.nunito(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star_rounded, color: AppColors.secondary, size: 16),
              const SizedBox(width: 4),
              Text('Level ${user.level}',
                  style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary)),
            ],
          ),
          const SizedBox(height: 16),
          // XP bar
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${user.xp} XP',
                      style: GoogleFonts.nunito(
                          fontSize: 12, color: AppColors.textSecondary)),
                  Text('${user.xpToNextLevel} XP',
                      style: GoogleFonts.nunito(
                          fontSize: 12, color: AppColors.textHint)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: xpPct,
                  minHeight: 8,
                  backgroundColor: AppColors.card,
                  valueColor:
                      const AlwaysStoppedAnimation(AppColors.secondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStats(user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('İstatistikler',
              style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          Row(
            children: [
              _statTile(Icons.play_circle_rounded, '${user.totalRuns}', 'Run',
                  AppColors.primary),
              const SizedBox(width: 10),
              _statTile(Icons.circle, '${user.totalCoins}', 'Toplam Coin',
                  AppColors.coin),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _statTile(Icons.directions_walk_rounded,
                  _formatDist(user.totalDistanceMeters),
                  'Mesafe', AppColors.success),
              const SizedBox(width: 10),
              _statTile(Icons.emoji_events_rounded, _formatScore(user.bestScore),
                  'En İyi Skor', AppColors.secondary),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _statTile(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary)),
                  Text(label,
                      style: GoogleFonts.nunito(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadges(List<String> badges) {
    final badgeData = {
      'first_run': ('İlk Koşu', Icons.play_arrow_rounded, AppColors.primary),
      'coin_collector': ('Coin Toplayıcı', Icons.circle, AppColors.coin),
      'explorer': ('Kaşif', Icons.explore_rounded, AppColors.success),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rozetler',
              style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: badges.map((b) {
              final data = badgeData[b];
              if (data == null) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: data.$3.withAlpha(20),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: data.$3.withAlpha(60)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(data.$2, color: data.$3, size: 18),
                    const SizedBox(width: 6),
                    Text(data.$1,
                        style: GoogleFonts.nunito(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: data.$3)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _formatDist(double m) {
    if (m >= 1000) return '${(m / 1000).toStringAsFixed(1)} km';
    return '${m.round()} m';
  }

  String _formatScore(int s) {
    if (s >= 1000) return '${(s / 1000).toStringAsFixed(1)}K';
    return s.toString();
  }
}
