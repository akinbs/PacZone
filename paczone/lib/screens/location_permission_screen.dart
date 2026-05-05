import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_colors.dart';
import 'home_map_screen.dart';

class LocationPermissionScreen extends StatelessWidget {
  const LocationPermissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Illustration
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withAlpha(18),
                  border: Border.all(
                      color: AppColors.primary.withAlpha(60), width: 1.5),
                ),
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withAlpha(12),
                          border: Border.all(
                              color: AppColors.primary.withAlpha(40), width: 1),
                        ),
                      ),
                      const Icon(
                        Icons.location_on_rounded,
                        color: AppColors.primary,
                        size: 64,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Text(
                'PacZone oluşturmak için\nkonum gerekli',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Konumun, bulunduğun yerde güvenli bir oyun alanı olup olmadığını kontrol etmek ve karakterini haritada göstermek için kullanılır.',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 32),
              // Info cards
              Row(
                children: [
                  _infoCard(
                    Icons.security_rounded,
                    'Güvenlik',
                    'Güvenli olmayan alanlarda oyun başlatılmaz',
                    AppColors.success,
                  ),
                  const SizedBox(width: 12),
                  _infoCard(
                    Icons.visibility_off_rounded,
                    'Gizlilik',
                    'Konumun sadece oyun için kullanılır',
                    AppColors.primary,
                  ),
                ],
              ),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await Geolocator.requestPermission();
                    if (!context.mounted) return;
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const HomeMapScreen()),
                    );
                  },
                  icon: const Icon(Icons.location_on_rounded, size: 20),
                  label: Text(
                    'Konum İznini Aç',
                    style:
                        GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.background,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const HomeMapScreen()),
                ),
                child: Text(
                  'Şimdilik atla',
                  style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: AppColors.textHint,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoCard(IconData icon, String title, String body, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(title,
                style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(body,
                style: GoogleFonts.nunito(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.4)),
          ],
        ),
      ),
    );
  }
}
