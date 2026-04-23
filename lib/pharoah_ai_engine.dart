import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;

class PharoahAiEngine {
  
  /// MAIN ENTRY POINT (Ye function bahar se call hoga)
  static Future<Map<String, dynamic>> processBills(List<File> images, String mode) async {
    final prefs = await SharedPreferences.getInstance();
    String apiKey = prefs.getString('geminiKey') ?? "";
    bool autoOffline = prefs.getBool('autoOffline') ?? true;

    // --- CASE 1: TRY ONLINE CLOUD AI (GEMINI) ---
    if (apiKey.isNotEmpty) {
      try {
        debugPrint("Starting Cloud AI (Gemini)...");
        return await _runGeminiVision(images, apiKey);
      } catch (e) {
        debugPrint("Cloud AI Failed: $e");
        if (!autoOffline) {
          throw Exception("Cloud AI Failed and Auto-Fallback is OFF. Please check internet.");
        }
        debugPrint("Falling back to Offline AI...");
      }
    }
    
    // --- CASE 2: OFFLINE AI (ML KIT) ---
    debugPrint("Starting Offline AI (ML Kit)...");
    return await _runOfflineMLKit(images);
  }

  // =========================================================================
  // 1. OFFLINE ENGINE (Google ML Kit)
  // =========================================================================
  static Future<Map<String, dynamic>> _runOfflineMLKit(List<File> images) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    String fullText = "";

    // Har ek photo ka text nikalna
    for (var img in images) {
      final inputImage = InputImage.fromFile(img);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      fullText += "${recognizedText.text}\n---PAGE BREAK---\n";
    }
    textRecognizer.close();

    // Offline me exact table nikalna mushkil hota hai, isliye hum raw text bhejenge
    // jisse user screen par dekh kar type kar sake.
    return {
      "status": "OFFLINE",
      "partyName": "Needs Manual Entry",
      "billNo": "N/A",
      "date": DateTime.now().toString(),
      "items": [],
      "raw_text": fullText, // User reference ke liye
      "message": "Processed Offline. Please verify details manually."
    };
  }

  // =========================================================================
  // 2. ONLINE ENGINE (Google Gemini 1.5 Flash)
  // =========================================================================
  static Future<Map<String, dynamic>> _runGeminiVision(List<File> images, String apiKey) async {
    const String url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent";
    
    // Convert first image to Base64 (Filhal Gemini 1 image per request acche se process karta hai)
    List<int> imageBytes = await images.first.readAsBytes();
    String base64Image = base64Encode(imageBytes);

    // The Master Prompt (AI ko samjhana ki kya chahiye)
    String prompt = """
      You are an expert ERP Data Extractor. Analyze this invoice image.
      Extract the following information and return ONLY a JSON object (no markdown, no extra text):
      {
        "partyName": "Vendor or Customer Name",
        "billNo": "Invoice Number",
        "date": "Invoice Date",
        "items": [
          {
            "name": "Item Name",
            "qty": Total quantity (number),
            "rate": Unit rate or price (number),
            "total": Total amount for this item (number)
          }
        ]
      }
    """;

    // Build the request payload
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

    // Call API
    final response = await http.post(
      Uri.parse("$url?key=$apiKey"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      String rawJson = data['candidates'][0]['content']['parts'][0]['text'];
      
      // Clean the string if Gemini wrapped it in markdown ```json ... ```
      rawJson = rawJson.replaceAll("```json", "").replaceAll("```", "").trim();
      
      Map<String, dynamic> result = jsonDecode(rawJson);
      result["status"] = "ONLINE";
      result["raw_text"] = "Processed via Gemini Cloud";
      result["message"] = "High Accuracy Cloud Extraction Complete.";
      return result;
    } else {
      throw Exception("Gemini API Error: ${response.statusCode}");
    }
  }
}
