import 'package:shared_preferences/shared_preferences.dart';

class PlayerPreferences {
  // Key for storing the player's unique username
  static const _keyPlayerUsername = 'playerUsername';

  // Method to save the player's unique username
  static Future<void> setPlayerUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPlayerUsername, username);
    print("Player username '$username' saved to SharedPreferences.");
  }

  // Method to get the player's unique username
  static Future<String?> getPlayerUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(_keyPlayerUsername);
    if (username != null) {
      print("Retrieved player username '$username' from SharedPreferences.");
    } else {
      print("No player username found in SharedPreferences.");
    }
    return username;
  }

  // Optional: Method to clear the player's username (e.g., for testing)
  static Future<void> clearPlayerUsername() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPlayerUsername);
    print("Player username cleared from SharedPreferences.");
  }
}
