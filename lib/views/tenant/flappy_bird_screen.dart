// lib/views/tenant/flappy_bird_screen.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/sensor_service.dart';
import '../../utils/constants.dart';

class FlappyBirdScreen extends StatefulWidget {
  const FlappyBirdScreen({super.key});

  @override
  State<FlappyBirdScreen> createState() => _FlappyBirdScreenState();
}

class _FlappyBirdScreenState extends State<FlappyBirdScreen>
    with SingleTickerProviderStateMixin {
  final _sensor = SensorService();

  // Hitbox tuning berdasarkan area visual utama tumpukan lemari.
  static const double _obstacleHitboxInsetX = 0.14;
  static const double _upperObstacleHitboxInsetTop = 0.08;
  static const double _upperObstacleHitboxInsetBottom = 0.08;
  static const double _lowerObstacleHitboxInsetTop = 0.08;
  static const double _lowerObstacleHitboxInsetBottom = 0.08;
  static const double _ceilingHeightFactor = 0.0;
  // fraction of screen height used by the ground graphic at the bottom
  static const double _groundHeightFactor = 0.12;
  static const double _stripEdgeBleed = 6.0;

  // ─── Game State ──────────────────────────────────────────────────────────────
  static const double _birdX = 0.25; // Posisi X tetap (normalized 0-1)

  double _birdY = 0.5; // Posisi Y bird (0 = atas, 1 = bawah)
  double _birdVelocity = 0.0; // Kecepatan vertikal (pixel/s)
  double _score = 0;
  int _highScore = 0;
  bool _isPlaying = false;
  bool _isDead = false;
  bool _isGyroMode = false;
  bool _gyroAvailable = false;
  bool _showCountdown = false;
  int _countdown = 3;

  // Pipa
  final List<_Pipe> _pipes = [];
  final List<_Coin> _coins = [];
  double _pipeWidth = 60;
  final double _pipeGap = 0; // Diisi saat build

  // Game loop
  Timer? _gameTimer;
  Timer? _countdownTimer;
  DateTime? _lastFrame;

  // Ukuran layar
  double _screenW = 0;
  double _screenH = 0;
  double _birdSize = 0;
  double _coinSize = 2;

  // Gyro raw Y value
  double _gyroY = 0;
  double _stripScrollX = 0;

  @override
  void initState() {
    super.initState();
    _sensor.setShakeDetectionEnabled(false);
    _checkGyro();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  @override
  void dispose() {
    _stopGame();
    _sensor.stopGyroscope();
    _sensor.setShakeDetectionEnabled(true);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  Future<void> _checkGyro() async {
    final available = await _sensor.checkGyroAvailability();
    if (mounted) setState(() => _gyroAvailable = available);
  }

  // ─── Game Control ─────────────────────────────────────────────────────────────

  void _startCountdown() {
    setState(() {
      _showCountdown = true;
      _countdown = 3;
    });
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        setState(() => _showCountdown = false);
        _startGame();
      }
    });
  }

  void _startGame() {
    _resetState();
    if (_isGyroMode && _gyroAvailable) {
      _sensor.startGyroscope((x, y, z) {
        _gyroY = y; // y axis = tilt depan/belakang
      });
    }
    _lastFrame = DateTime.now();
    _gameTimer = Timer.periodic(const Duration(milliseconds: 16), _gameLoop);
    setState(() => _isPlaying = true);
  }

  void _stopGame() {
    _gameTimer?.cancel();
    _countdownTimer?.cancel();
    _sensor.stopGyroscope();
  }

  void _resetState() {
    _birdY = 0.5;
    _birdVelocity = 0;
    _score = 0;
    _pipes.clear();
    _coins.clear();
    _isDead = false;
    _gyroY = 0;
    _stripScrollX = 0;
    _lastFrame = null;
  }

  void _jump() {
    if (!_isPlaying || _isDead) return;
    if (_isGyroMode) return; // Gyro mode: tidak pakai tap
    HapticFeedback.lightImpact();
    setState(() {
      _birdVelocity =
          AppConstants.JUMP_VELOCITY / _screenH; // Normalize ke screen height
    });
  }

  // ─── Game Loop ────────────────────────────────────────────────────────────────

  void _gameLoop(Timer t) {
    if (!mounted) {
      t.cancel();
      return;
    }

    final now = DateTime.now();
    final dt = _lastFrame != null
        ? now.difference(_lastFrame!).inMilliseconds / 1000.0
        : 0.016;
    _lastFrame = now;
    final safeDt = dt.clamp(0.0, 0.05); // Clamp untuk menghindari spike besar

    setState(() {
      // ── Bird physics ──
      if (_isGyroMode && _gyroAvailable) {
        // Gyro mode: tilt phone untuk kontrol bird
        final gyroInput = _gyroY * AppConstants.GYRO_SENSITIVITY;
        _birdVelocity = gyroInput / _screenH * 60;
        _birdY += _birdVelocity;
      } else {
        // Tap mode: gravitasi normal
        final gravity = AppConstants.GRAVITY / _screenH;
        _birdVelocity += gravity * safeDt;
        _birdY += _birdVelocity * safeDt;
      }

      // Batas atas/bawah
      const ceilingLimit = _ceilingHeightFactor;
      const groundLimit = 1.0 - _groundHeightFactor;
      if (_birdY <= ceilingLimit || _birdY >= groundLimit) {
        _die();
        return;
      }

      // ── Spawn pipa ──
      final pipeSpawnInterval = _screenW * 0.75;
      if (_pipes.isEmpty || (_screenW - _pipes.last.x) >= pipeSpawnInterval) {
        final gapCenter = 0.25 + Random().nextDouble() * 0.5;
        final gapNorm = AppConstants.PIPE_GAP / _screenH;
        final gapTopPx = (_screenH * (gapCenter - gapNorm / 2));
        final gapBottomPx = (_screenH * (gapCenter + gapNorm / 2));
        _pipes.add(_Pipe(
          x: _screenW,
          gapTop: gapCenter - gapNorm / 2,
          gapBottom: gapCenter + gapNorm / 2,
        ));
        _coins.add(_Coin(
          x: _screenW + ((_pipeWidth - _coinSize) / 2),
          y: ((gapTopPx + gapBottomPx) / 2 - (_coinSize / 2))
              .clamp(gapTopPx + 12.0, gapBottomPx - _coinSize - 12.0)
              .toDouble(),
        ));
      }

      // ── Move pipa ──
      final pipeSpeed = AppConstants.PIPE_SPEED / _screenW;
      for (final pipe in _pipes) {
        pipe.x -= pipeSpeed * safeDt * _screenW;
      }
      for (final coin in _coins) {
        coin.x -= pipeSpeed * safeDt * _screenW;
      }
      _pipes.removeWhere((p) => p.x + _pipeWidth < 0);
      _coins.removeWhere((coin) => coin.x + _coinSize < 0 || coin.collected);

      // Sinkronkan pergerakan strip langit-langit/tanah agar terasa menyambung.
      _stripScrollX += AppConstants.PIPE_SPEED * safeDt;

      _checkCoinCollision();

      // ── Collision detection ──
      _checkCollision();
    });
  }

  void _checkCoinCollision() {
    final birdPixelX = _birdX * _screenW;
    final birdPixelY = _birdY * _screenH;
    final birdR = _birdSize / 2 * 0.8;
    final birdRect = Rect.fromCircle(
      center: Offset(birdPixelX, birdPixelY),
      radius: birdR,
    );

    for (final coin in _coins) {
      if (coin.collected) continue;

      final coinRect = Rect.fromLTWH(coin.x, coin.y, _coinSize, _coinSize);
      if (birdRect.overlaps(coinRect)) {
        coin.collected = true;
        _score++;
        HapticFeedback.selectionClick();
      }
    }
  }

  void _checkCollision() {
    final birdPixelX = _birdX * _screenW;
    final birdPixelY = _birdY * _screenH;
    final birdR = _birdSize / 2 * 0.8; // Hitbox lebih kecil dari visual
    final ceilingHeight = _screenH * _ceilingHeightFactor;
    final groundTop = _screenH * (1.0 - _groundHeightFactor);
    final birdRect = Rect.fromCircle(
      center: Offset(birdPixelX, birdPixelY),
      radius: birdR,
    );

    for (final pipe in _pipes) {
      final pipeLeft = pipe.x;
      final pipeRight = pipe.x + _pipeWidth;
      final gapTopPx = pipe.gapTop * _screenH;
      final gapBottomPx = pipe.gapBottom * _screenH;

      // Skip cepat bila tidak overlap horizontal dasar.
      if (birdRect.right < pipeLeft || birdRect.left > pipeRight) {
        continue;
      }

      final topObstacleHeight = max(0.0, gapTopPx - ceilingHeight);
      final bottomObstacleHeight = max(0.0, groundTop - gapBottomPx);

      final topRect = Rect.fromLTRB(
        pipeLeft + _pipeWidth * _obstacleHitboxInsetX,
        ceilingHeight + (topObstacleHeight * _upperObstacleHitboxInsetTop),
        pipeRight - _pipeWidth * _obstacleHitboxInsetX,
        gapTopPx - (topObstacleHeight * _upperObstacleHitboxInsetBottom),
      );

      final bottomRect = Rect.fromLTRB(
        pipeLeft + _pipeWidth * _obstacleHitboxInsetX,
        gapBottomPx + (bottomObstacleHeight * _lowerObstacleHitboxInsetTop),
        pipeRight - _pipeWidth * _obstacleHitboxInsetX,
        groundTop - (bottomObstacleHeight * _lowerObstacleHitboxInsetBottom),
      );

      if (birdRect.overlaps(topRect) || birdRect.overlaps(bottomRect)) {
        _die();
        return;
      }
    }
  }

  void _die() {
    _isDead = true;
    _isPlaying = false;
    _gameTimer?.cancel();
    _sensor.stopGyroscope();
    HapticFeedback.heavyImpact();
    if (_score.toInt() > _highScore) {
      _highScore = _score.toInt();
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          _screenW = constraints.maxWidth;
          _screenH = constraints.maxHeight;
          _birdSize = _screenW * 0.15;
          _coinSize = _screenW * 0.2;
          _pipeWidth = _screenW * 0.18;

          return GestureDetector(
            onTap: _isPlaying ? _jump : null,
            child: Stack(
              children: [
                // Sky background
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/background.png',
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                  ),
                ),

                // (Removed ceiling/ground obstacle strips per user request)

                // Pipes
                ..._pipes.expand((pipe) => _buildPipe(pipe)),

                // Coins
                ..._coins
                    .where((coin) => !coin.collected)
                    .map((coin) => _buildCoin(coin)),

                // Ground strip (so bottom obstacles can align to it)
                _buildScrollingStrip(
                  assetPath: 'assets/images/ground.png',
                  height: _screenH * _groundHeightFactor,
                  alignTop: false,
                ),

                // Bird
                Positioned(
                  left: _birdX * _screenW - _birdSize / 2,
                  top: _birdY * _screenH - _birdSize / 2,
                  child: _buildBird(),
                ),

                // Score
                if (_isPlaying || _isDead)
                  Positioned(
                    top: 60,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        Text(
                          '${_score.toInt()}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                  offset: Offset(2, 2),
                                  blurRadius: 4,
                                  color: Colors.black38)
                            ],
                          ),
                        ),
                        Text(
                          _isGyroMode ? '🎮 Mode Gyroscope' : '👆 Mode Tap',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                // Countdown
                if (_showCountdown)
                  Center(
                    child: Text(
                      _countdown > 0 ? '$_countdown' : 'MULAI!',
                      style: const TextStyle(
                        fontSize: 80,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                              offset: Offset(3, 3),
                              blurRadius: 6,
                              color: Colors.black38)
                        ],
                      ),
                    ),
                  ),

                // Start screen
                if (!_isPlaying && !_isDead && !_showCountdown)
                  _buildStartScreen(),

                // Game over screen
                if (_isDead && !_showCountdown) _buildGameOverScreen(),

                // Back button
                Positioned(
                  top: 40,
                  left: 16,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildPipe(_Pipe pipe) {
    final gapTopPx = pipe.gapTop * _screenH;
    final gapBottomPx = pipe.gapBottom * _screenH;
    final groundTop = _screenH * _groundHeightFactor;

    return [
      // Top pipe
      Positioned(
        left: pipe.x,
        top: 0,
        width: _pipeWidth,
        height: max(0.0, gapTopPx),
        child: Transform.rotate(
          angle: pi,
          alignment: Alignment.center,
          child: const _PipeWidget(
            assetPath: 'assets/images/pipe.png',
          ),
        ),
      ),
      // Bottom pipe
      Positioned(
        left: pipe.x,
        top: gapBottomPx,
        width: _pipeWidth,
        height: max(0.0, _screenH - groundTop - gapBottomPx),
        child: const _PipeWidget(
          assetPath: 'assets/images/pipe.png',
        ),
      ),
    ];
  }

  Widget _buildScrollingStrip({
    required String assetPath,
    required double height,
    required bool alignTop,
  }) {
    final tileWidth = max(1.0, _screenW * 0.45);
    final offset = _stripScrollX % tileWidth;
    final tileCount = (_screenW / tileWidth).ceil() + 2;

    return Positioned(
      top: alignTop ? -_stripEdgeBleed : null,
      bottom: alignTop ? null : -_stripEdgeBleed,
      left: 0,
      right: 0,
      height: height + (_stripEdgeBleed * 2),
      child: ClipRect(
        child: Stack(
          children: List.generate(tileCount, (index) {
            return Positioned(
              left: (index * tileWidth) - offset,
              top: 0,
              bottom: 0,
              width: tileWidth,
              child: Image.asset(
                assetPath,
                fit: BoxFit.fill,
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildBird() {
    final renderWidth = _birdSize * 1.4;
    final renderHeight = _birdSize * 1.25;

    return Transform.rotate(
      angle: -0.16,
      child: Container(
        width: renderWidth,
        height: renderHeight,
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 14,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Image.asset(
          'assets/images/landlord.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Icon(Icons.person, color: Color(0xFF8095E4), size: 26),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCoin(_Coin coin) {
    return Positioned(
      left: coin.x,
      top: coin.y,
      width: _coinSize,
      height: _coinSize,
      child: Image.asset(
        'assets/images/uang.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }

  Widget _buildStartScreen() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Flappy Kost',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('High Score: $_highScore',
                style: const TextStyle(color: Color(0xFF6B7280))),
            const SizedBox(height: 20),
            // Mode selector
            Row(
              children: [
                Expanded(
                  child: _ModeButton(
                    label: '👆 Tap',
                    subtitle: 'Tap layar\nuntuk terbang',
                    selected: !_isGyroMode,
                    onTap: () => setState(() => _isGyroMode = false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ModeButton(
                    label: '📱 Gyro',
                    subtitle: _gyroAvailable
                        ? 'Miringkan ponsel\nuntuk kontrol'
                        : 'Gyroscope\ntidak tersedia',
                    selected: _isGyroMode,
                    enabled: _gyroAvailable,
                    onTap: _gyroAvailable
                        ? () => setState(() => _isGyroMode = true)
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startCountdown,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8095E4),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Mulai Main',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOverScreen() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💥 Nabrak!',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFE53935))),
            const SizedBox(height: 16),
            _ScoreRow(label: 'Skor', value: '${_score.toInt()}'),
            const SizedBox(height: 6),
            _ScoreRow(
                label: 'High Score', value: '$_highScore', highlight: true),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startCountdown,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8095E4),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Main Lagi',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kembali',
                  style: TextStyle(color: Color(0xFF6B7280))),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Pipe data ─────────────────────────────────────────────────────────────────

class _Pipe {
  double x;
  double gapTop;
  double gapBottom;
  bool passed = false;

  _Pipe({required this.x, required this.gapTop, required this.gapBottom});
}

class _Coin {
  double x;
  double y;
  bool collected = false;

  _Coin({required this.x, required this.y});
}

// ─── Pipe Widget ───────────────────────────────────────────────────────────────

class _PipeWidget extends StatelessWidget {
  final String assetPath;
  const _PipeWidget({required this.assetPath});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: ClipRect(
        child: Image.asset(
          assetPath,
          fit: BoxFit.fill,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

// ─── Small Widgets ─────────────────────────────────────────────────────────────

class _ModeButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  const _ModeButton({
    required this.label,
    required this.subtitle,
    required this.selected,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF8095E4).withOpacity(0.1)
              : const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF8095E4) : const Color(0xFFE5E7EB),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: enabled
                      ? const Color(0xFF1A1A2E)
                      : const Color(0xFF9CA3AF),
                )),
            const SizedBox(height: 4),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: enabled
                      ? const Color(0xFF6B7280)
                      : const Color(0xFF9CA3AF),
                )),
          ],
        ),
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const _ScoreRow(
      {required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF6B7280))),
        Text(value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: highlight ? 18 : 16,
              color:
                  highlight ? const Color(0xFF8095E4) : const Color(0xFF1A1A2E),
            )),
      ],
    );
  }
}
