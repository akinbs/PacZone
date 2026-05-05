import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import 'pz_button.dart';

class PauseSheet extends StatelessWidget {
  final VoidCallback onResume;
  final VoidCallback onQuit;

  const PauseSheet({
    super.key,
    required this.onResume,
    required this.onQuit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.card),
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: AppColors.textHint,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Icon(Icons.pause_circle_filled_rounded, color: AppColors.primary, size: 56),
          const SizedBox(height: 12),
          Text('Duraklatıldı',
              style: GoogleFonts.nunito(
                  fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text('Oyun duraklatıldı. Devam etmek ister misin?',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 28),
          PZButton(
            label: 'Devam Et',
            onPressed: onResume,
            style: PZButtonStyle.primary,
            width: double.infinity,
            icon: Icons.play_arrow_rounded,
          ),
          const SizedBox(height: 12),
          PZButton(
            label: 'Haritaya Dön',
            onPressed: onQuit,
            style: PZButtonStyle.ghost,
            width: double.infinity,
          ),
        ],
      ),
    );
  }
}
