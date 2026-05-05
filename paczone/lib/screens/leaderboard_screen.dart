import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/leaderboard_model.dart';
import '../theme/app_colors.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _LeaderboardList(items: LeaderboardModel.mockWeekly()),
                  _LeaderboardList(items: LeaderboardModel.mockAllTime()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: AppColors.textSecondary, size: 20),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Leaderboard',
                  style: GoogleFonts.nunito(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary)),
              Text('Bu bölgenin en iyileri',
                  style: GoogleFonts.nunito(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: TabBar(
          controller: _tabCtrl,
          indicator: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: AppColors.background,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800),
          unselectedLabelStyle:
              GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Haftalık'),
            Tab(text: 'Tüm Zamanlar'),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardList extends StatelessWidget {
  final List<LeaderboardItem> items;
  const _LeaderboardList({required this.items});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      itemCount: items.length,
      itemBuilder: (_, i) => _LeaderboardRow(item: items[i], index: i),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final LeaderboardItem item;
  final int index;
  const _LeaderboardRow({required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    final isTop3 = item.rank <= 3;
    final rankColor = switch (item.rank) {
      1 => const Color(0xFFFFD700),
      2 => const Color(0xFFC0C0C0),
      3 => const Color(0xFFCD7F32),
      _ => AppColors.textHint,
    };

    return AnimatedOpacity(
      duration: Duration(milliseconds: 200 + index * 60),
      opacity: 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: item.isCurrentUser
              ? AppColors.primary.withAlpha(20)
              : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.isCurrentUser
                ? AppColors.primary.withAlpha(80)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Rank
            SizedBox(
              width: 32,
              child: isTop3
                  ? Icon(Icons.emoji_events_rounded, color: rankColor, size: 22)
                  : Text(
                      '#${item.rank}',
                      style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: rankColor),
                    ),
            ),
            const SizedBox(width: 12),

            // Avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: item.avatarColor.withAlpha(30),
                border: Border.all(color: item.avatarColor.withAlpha(100), width: 2),
              ),
              child: Center(
                child: Text(
                  item.username[0].toUpperCase(),
                  style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: item.avatarColor),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Name + level
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        item.username,
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: item.isCurrentUser
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (item.isCurrentUser) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(30),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('Sen',
                              style: GoogleFonts.nunito(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary)),
                        ),
                      ],
                    ],
                  ),
                  Text('Lv ${item.level}',
                      style: GoogleFonts.nunito(
                          fontSize: 11,
                          color: AppColors.textHint)),
                ],
              ),
            ),

            // Score
            Text(
              _formatScore(item.score),
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: isTop3 ? rankColor : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatScore(int s) {
    if (s >= 1000) return '${(s / 1000).toStringAsFixed(1)}K';
    return s.toString();
  }
}
