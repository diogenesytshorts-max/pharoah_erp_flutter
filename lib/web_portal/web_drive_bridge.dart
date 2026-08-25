import "dart:convert";
import "package:flutter/foundation.dart";
import "package:http/http.dart" as http;
import "package:shared_preferences/shared_preferences.dart";

class WebDriveBridge {
  static const String prefWebhookKey = "WEB_CLOUD_SCRIPT_URL";
  static const String prefEmailKey = "WEB_CLOUD_USER_EMAIL";

  static Future<String> getWebhookUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(prefWebhookKey) ?? "";
  }

  static Future<String> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(prefEmailKey) ?? "";
  }

  static Future<void> saveCloudConfig(String url, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefWebhookKey, url.trim());
    await prefs.setString(prefEmailKey, email.trim().toLowerCase());
  }

  static Future<Map<String, dynamic>?> fetchDatabaseFromDrive() async {
    final url = await getWebhookUrl();
    final email = await getUserEmail();
    if (url.isEmpty || !url.startsWith("http")) return null;
    try {
      final fetchUrl = "$url?action=GET_DATABASE&tenantEmail=${Uri.encodeComponent(email)}";
      final response = await http.get(Uri.parse(fetchUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["status"] == "SUCCESS" && data["payload"] != null) {
          return Map<String, dynamic>.from(data["payload"]);
        }
      }
    } catch (e) { debugPrint("Drive Pull Error: $e"); }
    return null;
  }

  static Future<bool> saveDatabaseToDrive(Map<String, dynamic> payload) async {
    final url = await getWebhookUrl();
    final email = await getUserEmail();
    if (url.isEmpty || !url.startsWith("http")) return false;
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "action": "SAVE_DATABASE",
          "tenantEmail": email,
          "timestamp": DateTime.now().toIso8601String(),
          "payload": payload,
        }),
      );
      return response.statusCode == 200 || response.statusCode == 302;
    } catch (e) { debugPrint("Drive Push Error: $e"); return false; }
  }
}
