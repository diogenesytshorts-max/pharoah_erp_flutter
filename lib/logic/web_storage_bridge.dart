// FILE: lib/logic/web_storage_bridge.dart
// CROSS-PLATFORM STORAGE BRIDGE (WEB + MOBILE SAFE)

import 'dart:convert';
import 'dart:io' if (dart.library.html) 'dart:html' as universal_io;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WebStorageBridge {
  static Future<String> readJsonFile(String relativePath) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('WEB_DB_$relativePath') ?? "";
    } else {
      try {
        final root = await getApplicationDocumentsDirectory();
        final file = universal_io.File('${root.path}/$relativePath');
        if (await file.exists()) {
          return await file.readAsString();
        }
      } catch (e) {
        debugPrint("File read error: $e");
      }
      return "";
    }
  }

  static Future<void> writeJsonFile(String relativePath, String content) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('WEB_DB_$relativePath', content);
    } else {
      try {
        final root = await getApplicationDocumentsDirectory();
        final file = universal_io.File('${root.path}/$relativePath');
        if (!await file.parent.exists()) {
          await file.parent.create(recursive: true);
        }
        await file.writeAsString(content);
      } catch (e) {
        debugPrint("File write error: $e");
      }
    }
  }
}
