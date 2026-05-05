import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../core/app_state.dart';
import '../models/game_models.dart';
import '../models/result_model.dart';
import '../models/zone_models.dart';
import '../services/game_session_service.dart';
import '../services/osm_service.dart';
import '../services/zone_analyzer.dart';
import '../theme/app_colors.dart';
import '../widgets/chomp_widget.dart';
import '../widgets/pause_sheet.dart';
import 'result_screen.dart';

class GameScreen extends StatefulWidget {
  final ZoneAnalysisResult zoneResult;
  const GameScreen({super.key, required this.zoneResult});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late AnimationController _enemyCtrl;
  late AnimationController _countdownCtrl;
  late MapController _mapController;

  int _countdown = 3;
  bool _counting = true;
  bool _playing = false;
  bool _paused = false;
  bool _gameOver = false;       // any terminal state (prevents double-trigger)
  bool _caughtByGhost = false;  // specifically killed — shows red overlay

  late Duration _timeLeft;
  Timer? _gameTimer;

  int _score = 0;
  int _combo = 0;
  String? _floatText;
  Timer? _floatTimer;
  Timer? _enemyTimer;

  PowerUpState _powerUp = PowerUpState.inactive;

  late List<CoinModel> _coins;
  late List<_EnemyState> _enemies;
  late _NavGraph _navGraph;

  late GameSessionService _session;

  final _rng = math.Random();

  DynamicZoneData? get _zone => widget.zoneResult.zoneData;

  double get _centerLat => _zone?.centerLat ?? 41.0082;
  double get _centerLng => _zone?.centerLng ?? 28.9784;

  @override
  void initState() {
    super.initState();

    _mapController = MapController();

    _timeLeft = _zone != null
        ? _zone!.estimatedDuration
        : const Duration(minutes: 2, seconds: 30);

    _session = _zone != null
        ? GameSessionService.fromZone(_zone!)
        : GameSessionService(
            sessionId: 'sess_${DateTime.now().millisecondsSinceEpoch}',
            zoneId: 'fallback',
            maxDuration: _timeLeft,
          );

    _enemyCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    );

    _countdownCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _initCoins();
    _initEnemies();
    _startCountdown();
  }

  void _initCoins() {
    _coins = _zone != null ? List.from(_zone!.coins) : _buildFallbackCoins();
  }

  void _initEnemies() {
    final rawSegs = _zone != null
        ? _zone!.paths.map((p) => p.points).where((s) => s.length >= 2).toList()
        : _fallbackMazeSegs();

    _navGraph = _NavGraph.build(rawSegs);

    final nodeCount = _navGraph.nodes.length;
    if (nodeCount < 2) { _enemies = []; return; }

    final colors     = [AppColors.ghost1, AppColors.ghost2, AppColors.ghost3];
    final zoneEnemies = _zone?.enemies ?? [];
    final count      = zoneEnemies.isNotEmpty ? zoneEnemies.length : 2;

    _enemies = List.generate(math.min(count, 3), (i) {
      // Spread ghosts evenly: each starts at a different part of the graph
      final nodeIdx = ((i * nodeCount) ~/ math.max(count, 1)) % nodeCount;
      final neighbors = _navGraph.adj[nodeIdx];
      final nextIdx = neighbors.isNotEmpty
          ? neighbors[_rng.nextInt(neighbors.length)]
          : (nodeIdx + 1) % nodeCount;

      final speedFactor = i < zoneEnemies.length
          ? zoneEnemies[i].speedFactor
          : 0.85 + i * 0.12;
      final color = i < zoneEnemies.length
          ? zoneEnemies[i].color
          : colors[i % colors.length];

      return _EnemyState(
        id: 'ghost_$i',
        color: color,
        speedFactor: speedFactor,
        nodeIdx: nodeIdx,
        nextIdx: nextIdx,
        prevIdx: nodeIdx,
        progress: _rng.nextDouble() * 0.4,
        position: _navGraph.nodes[nodeIdx],
        aiMode: i == 0 ? _GhostAiMode.chase : _GhostAiMode.patrol,
        aiModeTimer: 80 + i * 40,
      );
    });
  }

  // 3×3 grid: every junction is at a segment endpoint → no T-junction problem.
  // Each "cell wall" is split at intersections so the graph connects them all.
  List<List<Offset>> _fallbackMazeSegs() => [
    // Horizontal — top row (left half / right half)
    [const Offset(-80,-70), const Offset(0,-70)],
    [const Offset(0,-70),   const Offset(80,-70)],
    // Horizontal — middle row
    [const Offset(-80,0),   const Offset(0,0)],
    [const Offset(0,0),     const Offset(80,0)],
    // Horizontal — bottom row
    [const Offset(-80,70),  const Offset(0,70)],
    [const Offset(0,70),    const Offset(80,70)],
    // Vertical — left column (top half / bottom half)
    [const Offset(-80,-70), const Offset(-80,0)],
    [const Offset(-80,0),   const Offset(-80,70)],
    // Vertical — center column
    [const Offset(0,-70),   const Offset(0,0)],
    [const Offset(0,0),     const Offset(0,70)],
    // Vertical — right column
    [const Offset(80,-70),  const Offset(80,0)],
    [const Offset(80,0),    const Offset(80,70)],
  ];

  void _startCountdown() async {
    for (int i = 3; i >= 1; i--) {
      setState(() => _countdown = i);
      await _countdownCtrl.forward(from: 0.0);
      await Future.delayed(const Duration(milliseconds: 200));
    }
    if (!mounted) return;
    setState(() {
      _counting = false;
      _playing = true;
    });
    _startGameTimer();
    _startEnemyTimer();
  }

  void _startGameTimer() {
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _paused || _gameOver) return;
      setState(() {
        if (_timeLeft.inSeconds <= 0) {
          t.cancel();
          _endGame();
          return;
        }
        _timeLeft -= const Duration(seconds: 1);

        if (_powerUp.active) {
          _powerUp = _powerUp.tick();
        }

        _session.recordSpeedSample(_rng.nextDouble() * 5 + 2);

        // Simulate player walking toward nearest coin every 2 seconds
        if (_timeLeft.inSeconds % 2 == 0) {
          _autoCollectCoin();
        }
      });
    });
  }

  // ── Coin collection ──────────────────────────────────────────────────────────

  void _autoCollectCoin() {
    final uncollected = _coins.where((c) => !c.collected).toList();
    if (uncollected.isEmpty) return;
    // Collect the nearest coin to simulate GPS-based walking toward it
    uncollected.sort((a, b) => a.position.distance.compareTo(b.position.distance));
    _collectCoin(uncollected.first);
  }

  void _collectCoin(CoinModel coin) {
    if (coin.collected) return;
    coin.collected = true;

    final isPower = coin.type == CoinType.power;
    _combo++;

    final multiplier = _combo >= 8 ? 3 : _combo >= 4 ? 2 : 1;
    final earned = coin.points * multiplier;
    _score += earned;

    _session.recordCoinCollected(coin.id, earned);

    if (isPower) {
      _powerUp = _powerUp.activate();
      _floatText = '⚡ POWER UP! +${coin.points}';
    } else if (_combo >= 8) {
      _floatText = '×3 COMBO! +$earned';
    } else if (_combo >= 4) {
      _floatText = '×2 COMBO! +$earned';
    } else {
      _floatText = '+$earned';
    }

    _floatTimer?.cancel();
    _floatTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _floatText = null);
    });

    // Check win condition after every collection
    if (_coins.every((c) => c.collected)) {
      _checkWinCondition();
    }
  }

  void _checkWinCondition() {
    if (_gameOver || !_playing) return;
    _gameOver = true;
    _gameTimer?.cancel();
    _enemyTimer?.cancel();
    final bonus = _timeLeft.inSeconds * 10;
    _score += bonus;
    // Keep _playing=true so the HUD float text stays visible
    setState(() => _floatText = 'MAZE CLEAR! +$bonus');
    _floatTimer?.cancel();
    Future.delayed(const Duration(milliseconds: 1500), _endGame);
  }

  // ── Ghost AI — node-based maze navigation ────────────────────────────────────
  //
  // Each ghost is always on the edge between two adjacent graph nodes.
  // Position = lerp(nodes[nodeIdx], nodes[nextIdx], progress).
  // Teleportation is impossible: every move step stays on a valid graph edge.

  // Game-pixel distance covered per 50 ms tick at speedFactor = 1.0
  static const double _ghostPxPerTick = 0.22;

  void _moveEnemies() {
    if (_enemies.isEmpty || _gameOver || !_playing) return;
    for (int i = 0; i < _enemies.length; i++) {
      _enemies[i].aiModeTimer--;
      if (_enemies[i].aiModeTimer <= 0) _switchAiMode(i);
      _moveGhost(i);
    }
    _checkCollisions();
  }

  void _switchAiMode(int i) {
    final chaseProb = i == 0 ? 0.70 : i == 1 ? 0.55 : 0.40;
    if (_rng.nextDouble() < chaseProb) {
      _enemies[i].aiMode = _GhostAiMode.chase;
      _enemies[i].aiModeTimer = 90 + _rng.nextInt(90);
    } else {
      _enemies[i].aiMode = _GhostAiMode.patrol;
      _enemies[i].aiModeTimer = 70 + _rng.nextInt(70);
    }
  }

  void _moveGhost(int i) {
    final e = _enemies[i];
    e.prevPosition = e.position;

    final from   = _navGraph.nodes[e.nodeIdx];
    final to     = _navGraph.nodes[e.nextIdx];
    final edgeLen = (to - from).distance;

    // Advance progress by a fixed pixel amount → constant real-world speed
    final step = edgeLen > 0.5
        ? (_ghostPxPerTick * e.speedFactor) / edgeLen
        : 1.0; // skip zero-length edges instantly

    e.progress += step;

    if (e.progress >= 1.0) {
      // Arrived at nextIdx — snap to node, then choose next direction
      e.prevIdx  = e.nodeIdx;
      e.nodeIdx  = e.nextIdx;
      e.position = _navGraph.nodes[e.nodeIdx];
      e.progress = 0.0;
      _chooseNext(i);
    } else {
      e.position = Offset.lerp(from, to, e.progress)!;
    }
  }

  void _chooseNext(int i) {
    final e = _enemies[i];
    // All neighbors except where we came from (no immediate backtrack)
    final all      = _navGraph.adj[e.nodeIdx];
    final forward  = all.where((n) => n != e.prevIdx).toList();
    final options  = forward.isNotEmpty ? forward : all;

    if (options.isEmpty) return; // isolated node — shouldn't happen

    if (_powerUp.active) {
      // Frightened: flee to the neighbour farthest from player
      e.nextIdx = options.reduce((a, b) =>
          _navGraph.nodes[a].distance > _navGraph.nodes[b].distance ? a : b);
    } else if (e.aiMode == _GhostAiMode.chase) {
      // Chase: greedy step toward the neighbour closest to player
      e.nextIdx = options.reduce((a, b) =>
          _navGraph.nodes[a].distance < _navGraph.nodes[b].distance ? a : b);
    } else {
      // Patrol: random walk — ghosts explore the entire maze over time
      e.nextIdx = options[_rng.nextInt(options.length)];
    }
  }

  // ── Collision detection ──────────────────────────────────────────────────────

  void _checkCollisions() {
    if (!_playing || _paused || _gameOver) return;

    // Ghost must be:
    //   1. Within hitRadius of the player (Offset.zero = map centre)
    //   2. On an edge that actually passes through the player's corridor
    //      (prevents ghosts on parallel side-streets from killing the player)
    //   3. Approaching the player (distance decreasing) OR within killRadius
    const double hitRadius    = 9.0;
    const double killRadius   = 4.0;
    const double corridorDist = 11.0;

    for (int i = _enemies.length - 1; i >= 0; i--) {
      final e    = _enemies[i];
      final dist = e.position.distance;
      if (dist >= hitRadius) continue;

      // Is the ghost's current edge on the same path corridor as the player?
      final from = _navGraph.nodes[e.nodeIdx];
      final to   = _navGraph.nodes[e.nextIdx];
      if (_distPointToSeg(Offset.zero, from, to) > corridorDist) continue;

      // Require approach direction unless extremely close
      final approaching = dist < e.prevPosition.distance;
      if (dist >= killRadius && !approaching) continue;

      if (_powerUp.active) {
        setState(() {
          _enemies.removeAt(i);
          _score += 200;
          _combo++;
          _floatText = '+200 GHOST!';
        });
        _floatTimer?.cancel();
        _floatTimer = Timer(const Duration(milliseconds: 1400), () {
          if (mounted) setState(() => _floatText = null);
        });
      } else {
        _triggerGameOver();
        return;
      }
    }
  }

  /// Minimum distance from point [p] to the finite line segment [a]→[b].
  double _distPointToSeg(Offset p, Offset a, Offset b) {
    final ab  = b - a;
    final abSq = ab.distanceSquared;
    if (abSq == 0) return (p - a).distance;
    final t = ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / abSq;
    final cx = a.dx + t.clamp(0.0, 1.0) * ab.dx;
    final cy = a.dy + t.clamp(0.0, 1.0) * ab.dy;
    return math.sqrt((p.dx - cx) * (p.dx - cx) + (p.dy - cy) * (p.dy - cy));
  }

  void _triggerGameOver() {
    if (_gameOver) return;
    _gameOver = true;
    _caughtByGhost = true;
    _gameTimer?.cancel();
    _enemyTimer?.cancel();
    setState(() => _playing = false);
    Future.delayed(const Duration(milliseconds: 1300), _endGame);
  }

  void _startEnemyTimer() {
    _enemyTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted || _paused) return;
      setState(_moveEnemies);
    });
  }

  void _endGame() {
    _gameTimer?.cancel();
    _enemyTimer?.cancel();
    _enemyCtrl.stop();

    final validation = _session.validate();

    final result = ResultModel(
      finalScore: validation.finalScore > 0 ? validation.finalScore : _score,
      coinsCollected: _session.coinsCollected,
      distanceWalkedMeters: validation.distanceMeters,
      duration: DateTime.now().difference(_session.startTime),
      maxCombo: _combo,
      previousBestScore: AppState.user.bestScore,
      rank: _rng.nextInt(14) + 3,
      xpEarned: ((_session.coinsCollected * 4) + (_score ~/ 50)).clamp(0, 999),
      isNewRecord: (_score > AppState.user.bestScore),
    );

    AppState.saveResult(result);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, a, __) => ResultScreen(result: result),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  void _togglePause() {
    if (_paused) {
      setState(() => _paused = false);
    } else {
      setState(() => _paused = true);
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isDismissible: false,
        builder: (_) => PauseSheet(
          onResume: () {
            Navigator.of(context).pop();
            setState(() => _paused = false);
          },
          onQuit: () {
            Navigator.of(context).pop();
            Navigator.of(context).pop();
          },
        ),
      );
    }
  }

  String _formatTime(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  LatLng _toLatLng(Offset offset) => OsmService.offsetToLatLng(
        offset, _centerLat, _centerLng, ZoneAnalyzer.pixelsPerMeter);

  List<LatLng> _zoneWallCorners() {
    const halfM = 100.0;
    const metersPerDegLat = 111320.0;
    const dLat = halfM / metersPerDegLat;
    final dLng = halfM /
        (metersPerDegLat * math.cos(_centerLat * math.pi / 180));
    final nw = LatLng(_centerLat + dLat, _centerLng - dLng);
    final ne = LatLng(_centerLat + dLat, _centerLng + dLng);
    final se = LatLng(_centerLat - dLat, _centerLng + dLng);
    final sw = LatLng(_centerLat - dLat, _centerLng - dLng);
    return [nw, ne, se, sw, nw];
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _floatTimer?.cancel();
    _enemyTimer?.cancel();
    _enemyCtrl.dispose();
    _countdownCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final avatar = AppState.user.avatar;
    final activeCoins = _coins.where((c) => !c.collected).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Real map with zone overlays ──────────────────────────────────
          Positioned.fill(child: _buildGameMap(activeCoins)),

          // ── Blur outside game square ─────────────────────────────────────
          Positioned.fill(
            child: LayoutBuilder(
              builder: (_, box) => _buildBlurOverlay(
                Size(box.maxWidth, box.maxHeight),
              ),
            ),
          ),

          // ── Chomp character pinned to screen center ──────────────────────
          if ((_playing || _paused) && !_gameOver)
            Center(
              child: ChompWidget(
                bodyColor: _powerUp.active
                    ? AppColors.secondary
                    : avatar.primaryColor,
                auraColor: _powerUp.active
                    ? AppColors.secondary.withAlpha(180)
                    : avatar.auraColor,
                size: 58,
                animated: _playing && !_paused,
              ),
            ),

          // ── Countdown overlay ────────────────────────────────────────────
          if (_counting)
            Container(
              color: Colors.black.withAlpha(130),
              child: Center(
                child: ScaleTransition(
                  scale: Tween<double>(begin: 1.4, end: 0.8)
                      .chain(CurveTween(curve: Curves.easeIn))
                      .animate(_countdownCtrl),
                  child: Text(
                    '$_countdown',
                    style: GoogleFonts.nunito(
                      fontSize: 120,
                      fontWeight: FontWeight.w900,
                      color: avatar.primaryColor,
                      shadows: [
                        Shadow(
                          color: avatar.primaryColor.withAlpha(150),
                          blurRadius: 40,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── HUD ──────────────────────────────────────────────────────────
          if ((_playing || _paused) && !_gameOver)
            SafeArea(
              child: Stack(
                children: [
                  Positioned(
                    top: 12, left: 16,
                    child: _hudChip(Icons.circle, _score.toString(), AppColors.secondary),
                  ),
                  Positioned(
                    top: 12, right: 16,
                    child: _hudChip(
                      Icons.timer_rounded,
                      _formatTime(_timeLeft),
                      _timeLeft.inSeconds < 30 ? AppColors.error : AppColors.primary,
                    ),
                  ),
                  Positioned(
                    bottom: 20, left: 16,
                    child: _hudChip(Icons.circle, '×${_session.coinsCollected}', AppColors.coin),
                  ),
                  if (_powerUp.active)
                    Positioned(
                      top: 64, left: 0, right: 0,
                      child: Center(child: _buildPowerUpBar()),
                    ),
                  Positioned(
                    bottom: 16, right: 16,
                    child: GestureDetector(
                      onTap: _togglePause,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withAlpha(220),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.card, width: 1),
                        ),
                        child: const Icon(Icons.pause_rounded,
                            color: AppColors.textSecondary, size: 22),
                      ),
                    ),
                  ),
                  if (_zone != null)
                    Positioned(
                      top: 12, left: 0, right: 0,
                      child: Center(child: _buildDifficultyBadge()),
                    ),
                  if (_zone != null)
                    Positioned(
                      bottom: 20, right: 60,
                      child: _buildDataSourceBadge(),
                    ),
                  if (_floatText != null)
                    Positioned(
                      top: size.height * 0.34, left: 0, right: 0,
                      child: Center(
                        child: Text(
                          _floatText!,
                          style: GoogleFonts.nunito(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: _powerUp.active
                                ? AppColors.secondary
                                : AppColors.textPrimary,
                            shadows: [
                              Shadow(
                                color: (_powerUp.active
                                        ? AppColors.secondary
                                        : AppColors.primary)
                                    .withAlpha(160),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // ── EventZone banner ─────────────────────────────────────────────
          if (widget.zoneResult.scanResult.isEventZone && _playing && !_gameOver)
            Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(
                bottom: false,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(70, 12, 70, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withAlpha(210),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bolt, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.zoneResult.scanResult.eventName ?? ''} · '
                        '${widget.zoneResult.scanResult.eventBonus ?? ''}',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Game Over overlay (only for ghost collision) ─────────────────
          if (_caughtByGhost && !_counting)
            Container(
              color: AppColors.error.withAlpha(140),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'GAME OVER',
                      style: GoogleFonts.nunito(
                        fontSize: 56,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2,
                        shadows: [
                          const Shadow(
                            color: AppColors.error,
                            blurRadius: 32,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'CAUGHT BY A GHOST!',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Blur overlay outside the game square ──────────────────────────────────

  Widget _buildBlurOverlay(Size screenSize) {
    const halfM = 100.0;
    const tileSize = 256.0;
    const zoomLevel = 18.0;
    final metersPerPx =
        (2 * math.pi * 6378137.0 * math.cos(_centerLat * math.pi / 180)) /
            (math.pow(2, zoomLevel) * tileSize);
    final halfPx = halfM / metersPerPx;
    final cx = screenSize.width / 2;
    final cy = screenSize.height / 2;

    // Keep at least 16 px margin from screen edges horizontally
    final maxHalfWidth = screenSize.width / 2 - 16.0;
    final squareHalfW = math.min(halfPx, maxHalfWidth);

    final squareRect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: squareHalfW * 2,
      height: halfPx * 2,
    );
    return ClipPath(
      clipper: _OutsideSquareClipper(squareRect),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(color: AppColors.background.withAlpha(130)),
      ),
    );
  }

  // ── Real map with zone overlays ────────────────────────────────────────────

  Widget _buildGameMap(List<CoinModel> activeCoins) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: LatLng(_centerLat, _centerLng),
        initialZoom: 18.0,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.example.paczone',
          retinaMode: RetinaMode.isHighDensity(context),
        ),

        if (_zone != null) ...[
          // Zone boundary walls
          PolylineLayer(
            polylines: [
              Polyline(
                points: _zoneWallCorners(),
                color: AppColors.primary.withAlpha(38),
                strokeWidth: 18.0,
              ),
              Polyline(
                points: _zoneWallCorners(),
                color: AppColors.accent.withAlpha(210),
                strokeWidth: 7.0,
              ),
              Polyline(
                points: _zoneWallCorners(),
                color: AppColors.primary.withAlpha(240),
                strokeWidth: 2.0,
              ),
            ],
          ),

          // Path shimmer — outer glow ring (soft, narrow to keep map visible)
          PolylineLayer(
            polylines: _zone!.paths.map((seg) {
              final pts = seg.geoPoints ?? seg.points.map(_toLatLng).toList();
              return Polyline(
                points: pts,
                color: Colors.white.withAlpha(10),
                strokeWidth: 7.0,
              );
            }).toList(),
          ),

          // Path shimmer — mid glow
          PolylineLayer(
            polylines: _zone!.paths.map((seg) {
              final pts = seg.geoPoints ?? seg.points.map(_toLatLng).toList();
              return Polyline(
                points: pts,
                color: Colors.white.withAlpha(28),
                strokeWidth: 3.0,
              );
            }).toList(),
          ),

          // Path shimmer — bright core
          PolylineLayer(
            polylines: _zone!.paths.map((seg) {
              final pts = seg.geoPoints ?? seg.points.map(_toLatLng).toList();
              return Polyline(
                points: pts,
                color: Colors.white.withAlpha(90),
                strokeWidth: 1.2,
              );
            }).toList(),
          ),

          // Coins on walkable paths — uniform small size; power coins differ by color only
          CircleLayer(
            circles: activeCoins.map((coin) {
              final isPower = coin.type == CoinType.power;
              return CircleMarker(
                point: _toLatLng(coin.position),
                radius: 2.5,
                useRadiusInMeter: true,
                color: isPower
                    ? AppColors.secondary.withAlpha(230)
                    : AppColors.coin.withAlpha(220),
                borderColor: isPower ? AppColors.secondary : AppColors.coinGlow,
                borderStrokeWidth: isPower ? 2.0 : 1.0,
              );
            }).toList(),
          ),

          // Enemy ghost markers
          MarkerLayer(
            markers: _enemies.map((e) => Marker(
                  point: _toLatLng(e.position),
                  width: 32,
                  height: 32,
                  child: _GhostMarker(
                    color: e.color,
                    frightened: _powerUp.active,
                  ),
                )).toList(),
          ),
        ],
      ],
    );
  }

  // ── HUD widgets ────────────────────────────────────────────────────────────

  Widget _hudChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withAlpha(220),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.card, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 5),
          Text(text,
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              )),
        ],
      ),
    );
  }

  Widget _buildPowerUpBar() {
    return Container(
      width: 180,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface.withAlpha(230),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.secondary.withAlpha(120), width: 1),
        boxShadow: [
          BoxShadow(color: AppColors.secondary.withAlpha(50), blurRadius: 12),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bolt_rounded, color: AppColors.secondary, size: 14),
              const SizedBox(width: 4),
              Text(
                'POWER ACTIVE · ${_powerUp.remainingSeconds}s',
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: _powerUp.progress,
              backgroundColor: AppColors.card,
              valueColor: const AlwaysStoppedAnimation(AppColors.secondary),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultyBadge() {
    if (_zone == null) return const SizedBox.shrink();
    final label = switch (_zone!.difficulty) {
      DifficultyLevel.easy   => 'EASY',
      DifficultyLevel.normal => 'NORMAL',
      DifficultyLevel.hard   => 'HARD',
    };
    final color = switch (_zone!.difficulty) {
      DifficultyLevel.easy   => AppColors.success,
      DifficultyLevel.normal => AppColors.primary,
      DifficultyLevel.hard   => AppColors.error,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(80), width: 1),
      ),
      child: Text(
        '${_zone!.modeType} · $label',
        style: GoogleFonts.nunito(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDataSourceBadge() {
    if (_zone == null) return const SizedBox.shrink();
    final isOsm = _zone!.modeType == 'Street Run';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (isOsm ? AppColors.success : AppColors.warning).withAlpha(30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (isOsm ? AppColors.success : AppColors.warning).withAlpha(80),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOsm ? Icons.map_rounded : Icons.auto_fix_high_rounded,
            color: isOsm ? AppColors.success : AppColors.warning,
            size: 10,
          ),
          const SizedBox(width: 4),
          Text(
            isOsm ? 'OSM Streets' : 'Simulated',
            style: GoogleFonts.nunito(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: isOsm ? AppColors.success : AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }

  // ── Fallbacks when no zone data ────────────────────────────────────────────

  List<CoinModel> _buildFallbackCoins() {
    final offsets = [
      const Offset(-70, -62), const Offset(-40, -62), const Offset(20, -62),
      const Offset(50, -62), const Offset(-70, -30), const Offset(70, -30),
      const Offset(-40, 0), const Offset(0, 0), const Offset(40, 0),
      const Offset(-70, 30), const Offset(70, 30),
      const Offset(-50, 62), const Offset(10, 62), const Offset(40, 62),
    ];
    return List.generate(offsets.length, (i) => CoinModel(
          id: 'fallback_$i',
          position: offsets[i],
          type: i >= offsets.length - 2 ? CoinType.power : CoinType.normal,
          points: i >= offsets.length - 2 ? 500 : 100,
        ));
  }

}

// ── Ghost AI modes ─────────────────────────────────────────────────────────────

enum _GhostAiMode { patrol, chase }

// ── Internal mutable enemy state ───────────────────────────────────────────────

class _EnemyState {
  final String id;
  final Color  color;
  final double speedFactor;

  int    nodeIdx;   // node the ghost just left (or is currently at)
  int    nextIdx;   // node the ghost is heading toward
  int    prevIdx;   // node before nodeIdx (for no-backtrack logic)
  double progress;  // 0.0 = at nodeIdx, 1.0 = at nextIdx
  Offset position;
  Offset prevPosition;
  _GhostAiMode aiMode;
  int          aiModeTimer;

  _EnemyState({
    required this.id,
    required this.color,
    required this.speedFactor,
    required this.nodeIdx,
    required this.nextIdx,
    required this.prevIdx,
    required this.progress,
    required this.position,
    this.aiMode      = _GhostAiMode.chase,
    this.aiModeTimer = 120,
  }) : prevPosition = position;
}

// ── Nav graph (node-based) ────────────────────────────────────────────────────
//
// Builds a graph where every unique path point is a node and edges connect
// adjacent points within a segment. Nearby points (< mergeThreshold) are
// merged into a single node so OSM segments that share a junction are
// automatically connected without false cross-street links.
//
// Ghost movement: always between two adjacent nodes → no teleportation.

class _NavGraph {
  final List<Offset>     nodes; // unique positions
  final List<List<int>>  adj;   // adj[nodeIdx] = list of neighbour node indices

  _NavGraph._(this.nodes, this.adj);

  static _NavGraph build(List<List<Offset>> segs,
      {double mergeThreshold = 4.0}) {
    final nodes   = <Offset>[];
    final adjSets = <int, Set<int>>{};

    int findOrAdd(Offset pt) {
      for (int j = 0; j < nodes.length; j++) {
        if ((nodes[j] - pt).distance < mergeThreshold) return j;
      }
      nodes.add(pt);
      return nodes.length - 1;
    }

    for (final seg in segs) {
      if (seg.length < 2) continue;
      final idx = seg.map(findOrAdd).toList();
      for (int i = 0; i < idx.length - 1; i++) {
        final a = idx[i], b = idx[i + 1];
        if (a == b) continue; // duplicate point
        adjSets.putIfAbsent(a, () => {}).add(b);
        adjSets.putIfAbsent(b, () => {}).add(a);
      }
    }

    final adj = List.generate(
        nodes.length, (i) => adjSets[i]?.toList() ?? <int>[]);
    return _NavGraph._(nodes, adj);
  }
}

// ── Ghost marker (Pac-Man style ghost shape) ───────────────────────────────────

class _GhostMarker extends StatelessWidget {
  final Color color;
  final bool frightened;
  const _GhostMarker({required this.color, this.frightened = false});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(32, 32),
      painter: _GhostPainter(
        color: frightened ? const Color(0xFF1565C0) : color,
      ),
    );
  }
}

class _GhostPainter extends CustomPainter {
  final Color color;
  _GhostPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final glowPaint = Paint()
      ..color = color.withAlpha(110)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    final bodyPaint = Paint()..color = color;

    final path = ui.Path();
    path.moveTo(w * 0.08, h);
    path.lineTo(w * 0.08, h * 0.44);
    path.quadraticBezierTo(w * 0.08, h * 0.04, w * 0.50, h * 0.04);
    path.quadraticBezierTo(w * 0.92, h * 0.04, w * 0.92, h * 0.44);
    path.lineTo(w * 0.92, h);
    path.cubicTo(w * 0.92, h * 0.82, w * 0.82, h * 0.72, w * 0.75, h * 0.82);
    path.cubicTo(w * 0.68, h * 0.93, w * 0.57, h * 0.93, w * 0.50, h * 0.82);
    path.cubicTo(w * 0.43, h * 0.71, w * 0.32, h * 0.71, w * 0.25, h * 0.82);
    path.cubicTo(w * 0.18, h * 0.93, w * 0.08, h * 0.93, w * 0.08, h);
    path.close();

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, bodyPaint);

    final whitePaint = Paint()..color = Colors.white;
    final pupilPaint = Paint()..color = const Color(0xFF0D47A1);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.32, h * 0.36), width: w * 0.22, height: h * 0.20),
      whitePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.35, h * 0.38), width: w * 0.10, height: h * 0.12),
      pupilPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.68, h * 0.36), width: w * 0.22, height: h * 0.20),
      whitePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.71, h * 0.38), width: w * 0.10, height: h * 0.12),
      pupilPaint,
    );
  }

  @override
  bool shouldRepaint(_GhostPainter old) => old.color != color;
}

// ── Clip path that covers everything OUTSIDE the game square ───────────────────

class _OutsideSquareClipper extends CustomClipper<ui.Path> {
  final Rect squareRect;
  const _OutsideSquareClipper(this.squareRect);

  @override
  ui.Path getClip(Size size) {
    return ui.Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(squareRect)
      ..fillType = ui.PathFillType.evenOdd;
  }

  @override
  bool shouldReclip(_OutsideSquareClipper old) => old.squareRect != squareRect;
}
