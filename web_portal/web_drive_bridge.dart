import "dart:convert";
import "package:shared_preferences/shared_preferences.dart";

class WebDriveBridge {
  static const String clientId = "1095984490170-1h676oimdshmep8b87dni1maii4mmq8q.apps.googleusercontent.com";
  static const String prefEmailKey = "GOOGLE_USER_EMAIL";
  static const String prefTokenKey = "GOOGLE_ACCESS_TOKEN";

  static Future<String> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(prefEmailKey) ?? "";
  }

  static Future<void> saveGoogleSession(String email, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefEmailKey, email.trim().toLowerCase());
    await prefs.setString(prefTokenKey, token.trim());
  }

  static Future<void> logoutGoogle() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefEmailKey);
    await prefs.remove(prefTokenKey);
  }

  static Future<Map<String, dynamic>?> fetchDatabaseFromDrive() async {
    final prefs = await SharedPreferences.getInstance();
    String? localBackup = prefs.getString("WEB_LOCAL_DATABASE");
    if (localBackup != null && localBackup.isNotEmpty) {
      return Map<String, dynamic>.from(jsonDecode(localBackup));
    }
    return null;
  }

  static Future<bool> saveDatabaseToDrive(Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("WEB_LOCAL_DATABASE", jsonEncode(payload));
    return true;
  }
}
