import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'pharoah_ai_engine.dart'; // AI Engine ko import kiya
import 'ai_verification_dashboard.dart'; // Naye Dashboard ko import kiya

class VisionInputHub extends StatefulWidget {
  final String mode; // "PURCHASE" ya "SALE"
  const VisionInputHub({super.key, required this.mode});

  @override
  State<VisionInputHub> createState() => _VisionInputHubState();
}

class _VisionInputHubState extends State<VisionInputHub> {
  List<File> scannedImages = []; 
  final ImagePicker _picker = ImagePicker();
  bool isAnalyzing = false; // Loading animation ke liye

  // --- CAMERA LOGIC ---
  Future<void> _openCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90, 
      );
      if (photo != null) {
        setState(() => scannedImages.add(File(photo.path)));
      }
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  // --- GALLERY LOGIC ---
  Future<void> _openGallery() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 90,
      );
      if (images.isNotEmpty) {
        setState(() {
          for (var img in images) {
            scannedImages.add(File(img.path));
          }
        });
      }
    } catch (e) {
      debugPrint("Gallery Error: $e");
    }
  }

  // --- THE MAGIC BUTTON: Run AI ---
  Future<void> _startAiAnalysis() async {
    setState(() => isAnalyzing = true); // Loading shuru

    try {
      // 1. Send photos to Pharoah Brain
      Map<String, dynamic> result = await PharoahAiEngine.processBills(scannedImages, widget.mode);

      // 2. Loading roko
      setState(() => isAnalyzing = false);

      // 3. Dashboard par bhejo
      if (mounted) {
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (c) => AiVerificationDashboard(
            images: scannedImages,
            aiData: result,
            mode: widget.mode,
          ))
        );
      }
    } catch (e) {
      setState(() => isAnalyzing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("AI Failed: $e"), 
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Color themeColor = widget.mode == "PURCHASE" ? Colors.orange.shade800 : Colors.blue.shade900;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21), 
      appBar: AppBar(
        title: Text("${widget.mode} VISION HUB", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: isAnalyzing 
        ? _buildLoadingScreen(themeColor) // NAYA: Futuristic loading screen
        : Column(
            children: [
              Expanded(child: Center(child: Icon(Icons.qr_code_scanner_rounded, size: 120, color: themeColor.withOpacity(0.3)))),
              Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  children: [
                    _buildLargeBtn("SMART CAMERA", "Flash & Auto-Focus Enabled", Icons.camera_enhance_rounded, themeColor, _openCamera),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: _buildSmallBtn("GALLERY", Icons.photo_library, Colors.purple, _openGallery)),
                        const SizedBox(width: 15),
                        Expanded(child: _buildSmallBtn("FILES/PDF", Icons.file_present_rounded, Colors.teal, () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PDF Support coming soon!")));
                        })),
                      ],
                    ),
                  ],
                ),
              ),

              // --- TRAY SECTION ---
              Container(
                height: 190,
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: const BorderRadius.vertical(top: Radius.circular(40))),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("${scannedImages.length} PAGES READY", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        if (scannedImages.isNotEmpty) 
                          TextButton(onPressed: () => setState(() => scannedPages.clear()), child: const Text("CLEAR ALL", style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: scannedImages.isEmpty 
                        ? Center(child: Text("No pages captured yet", style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 12)))
                        : ListView.builder(scrollDirection: Axis.horizontal, itemCount: scannedImages.length, itemBuilder: (c, i) => _buildThumb(i, themeColor)),
                    ),
                    if (scannedImages.isNotEmpty) 
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: themeColor, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 45), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), 
                          onPressed: _startAiAnalysis, // <--- MAGIC BUTTON LINKED
                          child: const Text("RUN AI ANALYSIS", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1))
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
    );
  }

  // --- FUTURISTIC LOADING SCREEN ---
  Widget _buildLoadingScreen(Color color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: color),
          const SizedBox(height: 25),
          const Text("PHAROAH AI IS THINKING...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 10),
          Text("Extracting items, calculating taxes...", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
        ],
      ),
    );
  }

  // UI Helpers
  Widget _buildLargeBtn(String label, String sub, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(25),
      child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(25), border: Border.all(color: color.withOpacity(0.4), width: 1.5)), child: Row(children: [Icon(icon, color: color, size: 38), const SizedBox(width: 20), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)), Text(sub, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10))])])),
    );
  }

  Widget _buildSmallBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(20),
      child: Container(padding: const EdgeInsets.symmetric(vertical: 15), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.1))), child: Column(children: [Icon(icon, color: color, size: 28), const SizedBox(height: 5), Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1))])),
    );
  }

  Widget _buildThumb(int i, Color color) {
    return Container(
      width: 55, margin: const EdgeInsets.only(right: 12), 
      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10), border: Border.all(color: color, width: 1.5), image: DecorationImage(image: FileImage(scannedImages[i]), fit: BoxFit.cover, opacity: 0.7)), 
      child: Stack(children: [
        Center(child: Container(padding: const EdgeInsets.all(5), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: Text("${i + 1}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)))),
        Positioned(top: 0, right: 0, child: GestureDetector(onTap: () => setState(() => scannedImages.removeAt(i)), child: Container(decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Icon(Icons.close, size: 16, color: Colors.white))))
      ]),
    );
  }
}
