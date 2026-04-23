import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;

class PharoahAiEngine {
  
  static Future<Map<String, dynamic>> processBills(List<File> images, String mode) async {
    final prefs = await SharedPreferences.getInstance();
    String apiKey = prefs.getString('geminiKey') ?? "";
    bool autoOffline = prefs.getBool('autoOffline') ?? true;

    String geminiErrorLog = "";

    // --- CLOUD AI (GEMINI) ---
    if (apiKey.trim().isNotEmpty) {
      try {
        debugPrint("Starting Cloud AI (Gemini)...");
        return await _runGeminiVision(images, apiKey, mode);
      } catch (e) {
        debugPrint("Cloud AI Failed: $e");
        geminiErrorLog = e.toString(); 
        
        if (!autoOffline) {
          throw Exception("Cloud AI Failed: $geminiErrorLog");
        }
      }
    } 
    
    // --- OFFLINE AI (ML KIT FALLBACK) ---
    debugPrint("Starting Offline AI...");
    return await _runOfflineMLKit(images, geminiErrorLog);
  }

  // =========================================================================
  // 1. OFFLINE ENGINE (ML Kit)
  // =========================================================================
  static Future<Map<String, dynamic>> _runOfflineMLKit(List<File> images, String previousError) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    String fullText = "";

    try {
      for (var img in images) {
        final inputImage = InputImage.fromFile(img);
        final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
        fullText += "${recognizedText.text}\n\n";
      }
    } catch (e) {
      textRecognizer.close();
      throw Exception("Offline OCR Failed: $e");
    }
    
    textRecognizer.close();

    String msg = "Processed Offline. Read raw text below.";
    if (previousError.isNotEmpty) {
      msg = "Gemini AI Failed ($previousError). Switched to Offline Mode.";
    }

    return {
      "status": "OFFLINE",
      "partyName": "Manual Entry",
      "billNo": "N/A",
      "date": DateTime.now().toString(),
      "items": [],
      "raw_text": fullText.isEmpty ? "No readable text found." : fullText,
      "message": msg
    };
  }

  // =========================================================================
  // 2. ONLINE ENGINE (Gemini 1.5 Flash Latest)
  // =========================================================================
  static Future<Map<String, dynamic>> _runGeminiVision(List<File> images, String apiKey, String mode) async {
    // FIXED: Changed model name to 'gemini-1.5-flash-latest' which is globally supported
    const String url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent";
    
    List<int> imageBytes = await images.first.readAsBytes();
    String base64Image = base64Encode(imageBytes);

    String prompt = """
      Analyze this invoice image. Extract data and return ONLY a valid JSON object. Do not use Markdown, do not say 'Here is the JSON'.
      Must use EXACTLY these keys:
      {
        "partyName": "Vendor Name",
        "billNo": "Invoice Number",
        "date": "Invoice Date",
        "items": [
          {
            "name": "Item Name",
            "qty": 10,
            "rate": 150.5,
            "total": 1505.0
          }
        ]
      }
    """;

    Map<String, dynamic> payload = {
      "contents": [
        {
          "parts": [
            {"text": prompt},
            {
              "inline_data": {
                "mime_type": "image/jpeg",
                "data": base64Image
              }
            }
          ]
        }
      ]
    };

    final response = await http.post(
      Uri.parse("$url?key=$apiKey"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      String rawText = data['candidates'][0]['content']['parts'][0]['text'];
      
      int startIndex = rawText.indexOf('{');
      int endIndex = rawText.lastIndexOf('}');
      
      if (startIndex != -1 && endIndex != -1) {
        String cleanJson = rawText.substring(startIndex, endIndex + 1);
        Map<String, dynamic> result = jsonDecode(cleanJson);
        result["status"] = "ONLINE";
        result["message"] = "High Accuracy Cloud Extraction Complete.";
        return result;
      } else {
        throw Exception("Invalid Format from AI.");
      }
    } else {
      var errorData = jsonDecode(response.body);
      throw Exception("${errorData['error']['message']}");
    }
  }
}
