// FILE: lib/web_portal/web_drive_bridge.dart
// 100% DIRECT GOOGLE DRIVE REST API v3 (ZERO GOOGLE APPS SCRIPT NEEDED)

import "dart:convert";
import "package:flutter/foundation.dart";
import "package:http/http.dart" as http;
import "package:shared_preferences/shared_preferences.dart";

class WebDriveBridge {
  static const String clientId = "1095984490170-1h676oimdshmep8b87dni1maii4mmq8q.apps.googleusercontent.com";
  static const String prefEmailKey = "GOOGLE_USER_EMAIL";
  static const String prefTokenKey = "GOOGLE_ACCESS_TOKEN";
  static const String prefFolderIdKey = "GOOGLE_DRIVE_FOLDER_ID";
  static const String prefFileIdKey = "GOOGLE_DRIVE_FILE_ID";

  static Future<String> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(prefEmailKey) ?? "";
  }

  static Future<String> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(prefTokenKey) ?? "";
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
    await prefs.remove(prefFolderIdKey);
    await prefs.remove(prefFileIdKey);
  }

  // 📂 Direct REST API: Google Drive me "Pharoah_ERP_Cloud_Database" Folder Dhoondhna ya Banana
  static Future<String?> getOrCreateCloudFolder(String token) async {
    final prefs = await SharedPreferences.getInstance();
    String? cachedId = prefs.getString(prefFolderIdKey);
    if (cachedId != null && cachedId.isNotEmpty) return cachedId;

    try {
      // 1. Search if folder exists
      final searchUrl = Uri.parse(
        "https://www.googleapis.com/drive/v3/files?q=name=Pharoah_ERP_Cloud_Database and mimeType=application/vnd.google-apps.folder and trashed=false",
      );
      final searchRes = await http.get(searchUrl, headers: {"Authorization": "Bearer $token"});

      if (searchRes.statusCode == 200) {
        final data = jsonDecode(searchRes.body);
        if (data["files"] != null && (data["files"] as List).isNotEmpty) {
          String folderId = data["files"][0]["id"];
          await prefs.setString(prefFolderIdKey, folderId);
          return folderId;
        }
      }

      // 2. Create folder if not found
      final createUrl = Uri.parse("https://www.googleapis.com/drive/v3/files");
      final createRes = await http.post(
        createUrl,
        headers: {"Authorization": "Bearer $token", "Content-Type": "application/json"},
        body: jsonEncode({
          "name": "Pharoah_ERP_Cloud_Database",
          "mimeType": "application/vnd.google-apps.folder",
        }),
      );

      if (createRes.statusCode == 200 || createRes.statusCode == 201) {
        final data = jsonDecode(createRes.body);
        String folderId = data["id"];
        await prefs.setString(prefFolderIdKey, folderId);
        return folderId;
      }
    } catch (e) {
      debugPrint("Direct Drive Folder Error: $e");
    }
    return null;
  }

  // 📥 Direct REST API: Database Read Karna (No Script)
  static Future<Map<String, dynamic>?> fetchDatabaseFromDrive() async {
    final token = await getAccessToken();
    if (token.isEmpty) return null;

    try {
      final folderId = await getOrCreateCloudFolder(token);
      if (folderId == null) return null;

      final searchUrl = Uri.parse(
        "https://www.googleapis.com/drive/v3/files?q=name=Pharoah_Main_Database.json and  in parents and trashed=false",
      );
      final searchRes = await http.get(searchUrl, headers: {"Authorization": "Bearer $token"});

      if (searchRes.statusCode == 200) {
        final data = jsonDecode(searchRes.body);
        if (data["files"] != null && (data["files"] as List).isNotEmpty) {
          String fileId = data["files"][0]["id"];
          final downloadUrl = Uri.parse("https://www.googleapis.com/drive/v3/files/$fileId?alt=media");
          final fileRes = await http.get(downloadUrl, headers: {"Authorization": "Bearer $token"});

          if (fileRes.statusCode == 200) {
            return Map<String, dynamic>.from(jsonDecode(fileRes.body));
          }
        }
      }
    } catch (e) {
      debugPrint("Direct Drive Read Error: $e");
    }
    return null;
  }

  // 💾 Direct REST API: Database Save Karna (No Script)
  static Future<bool> saveDatabaseToDrive(Map<String, dynamic> payload) async {
    final token = await getAccessToken();
    if (token.isEmpty) return false;

    try {
      final folderId = await getOrCreateCloudFolder(token);
      if (folderId == null) return false;

      final prefs = await SharedPreferences.getInstance();
      String? fileId = prefs.getString(prefFileIdKey);

      // Check if file exists
      if (fileId == null) {
        final searchUrl = Uri.parse(
          "https://www.googleapis.com/drive/v3/files?q=name=Pharoah_Main_Database.json and  in parents and trashed=false",
        );
        final searchRes = await http.get(searchUrl, headers: {"Authorization": "Bearer $token"});
        if (searchRes.statusCode == 200) {
          final data = jsonDecode(searchRes.body);
          if (data["files"] != null && (data["files"] as List).isNotEmpty) {
            fileId = data["files"][0]["id"];
            await prefs.setString(prefFileIdKey, fileId!);
          }
        }
      }

      final content = jsonEncode(payload);

      if (fileId != null) {
        // Update existing file directly
        final updateUrl = Uri.parse("https://www.googleapis.com/upload/drive/v3/files/$fileId?uploadType=media");
        final updateRes = await http.patch(
          updateUrl,
          headers: {"Authorization": "Bearer $token", "Content-Type": "application/json"},
          body: content,
        );
        return updateRes.statusCode == 200;
      } else {
        // Create new file directly in folder
        final createUrl = Uri.parse("https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart");
        final boundary = "-------314159265358979323846";
        final body = StringBuffer()
          ..write("--$boundary\r\n")
          ..write("Content-Type: application/json; charset=UTF-8\r\n\r\n")
          ..write(jsonEncode({"name": "Pharoah_Main_Database.json", "parents": [folderId]}))
          ..write("\r\n--$boundary\r\n")
          ..write("Content-Type: application/json\r\n\r\n")
          ..write(content)
          ..write("\r\n--$boundary--");

        final createRes = await http.post(
          createUrl,
          headers: {"Authorization": "Bearer $token", "Content-Type": "multipart/related; boundary=$boundary"},
          body: body.toString(),
        );

        if (createRes.statusCode == 200 || createRes.statusCode == 201) {
          final data = jsonDecode(createRes.body);
          await prefs.setString(prefFileIdKey, data["id"]);
          return true;
        }
      }
    } catch (e) {
      debugPrint("Direct Drive Save Error: $e");
    }
    return false;
  }
}
