import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/scan_result_model.dart';
import '../theme/app_colors.dart';
import 'pz_button.dart';

enum ScanSheetState { scanning, success, partial, failed, gpsWeak, speedTooHigh, noData }

class ScanBottomSheet extends StatefulWidget {
  final ScanSheetState sheetState;
  final ScanResultModel? result;
  final VoidCallback onStartGame;
  final VoidCallback onBack;

  const ScanBottomSheet({
    super.key,
    required this.sheetState,
    this.result,
    required this.onStartGame,
    required this.onBack,
  });

  @override
  State<ScanBottomSheet> createState() => _ScanBottomSheetState();
}

class _ScanBottomSheetState extends State<ScanBottomSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _dotCtrl;
  int _stepIndex = 0;
  late List<String> _steps;

  @override
  void initState() {
    super.initState();
    _steps = const [
      'Konum merkez alınıyor',
      '150 m × 150 m alan hesaplanıyor',
      'Yaya yolları çıkarılıyor',
      'Binalar duvar olarak işaretleniyor',
      'Araç yolları filtreleniyor',
      'Maze hazırlanıyor',
      'Coinler ve düşmanlar yerleştiriliyor',
    ];
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat();

    if (widget.sheetState == ScanSheetState.scanning) {
      _runScanSteps();
    }
  }

  void _runScanSteps() async {
    for (int i = 0; i < _steps.length; i++) {
      await Future.delayed(const Duration(milliseconds: 520));
      if (!mounted) return;
      setState(() => _stepIndex = i);
    }
  }

  @override
  void dispose() {
    _dotCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.card, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return switch (widget.sheetState) {
      ScanSheetState.scanning     => _buildScanning(),
      ScanSheetState.success      => _buildSuccess(),
      ScanSheetState.partial      => _buildPartial(),
      ScanSheetState.failed       => _buildFailed(),
      ScanSheetState.gpsWeak      => _buildGpsWeak(),
      ScanSheetState.speedTooHigh => _buildSpeedTooHigh(),
      ScanSheetState.noData       => _buildNoData(),
    };
  }

  Widget _buildScanning() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _handle(),
        const SizedBox(height: 4),
        Row(
          children: [
            AnimatedBuilder(
              animation: _dotCtrl,
              builder: (_, __) => SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  value: null,
                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Text('Çevren analiz ediliyor',
                style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
          ],
        ),
        const SizedBox(height: 20),
        ...List.generate(_steps.length, (i) {
          final done = i < _stepIndex;
          final active = i == _stepIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: done
                  ? AppColors.success.withAlpha(20)
                  : active
                      ? AppColors.primary.withAlpha(18)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  done
                      ? Icons.check_circle_rounded
                      : active
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                  color: done
                      ? AppColors.success
                      : active
                          ? AppColors.primary
                          : AppColors.textHint,
                  size: 18,
                ),
                const SizedBox(width: 12),
                Text(
                  _steps[i],
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: done || active ? AppColors.textPrimary : AppColors.textHint,
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildSuccess() {
    final r = widget.result;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _handle(),
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.success.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: AppColors.success, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              r?.isEventZone == true ? 'EventZone hazır!' : 'PacZone hazır!',
              style: GoogleFonts.nunito(
                  fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
            ),
          ],
        ),
        if (r?.isEventZone == true) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppColors.accent.withAlpha(60),
                AppColors.primary.withAlpha(40),
              ]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accent.withAlpha(100)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt, color: AppColors.secondary, size: 16),
                const SizedBox(width: 6),
                Text(
                  '${r?.eventName ?? ''} · ${r?.eventBonus ?? ''}',
                  style: GoogleFonts.nunito(
                      fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.secondary),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        Row(
          children: [
            _statChip(Icons.speed_rounded, '${r?.playabilityScore ?? 82}/100', 'Playability', AppColors.success),
            const SizedBox(width: 10),
            _statChip(Icons.route_rounded, '${r?.playableDistanceMeters.round() ?? 420} m', 'Yol', AppColors.primary),
            const SizedBox(width: 10),
            _statChip(Icons.timer_rounded,
                _formatDur(r?.estimatedDuration ?? const Duration(minutes: 2, seconds: 30)),
                'Süre', AppColors.secondary),
          ],
        ),
        const SizedBox(height: 22),
        PZButton(
          label: 'Chomp Mode Başlat',
          onPressed: widget.onStartGame,
          style: PZButtonStyle.primary,
          width: double.infinity,
          icon: Icons.play_arrow_rounded,
        ),
      ],
    );
  }

  Widget _buildPartial() {
    final r = widget.result;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _handle(),
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.warning.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Kısa PacZone hazır',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '150 m çevrende sınırlı yaya yolu bulundu. Mevcut path ağından daha kısa bir maze oluşturuldu.',
          style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            _statChip(Icons.speed_rounded, '${r?.playabilityScore ?? 61}/100', 'Playability', AppColors.warning),
            const SizedBox(width: 10),
            _statChip(Icons.route_rounded, '${r?.playableDistanceMeters.round() ?? 180} m', 'Yol', AppColors.primary),
            const SizedBox(width: 10),
            _statChip(Icons.timer_rounded,
                _formatDur(r?.estimatedDuration ?? const Duration(minutes: 1, seconds: 15)),
                'Süre', AppColors.secondary),
          ],
        ),
        const SizedBox(height: 22),
        PZButton(
          label: 'Yine de Başlat',
          onPressed: widget.onStartGame,
          style: PZButtonStyle.secondary,
          width: double.infinity,
        ),
        const SizedBox(height: 10),
        PZButton(
          label: 'Başka Yerde Dene',
          onPressed: widget.onBack,
          style: PZButtonStyle.ghost,
          width: double.infinity,
        ),
      ],
    );
  }

  Widget _buildFailed() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _handle(),
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.block_rounded, color: AppColors.error, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Bu alan uygun değil',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'Bu alan PacZone için güvenli değil. 150 m çevrendeki yaya yolu yoğunluğu düşük veya araç yolları fazla olabilir.',
          style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary, height: 1.55),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.place_rounded, color: AppColors.primary, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Park, kampüs, sahil yolu, meydan veya piknik alanında tekrar deneyin.',
                  style: GoogleFonts.nunito(
                      fontSize: 12, color: AppColors.textSecondary, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        PZButton(
          label: 'Haritaya Dön',
          onPressed: widget.onBack,
          style: PZButtonStyle.primary,
          width: double.infinity,
        ),
      ],
    );
  }

  Widget _buildGpsWeak() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _handle(),
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.warning.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.gps_off_rounded, color: AppColors.warning, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Konum doğruluğu düşük',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'Güvenli oyun alanı oluşturmak için konumunu daha net almamız gerekiyor. Açık alanda birkaç saniye bekleyip tekrar deneyin.',
          style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary, height: 1.55),
        ),
        const SizedBox(height: 22),
        PZButton(
          label: 'Tekrar Tara',
          onPressed: widget.onBack,
          style: PZButtonStyle.primary,
          width: double.infinity,
          icon: Icons.refresh_rounded,
        ),
      ],
    );
  }

  Widget _buildSpeedTooHigh() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _handle(),
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.speed_rounded, color: AppColors.error, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Hız çok yüksek',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'Çok hızlı hareket ettiğin için güvenli PacZone oluşturulamadı. '
          'PacZone yürüyüş veya koşu hızında oynanabilir.',
          style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary, height: 1.55),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.directions_walk_rounded, color: AppColors.primary, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Dur, birkaç saniye bekle ve tekrar tara.',
                  style: GoogleFonts.nunito(
                      fontSize: 12, color: AppColors.textSecondary, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        PZButton(
          label: 'Tekrar Tara',
          onPressed: widget.onBack,
          style: PZButtonStyle.primary,
          width: double.infinity,
          icon: Icons.refresh_rounded,
        ),
      ],
    );
  }

  Widget _buildNoData() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _handle(),
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.signal_wifi_off_rounded, color: AppColors.error, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Bağlantı yok',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'Konum verisi alınamadı. İnternet bağlantısı veya GPS sorunu olabilir.',
          style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary, height: 1.55),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.wifi_rounded, color: AppColors.primary, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'İnternet bağlantınızı ve cihaz GPS ayarlarınızı kontrol edin.',
                  style: GoogleFonts.nunito(
                      fontSize: 12, color: AppColors.textSecondary, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        PZButton(
          label: 'Tekrar Dene',
          onPressed: widget.onBack,
          style: PZButtonStyle.primary,
          width: double.infinity,
          icon: Icons.refresh_rounded,
        ),
      ],
    );
  }

  Widget _handle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: AppColors.textHint,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(50), width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 4),
            Text(value,
                style: GoogleFonts.nunito(
                    fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            Text(label,
                style: GoogleFonts.nunito(
                    fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  String _formatDur(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
