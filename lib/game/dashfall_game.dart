import 'package:flutter/material.dart';
import 'character.dart'; // Assuming this defines Character().radius & draw()
import 'platform.dart';  // Assuming this defines Platform, PlatformType, toRect(), color etc.
import 'spike.dart';     // Assuming this defines Spike, toOffset(), getPixelRadius(), update()
import '../widgets/game_over_screen.dart'; // Make sure this path is correct
import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:audioplayers/audioplayers.dart';


const double GRAVITY_PER_SECOND = 28.0;
const double INITIAL_JUMP_VELOCITY = -12.0;
const double JUMP_VELOCITY_SOLID = -16.5;
const double JUMP_VELOCITY_DASHED = -38.0;
const double BIRD_Y_VELOCITY_TO_SCREEN_SCALER = 0.18;
const double MAX_DOWNWARD_VELOCITY = 15.0;
const double MAX_UPWARD_VELOCITY = -20.0;
const double HORIZONTAL_SMOOTHNESS = 0.08;
const double SCROLL_SCORE_MULTIPLIER = 0.08;

class DashFallGame extends StatefulWidget {
  const DashFallGame({super.key});

  @override
  State<DashFallGame> createState() => _DashFallGameState();
}

class _DashFallGameState extends State<DashFallGame> with SingleTickerProviderStateMixin {
  final AudioPlayer _solidBouncePlayer = AudioPlayer();
  final AudioPlayer _dashedBouncePlayer = AudioPlayer();
  bool _isDisposed = false;
  late AnimationController _controller;
  StreamSubscription? _accelerometerSubscription;
  double birdX = 0.0;
  double birdY = 0.0;
  double velocityY = 0.0;
  double _targetBirdX = 0.0;

  List<Platform> platforms = [];
  List<Spike> spikes = [];
  final Random _random = Random();
  int score = 0;
  int _highScore = 0;
  bool isGameOver = false;
  double lastSpikeY = -1.0;

  Size? _currentScreenSize;

  static const String _highScoreKey = 'dashFallHighScore';

  int _currentSpikeScoreBracket = 0;
  bool _spikeGeneratedForCurrentBracket = false;

  final String _interstitialAdUnitId = 'ca-app-pub-4689824267498752/1424700606'; // Use test ID during development
  InterstitialAd? _interstitialAd;

  int _gameLoopCallCount = 0;
  bool _initialResetDone = false;

  // Counters for platform generation
  int _solidGeneratedCount = 0;
  int _dashedGeneratedCount = 0;

  // --- NEW FOR AD FREQUENCY ---
  int _gameOverCountSinceLastAd = 0;
  static const String _gameOverCountKey = 'dashFallGameOverCount';
  final int _adFrequency = 3; // Show ad every 3 game overs
  // --- END NEW FOR AD FREQUENCY ---

  Duration? _lastElapsed; // <-- added to track elapsed time between frames

  @override
  void initState() {
    super.initState();
    MobileAds.instance.initialize();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 16),
      vsync: this,
    )
      ..addListener(_gameLoop)
      ..repeat();

    _loadHighScore().then((_) {
      if (mounted) {
        _loadGameOverCount();
      }
    });

    _accelerometerSubscription = accelerometerEvents.listen((event) {
      if (!isGameOver && mounted) {
        double tilt = event.x.clamp(-6.0, 6.0) / 6.0;
        _targetBirdX = -tilt * 1.2;
        _targetBirdX = _targetBirdX.clamp(-1.0, 1.0);
      }
    });
    _loadInterstitialAd();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (InterstitialAd ad) {
              ad.dispose();
              _loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
              print('Ad failed to show: $error');
              ad.dispose();
              _loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('InterstitialAd failed to load: $error');
          _interstitialAd = null;
        },
      ),
    );
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _highScore = prefs.getInt(_highScoreKey) ?? 0;
      });
    }
  }

  Future<void> _saveHighScore(int currentScore) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_highScoreKey, currentScore);
  }

  Future<void> _loadGameOverCount() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _gameOverCountSinceLastAd = prefs.getInt(_gameOverCountKey) ?? 0;
      });
    } else {
      _gameOverCountSinceLastAd = prefs.getInt(_gameOverCountKey) ?? 0;
    }
    print("AD FREQ: Loaded game over count: $_gameOverCountSinceLastAd");
  }

  Future<void> _saveGameOverCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_gameOverCountKey, _gameOverCountSinceLastAd);
    print("AD FREQ: Saved game over count: $_gameOverCountSinceLastAd");
  }

  @override
  void dispose() {
    _isDisposed = true;
    _controller.removeListener(_gameLoop);
    _controller.dispose();
    _accelerometerSubscription?.cancel();
    _interstitialAd?.dispose();
    _solidBouncePlayer.dispose();
    _dashedBouncePlayer.dispose();
    super.dispose();
  }

  void _resetGame() {
    if (!mounted) return;
    print("GAME: _resetGame() called.");
    setState(() {
      birdX = 0.0;
      _targetBirdX = 0.0;
      birdY = 0.0;
      velocityY = INITIAL_JUMP_VELOCITY;
      score = 0;
      isGameOver = false;
      platforms.clear();
      spikes.clear();

      platforms.addAll([
        Platform(x: 0.0, y: 0.5, width: 0.4, height: 0.02, type: PlatformType.solid),
        Platform(x: -0.5, y: 0.2, width: 0.3, height: 0.02, type: PlatformType.dashed),
        Platform(x: 0.6, y: -0.1, width: 0.4, height: 0.02, type: PlatformType.solid),
      ]);
      for (var p in platforms) {
        p.isUsed = false;
      }
      lastSpikeY = -1.0;
      _currentSpikeScoreBracket = 0;
      _spikeGeneratedForCurrentBracket = false;
      _gameLoopCallCount = 0;

      _solidGeneratedCount = 0;
      _dashedGeneratedCount = 0;
    });
  }

  void _handleGameOver() async {
    if (isGameOver) return;
    if (mounted) setState(() {
      isGameOver = true;
    });
    else
      isGameOver = true;

    print("GAME: _handleGameOver() triggered. Score: $score");

    _gameOverCountSinceLastAd++;
    print("AD FREQ: Game over count incremented to $_gameOverCountSinceLastAd");

    if (_gameOverCountSinceLastAd >= _adFrequency) {
      print("AD FREQ: Ad frequency met. Attempting to show ad.");
      if (_interstitialAd != null) {
        await _interstitialAd!.show();
        _gameOverCountSinceLastAd = 0;
      } else {
        print("AD FREQ: Ad not loaded, cannot show. Will try to load next time.");
        _loadInterstitialAd();
      }
    } else {
      print("AD FREQ: Ad frequency not met yet ($_gameOverCountSinceLastAd/$_adFrequency).");
    }
    await _saveGameOverCount();

    bool isNewRecord = false;
    if (score > _highScore) {
      isNewRecord = true;
      _highScore = score;
      await _saveHighScore(_highScore);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => GameOverScreen(
              score: score,
              highScore: _highScore,
              onRestart: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const DashFallGame()),
                );
              },
            ),
          ),
        );
      }
    });
  }

  void _gameLoop() {
    if (!mounted || _currentScreenSize == null) return;
    if (isGameOver) return;

    final elapsed = _controller.lastElapsedDuration;
    if (elapsed == null) return;

    double dt;
    if (_lastElapsed == null) {
      dt = 0;
    } else {
      dt = (elapsed - _lastElapsed!).inMicroseconds / 1000000.0;
    }
    _lastElapsed = elapsed;

    if (dt == 0) return; // skip first frame to avoid big jump

    _gameLoopCallCount++;

    setState(() {
      // Horizontal Movement
      final double effectiveHorizontalSmoothness = 1.0 - pow(1.0 - HORIZONTAL_SMOOTHNESS, dt * 60.0);
      birdX += (_targetBirdX - birdX) * effectiveHorizontalSmoothness;
      final birdRadiusNormX = Character().radius / (_currentScreenSize!.width / 2);
      if (birdX > 1.0 + birdRadiusNormX) birdX = -1.0 - birdRadiusNormX;
      if (birdX < -1.0 - birdRadiusNormX) birdX = 1.0 + birdRadiusNormX;

      // Vertical Movement
      velocityY += GRAVITY_PER_SECOND * dt;
      velocityY = velocityY.clamp(MAX_UPWARD_VELOCITY, MAX_DOWNWARD_VELOCITY);
      birdY += velocityY * BIRD_Y_VELOCITY_TO_SCREEN_SCALER * dt;

      // Platform Collision
      final birdPxY = _currentScreenSize!.height / 2 + birdY * _currentScreenSize!.height / 2;
      final birdPxX = _currentScreenSize!.width / 2 + birdX * _currentScreenSize!.width / 2;
      final characterPixelRadius = Character().radius;

      for (final platform in List<Platform>.from(platforms)) {
        if (platform.isUsed && platform.isDashed()) continue;
        final rect = platform.toRect(_currentScreenSize!);
        final isFalling = velocityY > 0;
        final birdBottomPx = birdPxY + characterPixelRadius;
        final platformTopPx = rect.top;
        const double landingTolerance = 12.0;
        bool yCollision = isFalling &&
            birdBottomPx >= platformTopPx - landingTolerance &&
            birdBottomPx <= platformTopPx + rect.height * 0.75;
        bool xCollision = (birdPxX + characterPixelRadius * 0.8) > rect.left &&
            (birdPxX - characterPixelRadius * 0.8) < rect.right;
        // Inside the platform collision loop in _gameLoop()
        if (yCollision && xCollision) {
          birdY = (platformTopPx - characterPixelRadius - _currentScreenSize!.height / 2) / (_currentScreenSize!.height / 2);

          // --- PLAY SOUND AND SET VELOCITY BASED ON PLATFORM TYPE ---
          if (platform.isDashed()) {
            velocityY = JUMP_VELOCITY_DASHED;
            platform.isUsed = true; // Mark dashed platform as used
            if (!_isDisposed) { // Check if widget is disposed
              // Consider using a try-catch if play can throw errors you want to handle gracefully
              _dashedBouncePlayer.play(AssetSource('sounds/dashed_platform_bounce.mp3'));
            }
          } else { // Solid platform
            velocityY = JUMP_VELOCITY_SOLID;
            if (!_isDisposed) { // Check if widget is disposed
              _solidBouncePlayer.play(AssetSource('sounds/solid_platform_bounce.mp3'));
            }
          }
          break;
        }

      }
      platforms.removeWhere((p) => p.isDashed() && p.isUsed);

      // Scrolling Logic
      double scrollThreshold = -0.4;
      if (birdY < scrollThreshold) {
        double scrollDelta = scrollThreshold - birdY;
        birdY = scrollThreshold;
        score += (scrollDelta * _currentScreenSize!.height * SCROLL_SCORE_MULTIPLIER).toInt();
        for (var platform in platforms) {
          platform.y += scrollDelta;
        }
        for (var spike in spikes) {
          spike.y += scrollDelta;
        }
        lastSpikeY += scrollDelta;
      }

      // Remove Off-Screen Elements
      final double bottomBoundary = 1.2;
      final double topBoundaryForGeneration = -0.8;
      platforms.removeWhere((p) => p.y > bottomBoundary + (p.height / 2));
      spikes.removeWhere((s) => s.y > bottomBoundary + (s.getPixelRadius(_currentScreenSize!) / (_currentScreenSize!.height / 2)));

      // --- Generate New Platforms and Spikes ---
      if (platforms.isEmpty || platforms.last.y > topBoundaryForGeneration) {
        double newPlatformX = _random.nextDouble() * 1.8 - 0.9;
        double lastKnownPlatformY = platforms.isEmpty ? (birdY < 0 ? birdY - 0.3 : 0.0) : platforms.last.y;
        double newPlatformY = lastKnownPlatformY - (_random.nextDouble() * 0.35 + 0.45);
        newPlatformY = newPlatformY.clamp(-1.0, topBoundaryForGeneration + 0.1);
        double newPlatformWidth = 0.18 + _random.nextDouble() * 0.15;

        PlatformType type;
        double randomVal = _random.nextDouble();
        if (randomVal < 0.5) {
          type = PlatformType.solid;
          _solidGeneratedCount++;
        } else {
          type = PlatformType.dashed;
          _dashedGeneratedCount++;
        }
        platforms.add(Platform(x: newPlatformX, y: newPlatformY, width: newPlatformWidth, height: 0.02, type: type));

        if ((_solidGeneratedCount + _dashedGeneratedCount) > 0 && (_solidGeneratedCount + _dashedGeneratedCount) % 20 == 0) {
          double totalGenerated = (_solidGeneratedCount + _dashedGeneratedCount).toDouble();
          if (totalGenerated > 0) {
            print("PLATFORM STATS: Solid: $_solidGeneratedCount (${(_solidGeneratedCount / totalGenerated * 100).toStringAsFixed(1)}%), Dashed: $_dashedGeneratedCount (${(_dashedGeneratedCount / totalGenerated * 100).toStringAsFixed(1)}%)");
          }
        }

        if (score >= _currentSpikeScoreBracket + 300) {
          _currentSpikeScoreBracket += 300;
          _spikeGeneratedForCurrentBracket = false;
        }
        double minSpikeSpacing = 0.6;
        double chanceToSpawnSpike = 0.18;
        if (!_spikeGeneratedForCurrentBracket &&
            (lastSpikeY == -1.0 || (newPlatformY - lastSpikeY).abs() > minSpikeSpacing) &&
            _random.nextDouble() < chanceToSpawnSpike &&
            score > 80) {
          double spikeX = _random.nextDouble() * 1.8 - 0.9;
          spikes.add(Spike(x: spikeX, y: newPlatformY - 0.12 - _random.nextDouble() * 0.1));
          lastSpikeY = newPlatformY - 0.12;
          _spikeGeneratedForCurrentBracket = true;
        }
      }

      for (final spike in spikes) {
        spike.update();
      }

      final birdBottomNorm = birdY + (characterPixelRadius / (_currentScreenSize!.height / 2));
      if (birdBottomNorm > 1.15) {
        _handleGameOver();
        return;
      }
      for (final spike in List<Spike>.from(spikes)) {
        final spikeCenterPx = spike.toOffset(_currentScreenSize!);
        final spikePixelRadius = spike.getPixelRadius(_currentScreenSize!);
        final dx = birdPxX - spikeCenterPx.dx;
        final dy = birdPxY - spikeCenterPx.dy;
        final distance = sqrt(dx * dx + dy * dy);
        if (distance < characterPixelRadius * 0.85 + spikePixelRadius * 0.85) {
          _handleGameOver();
          return;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final newScreenSize = MediaQuery.of(context).size;
    if (_currentScreenSize == null || _currentScreenSize != newScreenSize) {
      _currentScreenSize = newScreenSize;
      if (!_initialResetDone && _currentScreenSize != null) {
        print("BUILD: Screen size available: ${_currentScreenSize?.width}x${_currentScreenSize?.height}. Resetting game.");
        _resetGame();
        _initialResetDone = true;
      } else if (_initialResetDone && _currentScreenSize != null) {
        print("BUILD: Screen size changed. Consider if elements need recalc.");
      }
    }

    if (_currentScreenSize == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.lightBlue.shade100,
      body: Stack(
        children: [
          CustomPaint(
            painter: _GamePainter(
                birdX: birdX, birdY: birdY,
                platforms: platforms, spikes: spikes),
            child: Container(width: _currentScreenSize!.width, height: _currentScreenSize!.height),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            left: 0, right: 0,
            child: Text(
              'Score: $score',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 30, fontWeight: FontWeight.bold, color: Colors.black87,
                  shadows: [Shadow(blurRadius: 1.5, color: Colors.white, offset: Offset(1, 1))]
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GamePainter extends CustomPainter {
  final double birdX;
  final double birdY;
  final List<Platform> platforms;
  final List<Spike> spikes;

  _GamePainter({
    required this.birdX, required this.birdY,
    required this.platforms, required this.spikes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Colors.lightBlue.shade300, Colors.lightBlue.shade50],
        stops: const [0.0, 0.7]
    );
    canvas.drawRect(bgRect, Paint()..shader = gradient.createShader(bgRect));

    for (final platform in platforms) {
      final platformRect = platform.toRect(size);
      final platformPaint = Paint()..color = platform.color;
      if (platform.type == PlatformType.dashed) {
        const double dashWidth = 10.0;
        const double dashSpace = 6.0;
        double startX = platformRect.left;
        final platformStrokePaint = Paint()
          ..color = platform.color.withOpacity(0.85)
          ..strokeWidth = platformRect.height
          ..style = PaintingStyle.stroke;
        while (startX < platformRect.right) {
          final endX = (startX + dashWidth).clamp(platformRect.left, platformRect.right);
          canvas.drawLine(
            Offset(startX, platformRect.center.dy),
            Offset(endX, platformRect.center.dy),
            platformStrokePaint,
          );
          startX += dashWidth + dashSpace;
        }
      } else {
        RRect platformRRect = RRect.fromRectAndRadius(platformRect, const Radius.circular(4));
        canvas.drawRRect(platformRRect, platformPaint);
      }
    }

    final spikePaint = Paint()..color = Colors.red.shade700;
    for (final spike in spikes) {
      final center = spike.toOffset(size);
      final radius = spike.getPixelRadius(size);
      var path = Path();
      path.moveTo(center.dx, center.dy - radius);
      path.lineTo(center.dx - radius * 0.8, center.dy + radius * 0.6);
      path.lineTo(center.dx + radius * 0.8, center.dy + radius * 0.6);
      path.close();
      canvas.drawPath(path, spikePaint);
    }
    Character().draw(canvas, size, birdX, birdY);
  }

  @override
  bool shouldRepaint(covariant _GamePainter oldDelegate) {
    if (birdX != oldDelegate.birdX ||
        birdY != oldDelegate.birdY ||
        platforms.length != oldDelegate.platforms.length ||
        spikes.length != oldDelegate.spikes.length) {
      return true;
    }
    return false;
  }
}

