import 'package:flutter/material.dart';
import 'character.dart';
import 'platform.dart';
import 'spike.dart';
import '../widgets/game_over_screen.dart';
import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences
import 'package:google_mobile_ads/google_mobile_ads.dart';

class DashFallGame extends StatefulWidget {
  const DashFallGame({super.key});

  @override
  State<DashFallGame> createState() => _DashFallGameState();
}

class _DashFallGameState extends State<DashFallGame> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late StreamSubscription _accelerometerSubscription;
  double birdX = 0.0;
  double birdY = 0.2;
  double velocityY = 0.0;
  double gravity = 0.30;

  double _targetBirdX = 0.0;
  double horizontalSmoothness = 0.1;

  List<Platform> platforms = [];
  List<Spike> spikes = [];
  final Random _random = Random();
  int score = 0;
  int _highScore = 0; // Changed to _highScore to indicate it's internal state
  bool isGameOver = false;
  double lastSpikeY = -1.0;

  late Size _currentScreenSize;

  static const String _highScoreKey = 'dashFallHighScore';

  int _currentSpikeScoreBracket = 0;
  bool _spikeGeneratedForCurrentBracket = false;
  final String _interstitialAdUnitId = 'ca-app-pub-4689824267498752/9947587251';
  InterstitialAd? _interstitialAd;

  void _loadInterstitialAd() { // <--- ADD THIS METHOD
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          // Keep a reference to the ad so you can show it later.
          _interstitialAd = ad;
          print('InterstitialAd loaded.');

          // Set ad dismissal callback
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (InterstitialAd ad) {
              print('$ad onAdDismissedFullScreenContent.');
              ad.dispose(); // Dispose the ad after it's shown
              _loadInterstitialAd(); // Load the next ad
            },
            onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
              print('$ad onAdFailedToShowFullScreenContent: $error');
              ad.dispose(); // Dispose the ad
              _loadInterstitialAd(); // Attempt to load the next ad
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('InterstitialAd failed to load: $error');
          _interstitialAd = null; // Ensure ad instance is null if load fails
        },
      ),
    );
  }




  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_gameLoop)
      ..repeat();

    _loadHighScore().then((_) { // Load high score then reset game
      _resetGame(); // Initial game state reset, now aware of loaded highScore
    });


    _accelerometerSubscription = accelerometerEvents.listen((event) {
      if (!isGameOver) {
        _targetBirdX += -event.x * 0.1;
        if (_targetBirdX > 1.0) _targetBirdX = -1.0;
        else if (_targetBirdX < -1.0) _targetBirdX = 1.0;
      }
    });

    _loadInterstitialAd();

    // velocityY = -18.0; // Moved initial jump to _resetGame after high score is loaded
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() { // Ensure UI updates if highScore is displayed somewhere in this widget tree
      _highScore = prefs.getInt(_highScoreKey) ?? 0;
    });
  }

  Future<void> _saveHighScore(int currentScore) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_highScoreKey, currentScore);
  }


  @override
  void dispose() {
    _controller.dispose();
    _accelerometerSubscription.cancel();
    _interstitialAd?.dispose();
    super.dispose();
  }

  void _resetGame() {
    // Note: _highScore is NOT reset here. It persists across games.
    setState(() {
      birdX = 0.0;
      _targetBirdX = 0.0;
      birdY = 0.2;
      velocityY = 0.0; // Reset velocity
      score = 0;
      isGameOver = false;
      platforms.clear();
      spikes.clear();
      platforms.addAll([
        Platform(x: 0.0, y: 0.3, width: 0.4, height: 0.02, type: PlatformType.solid),
        Platform(x: -0.5, y: -0.1, width: 0.3, height: 0.02, type: PlatformType.dashed),
        Platform(x: 0.6, y: -0.5, width: 0.4, height: 0.02, type: PlatformType.solid),
      ]);
      for (var p in platforms) {
        p.isUsed = false;
      }
      lastSpikeY = -1.0;
      _currentSpikeScoreBracket = 0;
      _spikeGeneratedForCurrentBracket = false;
      velocityY = -18.0; // Apply initial jump for new game
    });
  }

  void _handleGameOver() async { // Make it async
    if (!isGameOver) {
      setState(() { // Set isGameOver immediately to stop game loop updates
        isGameOver = true;
      });

      if (_interstitialAd != null) {
        _interstitialAd!.show();
        _interstitialAd = null; // Mark as shown, new ad will be loaded by callback
      }

      bool isNewRecord = false;
      int finalHighScoreToDisplay = _highScore; // Start with the current loaded high score

      if (score > _highScore) {
        isNewRecord = true;
        _highScore = score; // Update in-memory high score
        finalHighScoreToDisplay = _highScore; // The new score is the high score
        await _saveHighScore(_highScore); // Save the new high score
      }
      // If score is not > _highScore, finalHighScoreToDisplay remains the old _highScore

      // Ensure this runs after the current frame is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) { // Check if the widget is still in the tree
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => GameOverScreen(
                score: score, // The current game's score
                highScore: finalHighScoreToDisplay, // The true high score
                isNewRecord: isNewRecord, // True only if current score > previous high score
                onRestart: () {
                  // When restarting, simply navigate to a new game instance.
                  // The new instance will load the potentially updated high score.
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
  }

  void _gameLoop() {
    if (!mounted || isGameOver || _currentScreenSize == null) return;

    // ... (rest of your _gameLoop remains IDENTICAL)
    setState(() {
      // --- Horizontal Smoothing ---
      birdX = birdX + ( _targetBirdX - birdX ) * horizontalSmoothness;

      // Pixel-perfect screen wrapping based on bird's pixel position and radius
      final birdRadius = Character().radius;
      final screenWidth = _currentScreenSize.width;
      final birdPxX = screenWidth / 2 + birdX * screenWidth / 2;
      // If the bird's right edge is left of the screen, wrap to just off the right edge
      if (birdPxX + birdRadius < 0) {
        birdX = (screenWidth + birdRadius) / (screenWidth / 2) - 1;
        _targetBirdX = birdX;
      }
      // If the bird's left edge is right of the screen, wrap to just off the left edge
      else if (birdPxX - birdRadius > screenWidth) {
        birdX = -(screenWidth + birdRadius) / (screenWidth / 2) + 1;
        _targetBirdX = birdX;
      }

      // --- Vertical Movement (Gravity & Velocity) ---
      velocityY += gravity;
      velocityY = velocityY.clamp(-15.0, 8.0); // Clamp speed
      birdY += velocityY / 300.0; // Fine-tuned vertical speed

      // --- Platform Collision ---
      final birdPxY = _currentScreenSize.height / 2 + birdY * _currentScreenSize.height / 2;

      for (final platform in platforms) {
        if (platform.isUsed && platform.isDashed()) continue;

        final rect = platform.toRect(_currentScreenSize); // Use actual screen size

        final isFalling = velocityY > 0;
        final birdBottom = birdPxY + Character().radius; // Use Character().radius directly
        final platformTop = rect.top;
        // Collision tolerance
        final isAbovePlatform = birdBottom >= platformTop - 10 && birdBottom <= platformTop + 15;
        final isWithinPlatformX = birdPxX >= rect.left && birdPxX <= rect.right;

        if (isFalling && isAbovePlatform && isWithinPlatformX) {
          velocityY = platform.isDashed() ? -45.0 : -15.0; // Jump forces
          if (platform.isDashed()) {
            platform.isUsed = true;
          }
          break;
        }
      }
      platforms.removeWhere((p) => p.isDashed() && p.isUsed);

      // --- Scrolling and Dynamic Platform/Spike Generation ---
      if (birdY < -0.2) {
        double scrollDelta = -birdY - 0.2;
        birdY = -0.2;
        score += (scrollDelta * 100).toInt();

        for (var platform in platforms) {
          platform.y += scrollDelta;
        }
        for (var spike in spikes) {
          spike.y += scrollDelta;
        }
      }

      platforms.removeWhere((p) => p.y > 1.2);
      spikes.removeWhere((s) => s.y > 1.2);

      if (platforms.isEmpty || platforms.last.y > -0.8) {
        double x = _random.nextDouble() * 2 - 1;
        double lastPlatformY = platforms.isEmpty ? -0.5 : platforms.last.y;
        double y = lastPlatformY - (_random.nextDouble() * 0.4 + 0.3);
        if (y > -0.8) y = -0.8;
        double width = 0.2 + _random.nextDouble() * 0.15;
        PlatformType type;
        if (_random.nextDouble() < 0.7) { // 0.7 means 70% chance
          type = PlatformType.solid;
        } else {
          type = PlatformType.dashed; // The remaining 30% chance
        }
        platforms.add(
          Platform(x: x, y: y, width: width, height: 0.02, type: type),
        );

        if (score >= _currentSpikeScoreBracket + 5000) {
          _currentSpikeScoreBracket += 5000; // Move to the next bracket
          _spikeGeneratedForCurrentBracket = false; // Allow a new spike for this new bracket
        }

        // 2. If a spike hasn't been generated for the current bracket yet,
        //    AND we meet a spacing condition, then try to generate one with a random chance.
        double minSpikeSpacing = 0.4; // You can adjust this minimum vertical spacing if needed

        // Adjust chanceToSpawnThisTick:
        // Higher (e.g., 0.3 to 0.5) = spike appears sooner once eligible in the bracket.
        // Lower (e.g., 0.05 to 0.2) = spike may appear later in the bracket.
        double chanceToSpawnThisTick = 0.15; // Example: 15% chance per eligible game tick

        if (!_spikeGeneratedForCurrentBracket &&
            (lastSpikeY - y > minSpikeSpacing) &&
            _random.nextDouble() < chanceToSpawnThisTick) {

          double spikeX = _random.nextDouble() * 2 - 1; // Random horizontal position
          spikes.add(Spike(x: spikeX, y: y + 0.15));     // Add the new spike
          lastSpikeY = y;                               // Remember y-pos for spacing next one
          _spikeGeneratedForCurrentBracket = true;      // Mark spike as generated for this bracket
        }
      }

      // --- Spikes Horizontal Movement ---
      for (final spike in spikes) {
        spike.update();
      }

      // --- Game Over Conditions ---
      if (birdY > 1.2) {
        _handleGameOver();
      }
      for (final spike in spikes) {
        final spikeCenter = spike.toOffset(_currentScreenSize);
        final spikeRadius = spike.getPixelRadius(_currentScreenSize);
        final dx = birdPxX - spikeCenter.dx;
        final dy = birdPxY - spikeCenter.dy;
        final distance = sqrt(dx * dx + dy * dy);
        if (distance < Character().radius + spikeRadius) { // Use Character().radius directly
          _handleGameOver();
          break;
        }
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    // It's good practice to get screen size here if it can change (e.g. orientation)
    // and if game elements positions depend on it directly in paint.
    // However, if your game loop uses it for logic that assumes a fixed size per game session,
    // getting it once might be okay. Your current check in _gameLoop for null is a safeguard.
    _currentScreenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white, // Or whatever background you prefer
      body: Stack(
        children: [
          CustomPaint(
            painter: _GamePainter(birdX: birdX, birdY: birdY, platforms: platforms, spikes: spikes),
            child: Container(), // Ensures CustomPaint takes up space
          ),
          Positioned(
            top: 50,
            left: 0,
            right: 0,
            child: Text(
              'Score: $score',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black, // Ensure visibility against your game background
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// _GamePainter remains IDENTICAL
class _GamePainter extends CustomPainter {
  final double birdX;
  final double birdY;
  final List<Platform> platforms;
  final List<Spike> spikes;
  _GamePainter({required this.birdX, required this.birdY, required this.platforms, required this.spikes});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.blue.shade200, Colors.lightBlue.shade50],
    );
    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);

    // Draw platforms
    for (final platform in platforms) {
      final paint = Paint()..color = platform.color;
      final rect = platform.toRect(size);
      if (platform.type == PlatformType.dashed) {
        const dashWidth = 6.0;
        const dashSpace = 4.0;
        double startX = rect.left;
        while (startX < rect.right) {
          final endX = (startX + dashWidth).clamp(rect.left, rect.right);
          canvas.drawLine(
            Offset(startX, rect.center.dy),
            Offset(endX, rect.center.dy),
            paint..strokeWidth = rect.height,
          );
          startX += dashWidth + dashSpace;
        }
      } else {
        canvas.drawRect(rect, paint);
      }
    }

    // Draw spikes
    for (final spike in spikes) {
      final paint = Paint()..color = Colors.redAccent;
      final center = spike.toOffset(size);
      final radius = spike.getPixelRadius(size);
      canvas.drawCircle(center, radius, paint);
    }

    // Draw bird
    final character = Character(); // Assuming Character() is cheap to create
    character.draw(canvas, size, birdX, birdY);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}