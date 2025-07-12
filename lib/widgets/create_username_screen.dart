import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Adjust the path if your PlayerPreferences file is located differently
import 'package:dashfallgame/player_prefs.dart';
// Adjust the path to your StartScreen file
import 'package:dashfallgame/widgets/start_screen.dart';

// Imports are above this line

class CreateUsernameScreen extends StatefulWidget {
  const CreateUsernameScreen({super.key});

  @override
  State<CreateUsernameScreen> createState() => _CreateUsernameScreenState();
}

class _CreateUsernameScreenState extends State<CreateUsernameScreen> {
  // --- Controllers, Keys, and State Variables ---
  final _usernameController = TextEditingController(); // To manage the text in the TextField
  final _formKey = GlobalKey<FormState>(); // For validating the input form
  bool _isLoading = false; // To show a loading indicator during Firestore check
  String? _usernameError; // To display error messages like "username taken"

  // --- Firestore Instance ---
  final FirebaseFirestore _firestore = FirebaseFirestore
      .instance; // Instance to interact with Firestore

  // --- Dispose method to clean up controller ---
  @override
  void dispose() {
    _usernameController.dispose(); // Important to prevent memory leaks
    super.dispose();
  }

  // --- Function to check if username exists in Firestore ---
  Future<bool> _checkUsernameExists(String username) async {
    if (username.isEmpty) return false; // Don't check empty strings

    final String lowercaseUsername = username.toLowerCase();
    print("Checking if username exists: $lowercaseUsername");

    try {
      final doc = await _firestore.collection('usernames').doc(
          lowercaseUsername).get();
      if (doc.exists) {
        print("Username '$lowercaseUsername' exists in Firestore.");
      } else {
        print("Username '$lowercaseUsername' does NOT exist in Firestore.");
      }
      return doc.exists;
    } catch (e) {
      print("Error checking username existence: $e");
      // Consider how to handle errors here. For now, we'll assume it doesn't exist
      // to prevent users from being stuck if there's a temporary network issue,
      // but you might want more sophisticated error handling for a production app.
      // For example, you could rethrow the error and display it to the user.
      _usernameError =
      "Error checking username. Please try again."; // Set error message
      // No need to call setState here as this function is called from _createUsername which handles state.
      return true; // Treat error as "exists" to prevent accidental overwrite if check fails
    }
  }


  // --- Function to attempt to create the username ---
  Future<void> _createUsername() async {
    // First, validate the form input based on the TextFormField's validator
    if (!_formKey.currentState!.validate()) {
      // If validator returns a string (error message), validation failed.
      return;
    }

    // If form is valid, proceed
    setState(() {
      _isLoading = true;
      _usernameError = null; // Clear any previous error message
    });

    final username = _usernameController.text.trim();
    final lowercaseUsername = username.toLowerCase();

    try {
      bool exists = await _checkUsernameExists(
          username); // Use original casing for the check if you like, or lowercase

      if (exists) {
        // _checkUsernameExists might have set _usernameError if the check itself failed.
        // If _usernameError is still null here, it means the username genuinely exists.
        setState(() {
          if (_usernameError ==
              null) { // Only set if not already set by _checkUsernameExists's error handling
            _usernameError = 'Username already taken. Please try another.';
          }
          _isLoading = false;
        });
        return;
      }

      // If username doesn't exist, create it in Firestore.
      // We use the lowercase username as the document ID in the 'usernames' collection
      // to inherently enforce uniqueness at the Firestore level.
      // You might store more data here if needed, like registration timestamp or original casing.
      await _firestore.collection('usernames').doc(lowercaseUsername).set({
        'original_username': username,
        // Store the original casing for display purposes
        'createdAt': FieldValue.serverTimestamp(),
        // Useful metadata
      });

      // Save the chosen username (e.g., original casing) to local preferences
      await PlayerPreferences.setPlayerUsername(username);
      print("Username '$username' created and saved to PlayerPreferences.");

      // Navigate to the StartScreen if the widget is still mounted
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const StartScreen()),
        );
      }
    } catch (e) {
      print("Error during _createUsername: $e");
      setState(() {
        _usernameError =
        'An error occurred while creating username. Please try again.';
        _isLoading = false;
      });
    }
  }


  // --- TODO: Add build method (UI) ---

  // Placeholder for the build method for now to avoid errors
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Create Your Player Username'),
        backgroundColor: const Color(0xFF007AFF),
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Choose a unique username',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF007AFF),
                    letterSpacing: 1.1,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  '(This will be shown on leaderboards)',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _usernameController,
                  textAlign: TextAlign.center,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (value) {
                    if (value == null || value
                        .trim()
                        .isEmpty) {
                      return 'Please enter a username';
                    }
                    final trimmedValue = value.trim();
                    if (trimmedValue.length < 3) {
                      return 'Username too short (min 3 chars)';
                    }
                    if (trimmedValue.length > 20) {
                      return 'Username too long (max 20 chars)';
                    }
                    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(trimmedValue)) {
                      return 'Letters, numbers, and underscores only';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    if (_usernameError != null) {
                      setState(() {
                        _usernameError = null;
                      });
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'E.g., DashKing123',
                    filled: true,
                    fillColor: const Color(0xFFE6F0FF),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    errorText: _usernameError,
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                          color: Color(0xFF007AFF), width: 2),
                    ),
                    hintStyle: TextStyle(
                      color: Colors.blueGrey[300],
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF007AFF),
                  ),
                ),
                const SizedBox(height: 36),
                _isLoading
                    ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF007AFF)),
                )
                    : ElevatedButton(
                  onPressed: _createUsername,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  child: const Text(
                    'Save Username & Play',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
