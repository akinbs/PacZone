import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_config.dart';
import '../controllers/location_controller.dart';
import '../core/app_state.dart';
import '../models/location_model.dart';
import '../models/scan_result_model.dart';
import '../models/zone_models.dart';
import '../services/api_scan_service.dart';
import '../services/mock_location_service.dart';
import '../services/mock_scan_service.dart';
import '../services/real_location_service.dart';
import '../services/scan_service.dart';
import '../services/osm_service.dart';
import '../services/zone_analyzer.dart';
import '../theme/app_colors.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/mapbox_map_view.dart';
import '../widgets/scan_bottom_sheet.dart';
import '../widgets/daily_route_sheet.dart';
import 'game_screen.dart';
import 'profile_screen.dart';

enum _MapState {
  ready,
  scanning,
  scanSuccess,
  scanPartial,
  scanFailed,
  gpsWeak,
  eventZone,
  speedTooHigh,
  noData,
}

class HomeMapScreen extends StatefulWidget {
  const HomeMapScreen({super.key});

  @override
  State<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends State<HomeMapScreen>
    with TickerProviderStateMixin {
  _MapState _state = _MapState.ready;
  ZoneAnalysisResult? _zoneResult;
  late AnimationController _scanAnimCtrl;
  late AnimationController _avatarPulseCtrl;
  late AnimationController _buttonPulseCtrl;
  late LocationController _locationCtrl;
  late ScanService _scanService;

  @override
  void initState() {
    super.initState();
    _scanAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _avatarPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _buttonPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _locationCtrl = LocationController(
      service: AppConfig.useRealLocation
          ? RealLocationService()
          : MockLocationService(),
    );
    _locationCtrl.addListener(_onLocationChanged);
    _locationCtrl.initialize();

    _scanService = AppConfig.useRealApi
        ? ApiScanService(baseUrl: AppConfig.apiBaseUrl)
        : MockScanService();
  }

  void _onLocationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _scanAnimCtrl.dispose();
    _avatarPulseCtrl.dispose();
    _buttonPulseCtrl.dispose();
    _locationCtrl.removeListener(_onLocationChanged);
    _locationCtrl.dispose();
    super.dispose();
  }

  void _onMainButtonPressed() {
    final ls = _locationCtrl.state;

    // Location permission/service issues — handle them first
    if (ls == LocationState.permissionDenied) {
      _locationCtrl.retry();
      return;
    }
    if (ls == LocationState.permissionDeniedForever) {
      _locationCtrl.openAppSettings();
      return;
    }
    if (ls == LocationState.serviceDisabled) {
      _locationCtrl.openLocationSettings();
      return;
    }
    if (_locationCtrl.isLoading) return;

    // Location OK — handle scan flow
    if (_state == _MapState.ready) {
      _startScan();
    } else if (_state == _MapState.scanSuccess ||
               _state == _MapState.scanPartial ||
               _state == _MapState.eventZone) {
      _startGame();
    } else {
      setState(() => _state = _MapState.ready);
    }
  }

  void _startScan() async {
    setState(() => _state = _MapState.scanning);

    // Build LocationInput from real GPS when available, fall back to mock
    final loc = _locationCtrl.location;
    final locationInput = loc != null
        ? LocationInput(
            lat: loc.latitude,
            lng: loc.longitude,
            accuracyMeters: loc.accuracy,
            speedKmh: loc.speedKmh,
            headingDegrees: loc.heading ?? 0,
            timestamp: loc.timestamp,
          )
        : LocationInput.mockGood();

    final result = await _scanService.analyze(locationInput);
    if (!mounted) return;

    _zoneResult = result;
    AppState.lastScanResult = result.scanResult;

    final newState = switch (result.scanResult.status) {
      ScanStatus.success      => result.scanResult.isEventZone
          ? _MapState.eventZone
          : _MapState.scanSuccess,
      ScanStatus.partial      => _MapState.scanPartial,
      ScanStatus.failed       => _MapState.scanFailed,
      ScanStatus.gpsWeak      => _MapState.gpsWeak,
      ScanStatus.speedTooHigh => _MapState.speedTooHigh,
      ScanStatus.noData       => _MapState.noData,
    };
    setState(() => _state = newState);
  }

  void _applyDebugResult(ZoneAnalysisResult result) {
    Navigator.of(context).pop();
    _zoneResult = result;
    AppState.lastScanResult = result.scanResult;
    final newState = switch (result.scanResult.status) {
      ScanStatus.success      => result.scanResult.isEventZone
          ? _MapState.eventZone
          : _MapState.scanSuccess,
      ScanStatus.partial      => _MapState.scanPartial,
      ScanStatus.failed       => _MapState.scanFailed,
      ScanStatus.gpsWeak      => _MapState.gpsWeak,
      ScanStatus.speedTooHigh => _MapState.speedTooHigh,
      ScanStatus.noData       => _MapState.noData,
    };
    setState(() => _state = newState);
  }

  void _showDebugPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _DebugScenarioSheet(onScenarioSelected: _applyDebugResult),
    );
  }

  void _startGame() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, a, __) => GameScreen(zoneResult: _zoneResult!),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(anim),
            child: child,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    ).then((_) => setState(() => _state = _MapState.ready));
  }

  bool get _showSheet =>
      _state == _MapState.scanning ||
      _state == _MapState.scanSuccess ||
      _state == _MapState.scanPartial ||
      _state == _MapState.scanFailed ||
      _state == _MapState.gpsWeak ||
      _state == _MapState.eventZone ||
      _state == _MapState.speedTooHigh ||
      _state == _MapState.noData;

  ScanSheetState get _sheetState => switch (_state) {
        _MapState.scanning     => ScanSheetState.scanning,
        _MapState.scanSuccess  => ScanSheetState.success,
        _MapState.scanPartial  => ScanSheetState.partial,
        _MapState.scanFailed   => ScanSheetState.failed,
        _MapState.gpsWeak      => ScanSheetState.gpsWeak,
        _MapState.speedTooHigh => ScanSheetState.speedTooHigh,
        _MapState.noData       => ScanSheetState.noData,
        // EventZone is a bonus on top of a standard dynamic PacZone — shows success sheet
        _MapState.eventZone    => ScanSheetState.success,
        _                      => ScanSheetState.scanning,
      };

  // Location state overrides scan state for button text
  String get _mainButtonText {
    switch (_locationCtrl.state) {
      case LocationState.initial:
      case LocationState.checkingPermission:
      case LocationState.permissionGranted:
      case LocationState.loadingLocation:
        return 'Konum Bekleniyor';
      case LocationState.permissionDenied:
        return 'Konum İzni Gerekli';
      case LocationState.permissionDeniedForever:
        return 'Ayarları Aç';
      case LocationState.serviceDisabled:
        return 'Konumu Aç';
      case LocationState.locationError:
        return 'Konum Alınamadı';
      default:
        break;
    }
    return switch (_state) {
      _MapState.ready        => 'PacZone Oluştur',
      _MapState.scanning     => 'Alan Taranıyor...',
      _MapState.scanSuccess  => 'Chomp Mode Başlat',
      _MapState.scanPartial  => 'Yine de Başlat',
      _MapState.scanFailed   => 'Başka Yerde Dene',
      _MapState.gpsWeak      => 'Konum Bekleniyor',
      _MapState.eventZone    => 'Chomp Mode Başlat',
      _MapState.speedTooHigh => 'Dur ve Tekrar Tara',
      _MapState.noData       => 'Tekrar Dene',
    };
  }

  Color get _mainButtonColor {
    final ls = _locationCtrl.state;
    if (ls == LocationState.permissionDenied ||
        ls == LocationState.permissionDeniedForever ||
        ls == LocationState.serviceDisabled ||
        ls == LocationState.locationError) {
      return AppColors.error;
    }
    if (_locationCtrl.isLoading) return AppColors.card;
    return switch (_state) {
      _MapState.scanSuccess  => AppColors.success,
      _MapState.scanPartial  => AppColors.warning,
      _MapState.scanFailed   => AppColors.error,
      _MapState.gpsWeak      => AppColors.warning,
      _MapState.eventZone    => AppColors.accent,
      _MapState.speedTooHigh => AppColors.error,
      _MapState.noData       => AppColors.error,
      _                      => AppColors.primary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final user = AppState.user;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Full-screen map — OSM (Carto Dark Matter) via flutter_map
          Positioned.fill(child: _buildMap()),

          // Avatar on map (center)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Scan radius hint (always visible)
                AnimatedBuilder(
                  animation: _avatarPulseCtrl,
                  builder: (_, __) => CustomPaint(
                    size: const Size(200, 200),
                    painter: _ScanRadiusPainter(
                      pulse: _avatarPulseCtrl.value,
                      active: _state == _MapState.scanning,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Avatar marker at center
          Center(
            child: Transform.translate(
              offset: const Offset(0, -8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AvatarWidget(
                    avatar: user.avatar,
                    size: 52,
                    showAura: true,
                  ),
                  // Location dot
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: user.avatar.primaryColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: user.avatar.primaryColor.withAlpha(100),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  // GPS accuracy / location status chip
                  const SizedBox(height: 8),
                  _buildLocationChip(),
                ],
              ),
            ),
          ),

          // Top bar
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(user),
                const Spacer(),

                // EventZone banner
                if (_state == _MapState.eventZone)
                  _buildEventZoneBanner(),

                // Sheet or bottom dock
                if (_showSheet)
                  _buildSheetArea()
                else
                  _buildFloatingDock(),

                SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return RealMapView(location: _locationCtrl.location);
  }

  Widget _buildLocationChip() {
    final ls = _locationCtrl.state;
    if (ls == LocationState.locationReady) {
      final loc = _locationCtrl.location;
      if (loc == null) return const SizedBox.shrink();
      return _locationTag(
        '±${loc.accuracy.round()} m',
        Icons.gps_fixed_rounded,
        AppColors.success,
      );
    }
    if (ls == LocationState.locationWeak) {
      return _locationTag('Konum zayıf', Icons.gps_not_fixed_rounded, AppColors.warning);
    }
    if (ls == LocationState.loadingLocation ||
        ls == LocationState.checkingPermission ||
        ls == LocationState.permissionGranted) {
      return _locationTag('Konum alınıyor', Icons.gps_not_fixed_rounded, AppColors.textHint);
    }
    if (ls == LocationState.permissionDenied ||
        ls == LocationState.permissionDeniedForever) {
      return _locationTag('İzin yok', Icons.location_off_rounded, AppColors.error);
    }
    if (ls == LocationState.serviceDisabled) {
      return _locationTag('GPS kapalı', Icons.location_disabled_rounded, AppColors.error);
    }
    return const SizedBox.shrink();
  }

  Widget _locationTag(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface.withAlpha(210),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(80), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 11),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.nunito(
                fontSize: 10, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(user) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          // Level badge — long press opens debug scenario panel
          GestureDetector(
            onLongPress: _showDebugPanel,
            child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface.withAlpha(220),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.card, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, color: AppColors.secondary, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Lv ${user.level}',
                  style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 50,
                  height: 6,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: user.xp / user.xpToNextLevel,
                      backgroundColor: AppColors.background,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ),

          const Spacer(),

          // Profile avatar button
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface.withAlpha(220),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.card, width: 1),
              ),
              child: AvatarWidget(
                avatar: AppState.user.avatar,
                size: 28,
                showAura: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventZoneBanner() {
    final result = _zoneResult?.scanResult;
    final eventName = result?.eventName ?? 'EventZone';
    final eventBonus = result?.eventBonus ?? 'Bonus Aktif';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.accent.withAlpha(200), AppColors.primary.withAlpha(180)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withAlpha(80),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bolt, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(eventName,
                style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontSize: 14)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(eventBonus,
                  style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w900,
                      color: AppColors.background,
                      fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetArea() {
    return ScanBottomSheet(
      sheetState: _sheetState,
      result: _zoneResult?.scanResult,
      onStartGame: _startGame,
      onBack: () => setState(() => _state = _MapState.ready),
    );
  }

  Widget _buildFloatingDock() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Daily button
          _dockSideButton(
            icon: Icons.bolt_rounded,
            label: 'Görevler',
            onTap: () => showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (_) => const DailyRouteSheet(),
            ),
          ),
          const SizedBox(width: 12),

          // Main button
          Expanded(child: _buildMainButton()),

          const SizedBox(width: 12),

          // Profile button
          _dockSideButton(
            icon: Icons.person_rounded,
            label: 'Profil',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dockSideButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface.withAlpha(230),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.card, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 22),
            const SizedBox(height: 2),
            Text(label,
                style: GoogleFonts.nunito(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHint)),
          ],
        ),
      ),
    );
  }

  bool get _buttonIsLoading =>
      _state == _MapState.scanning || _locationCtrl.isLoading;

  bool get _buttonUsesWhiteText {
    final ls = _locationCtrl.state;
    return ls == LocationState.permissionDenied ||
        ls == LocationState.permissionDeniedForever ||
        ls == LocationState.serviceDisabled ||
        ls == LocationState.locationError ||
        _state == _MapState.scanFailed ||
        _state == _MapState.gpsWeak ||
        _state == _MapState.speedTooHigh ||
        _state == _MapState.noData;
  }

  Widget _buildMainButton() {
    final isLoading = _buttonIsLoading;
    return AnimatedBuilder(
      animation: _buttonPulseCtrl,
      builder: (_, __) {
        final pulse = _buttonPulseCtrl.value;
        return GestureDetector(
          onTap: isLoading ? null : _onMainButtonPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: isLoading ? AppColors.card : _mainButtonColor,
              borderRadius: BorderRadius.circular(22),
              boxShadow: isLoading
                  ? null
                  : [
                      BoxShadow(
                        color: _mainButtonColor.withAlpha(
                            (80 + 60 * pulse).round()),
                        blurRadius: 18 + 8 * pulse,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Center(
              child: isLoading
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(AppColors.textSecondary),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(_mainButtonText,
                            style: GoogleFonts.nunito(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textSecondary)),
                      ],
                    )
                  : Text(
                      _mainButtonText,
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: _buttonUsesWhiteText
                            ? Colors.white
                            : AppColors.background,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Debug Scenario Panel ─────────────────────────────────────────────────────

class _DebugScenarioSheet extends StatefulWidget {
  final void Function(ZoneAnalysisResult) onScenarioSelected;

  const _DebugScenarioSheet({required this.onScenarioSelected});

  @override
  State<_DebugScenarioSheet> createState() => _DebugScenarioSheetState();
}

class _DebugScenarioSheetState extends State<_DebugScenarioSheet> {
  static const _scenarios = [
    (index: 0, label: 'Park (Success)',   icon: Icons.park_rounded,           color: AppColors.success),
    (index: 1, label: 'Campus (Success)', icon: Icons.school_rounded,          color: AppColors.success),
    (index: 2, label: 'Short (Partial)',  icon: Icons.route_rounded,           color: AppColors.warning),
    (index: 3, label: 'Failed',           icon: Icons.block_rounded,           color: AppColors.error),
    (index: 4, label: 'EventZone',        icon: Icons.bolt_rounded,            color: AppColors.secondary),
    (index: 5, label: 'Speed Too High',   icon: Icons.speed_rounded,           color: AppColors.error),
    (index: 6, label: 'No Data',          icon: Icons.signal_wifi_off_rounded, color: AppColors.error),
  ];

  bool _testingOsm = false;
  String? _osmResult;

  Future<void> _runOsmTest() async {
    setState(() { _testingOsm = true; _osmResult = null; });
    try {
      final osm = await OsmService.fetchWays(41.0082, 28.9784, radiusMeters: 250);
      if (!mounted) return;
      setState(() {
        _osmResult = osm.isEmpty
            ? 'FAIL — 0 ways returned (check logs)'
            : 'OK — ${osm.ways.length} ways fetched';
        _testingOsm = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _osmResult = 'ERROR: $e'; _testingOsm = false; });
    }
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
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.textHint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.bug_report_rounded, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Debug Scenarios',
                  style: GoogleFonts.nunito(
                    fontSize: 15, fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // OSM connectivity test button
            GestureDetector(
              onTap: _testingOsm ? null : _runOsmTest,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withAlpha(60), width: 1),
                ),
                child: Row(
                  children: [
                    _testingOsm
                        ? const SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(AppColors.primary)))
                        : const Icon(Icons.wifi_tethering_rounded,
                            color: AppColors.primary, size: 14),
                    const SizedBox(width: 8),
                    Text(
                      _testingOsm ? 'Testing Overpass API...' : 'Test OSM / Overpass API',
                      style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700,
                        color: AppColors.primary),
                    ),
                    if (_osmResult != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_osmResult!,
                          style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w600,
                            color: _osmResult!.startsWith('OK')
                                ? AppColors.success : AppColors.error),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 3.2,
              children: _scenarios.map((s) {
                return GestureDetector(
                  onTap: () => widget.onScenarioSelected(ZoneAnalyzer.resultForScenario(s.index)),
                  child: Container(
                    decoration: BoxDecoration(
                      color: s.color.withAlpha(18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: s.color.withAlpha(60), width: 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(s.icon, color: s.color, size: 15),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            s.label,
                            style: GoogleFonts.nunito(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// Draws a square scan boundary representing the 150 m × 150 m PacZone area.
class _ScanRadiusPainter extends CustomPainter {
  final double pulse;
  final bool active;
  const _ScanRadiusPainter({required this.pulse, required this.active});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    if (active) {
      // Active scan — animated square rings expanding outward
      for (int i = 0; i < 3; i++) {
        final half = 56.0 + i * 22.0 + pulse * 14;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: center, width: half * 2, height: half * 2),
            const Radius.circular(10),
          ),
          Paint()
            ..color = AppColors.primary.withAlpha((42 - i * 13).clamp(0, 80))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    } else {
      // Idle — soft-pulsing square boundary (the 150 m × 150 m scan area)
      final half = 56.0 + pulse * 8;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: half * 2, height: half * 2),
          const Radius.circular(10),
        ),
        Paint()
          ..color = AppColors.primary.withAlpha((18 + (pulse * 14).round()))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(_ScanRadiusPainter old) =>
      old.pulse != pulse || old.active != active;
}
