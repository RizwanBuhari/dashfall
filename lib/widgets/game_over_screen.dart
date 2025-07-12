import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dashfallgame/player_prefs.dart';

class GameOverScreen extends StatefulWidget {
  final int score;
  final int highScore; // Kept for initial display before Firestore loads
  final VoidCallback onRestart;

  const GameOverScreen({
    super.key,
    required this.score,
    required this.highScore, // Still useful for initial display
    // bool isNewRecord = false, // Not needed from constructor if determined internally
    required this.onRestart,
  });

  @override
  State<GameOverScreen> createState() => _GameOverScreenState();
}

class _GameOverScreenState extends State<GameOverScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoadingHighScore = true;
  String? _playerUsername;
  late int _displayHighScore;
  bool _isNewRecordDisplayed = false; // <<< NEW: State for displaying the record message

  @override
  void initState() {
    super.initState();
    _displayHighScore = widget.highScore;
    _initializeAndFetchHighScore();
  }

  Future<void> _initializeAndFetchHighScore() async {
    setState(() {
      _isLoadingHighScore = true;
      _isNewRecordDisplayed = false; // <<< NEW: Reset on each initialization
    });

    await _loadPlayerUsername();

    if (_playerUsername != null && _playerUsername!.isNotEmpty) {
      await _checkAndRecordHighScore();
    } else {
      print("Player username not found. High score might not be up-to-date.");
      if (mounted) {
        setState(() {
          _isLoadingHighScore = false;
        });
      }
    }
  }

  Future<void> _loadPlayerUsername() async {
    _playerUsername = await PlayerPreferences.getPlayerUsername();
  }

  Future<void> _checkAndRecordHighScore() async {
    final int currentScore = widget.score;
    bool newRecordAchieved = false; // Local flag

    if (_playerUsername == null || _playerUsername!.isEmpty) {
      if (mounted) setState(() => _isLoadingHighScore = false);
      return;
    }
    if (currentScore < 0) {
      if (mounted) {
        setState(() {
          _isLoadingHighScore = false;
        });
      }
      return;
    }

    String lowercaseUsername = _playerUsername!.toLowerCase();
    DocumentReference userHighScoreDoc =
    _firestore.collection('high_scores').doc(lowercaseUsername);

    try {
      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(userHighScoreDoc);
        int previousBestScore = 0;
        bool existingDoc = snapshot.exists;

        if (existingDoc) {
          previousBestScore = (snapshot.data() as Map<String, dynamic>)['score'] ?? 0;
        }

        if (!existingDoc || currentScore > previousBestScore) {
          transaction.set(userHighScoreDoc, {
            'score': currentScore,
            'original_username': _playerUsername,
            'timestamp': FieldValue.serverTimestamp(),
          });
          newRecordAchieved = true; // <<< NEW: Mark that a new record was made
          if (mounted) {
            // SetState for _displayHighScore will be outside or in finally
            // _displayHighScore = currentScore; // Update display immediately
          }
        } else {
          // No new record
        }
        // Update _displayHighScore regardless of new record or not within the transaction
        // if it's based on previousBestScore or currentScore
        if (mounted) {
          _displayHighScore = newRecordAchieved ? currentScore : previousBestScore;
        }

      });

      // After transaction, update the state based on whether a new record was set
      if (mounted) {
        setState(() {
          _isNewRecordDisplayed = newRecordAchieved;
          // _displayHighScore is already set within the transaction's setState
          // or if not, ensure it's set here based on logic.
          // If transaction failed, _displayHighScore would remain widget.highScore or last successful.
        });
      }

    } catch (e) {
      print("Error in high score transaction: $e");
      // UI will show the _displayHighScore which was initialized or last successfully set
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingHighScore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text('GAME OVER', style: TextStyle(fontSize: 40, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                const SizedBox(height: 30),
                Text('YOUR SCORE', style: TextStyle(fontSize: 20, color: Colors.grey[700], fontWeight: FontWeight.w600)),
                Text('${widget.score}', style: const TextStyle(fontSize: 48, color: Colors.deepPurple, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Text('HIGH SCORE', style: TextStyle(fontSize: 20, color: Colors.grey[700], fontWeight: FontWeight.w600)),
                _isLoadingHighScore
                    ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: SizedBox(height: 36, width: 24, child: CircularProgressIndicator(strokeWidth: 3)),
                )
                    : Text(
                  '$_displayHighScore',
                  style: const TextStyle(fontSize: 36, color: Colors.orange, fontWeight: FontWeight.bold),
                ),

                // <<< NEW: Conditionally display "NEW RECORD" message >>>
                if (!_isLoadingHighScore && _isNewRecordDisplayed)
                  Padding(
                    padding: const EdgeInsets.only(top: 15.0), // Add some space above
                    child: Text(
                      '🏆 NEW RECORD! 🏆',
                      style: TextStyle(
                        fontSize: 24,
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Adjust spacing: if new record message is shown, less extra space is needed.
                // If not, add more space to keep button position somewhat consistent.
                SizedBox(height: _isNewRecordDisplayed ? 15 : 30),


                ElevatedButton(
                  onPressed: widget.onRestart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('RESTART GAME'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

