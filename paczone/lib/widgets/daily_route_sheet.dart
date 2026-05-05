import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class _DailyTask {
  final String title;
  final String target;
  final int progress;
  final int total;
  final IconData icon;
  final bool done;

  const _DailyTask({
    required this.title,
    required this.target,
    required this.progress,
    required this.total,
    required this.icon,
    required this.done,
  });
}

class DailyRouteSheet extends StatelessWidget {
  const DailyRouteSheet({super.key});

  static const _tasks = [
    _DailyTask(
      title: '1 PacZone Oluştur',
      target: '1/1',
      progress: 0,
      total: 1,
      icon: Icons.play_circle_outline_rounded,
      done: false,
    ),
    _DailyTask(
      title: '300 m Yürü',
      target: '142 / 300 m',
      progress: 142,
      total: 300,
      icon: Icons.directions_walk_rounded,
      done: false,
    ),
    _DailyTask(
      title: '20 Coin Topla',
      target: '20 / 20',
      progress: 20,
      total: 20,
      icon: Icons.circle,
      done: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.card),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.textHint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              const Icon(Icons.bolt, color: AppColors.secondary, size: 22),
              const SizedBox(width: 8),
              Text("Bugünün Görevleri",
                  style: GoogleFonts.nunito(
                      fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('1/3 Tamamlandı',
                    style: GoogleFonts.nunito(
                        fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.secondary)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ..._tasks.map((t) => _taskRow(t)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppColors.secondary.withAlpha(30),
                AppColors.primary.withAlpha(20),
              ]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.secondary.withAlpha(60)),
            ),
            child: Row(
              children: [
                const Icon(Icons.inventory_2_rounded, color: AppColors.secondary, size: 28),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Günlük Ödül',
                        style: GoogleFonts.nunito(
                            fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                    Text('+200 XP + Özel Coin',
                        style: GoogleFonts.nunito(
                            fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.secondary)),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.textHint.withAlpha(60),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('Kilitli',
                      style: GoogleFonts.nunito(
                          fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textHint)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _taskRow(_DailyTask task) {
    final pct = task.total > 0 ? task.progress / task.total : 0.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: task.done ? AppColors.success.withAlpha(15) : AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: task.done ? AppColors.success.withAlpha(60) : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Icon(
            task.done ? Icons.check_circle_rounded : task.icon,
            color: task.done ? AppColors.success : AppColors.primary,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title,
                    style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: task.done ? AppColors.success : AppColors.textPrimary)),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct.clamp(0.0, 1.0),
                    backgroundColor: AppColors.background,
                    color: task.done ? AppColors.success : AppColors.primary,
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(task.target,
              style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: task.done ? AppColors.success : AppColors.textSecondary)),
        ],
      ),
    );
  }
}
