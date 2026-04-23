import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class VisionInputHub extends StatefulWidget {
  final String mode; // "PURCHASE" ya "SALE"
  const VisionInputHub({super.key, required this.mode});

  @override
  State<VisionInputHub> createState() => _VisionInputHubState();
}

class _VisionInputHubState extends State<VisionInputHub> {
  // Ab string ki jagah actual Files save hongi
  List<File> scannedImages = []; 
  final ImagePicker _picker = ImagePicker();

  // --- CAMERA LOGIC ---
  Future<void> _openCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90, // AI ke liye high quality chahiye
      );
      
      if (photo != null) {
        setState(() {
          scannedImages.add(File(photo.path));
        });
      }
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  // --- GALLERY LOGIC (Multi-select enabled) ---
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
      body: Column(
        children: [
          // --- 1. SCANNER VISUALS ---
          Expanded(
            child: Center(
              child: Icon(Icons.qr_code_scanner_rounded, size: 120, color: themeColor.withOpacity(0.3))
            )
          ),

          // --- 2. MAIN BUTTONS ---
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

          // --- 3. THUMBNAIL TRAY ---
          Container(
            height: 190,
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05), 
              borderRadius: const BorderRadius.vertical(top: Radius.circular(40))
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("${scannedImages.length} PAGES READY", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    if (scannedImages.isNotEmpty) 
                      TextButton(
                        onPressed: () => setState(() => scannedImages.clear()), 
                        child: const Text("CLEAR ALL", style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold))
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: scannedImages.isEmpty 
                    ? Center(child: Text("No pages captured yet", style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 12)))
                    : ListView.builder(
                        scrollDirection: Axis.horizontal, 
                        itemCount: scannedImages.length, 
                        itemBuilder: (c, i) => _buildThumb(i, themeColor)
                      ),
                ),
                if (scannedImages.isNotEmpty) 
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor, 
                        foregroundColor: Colors.white, 
                        minimumSize: const Size(double.infinity, 45),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                      ), 
                      onPressed: () {
                        // TODO: Send scannedImages to AI Engine
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sending to AI Engine...")));
                      }, 
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

  // --- UI HELPERS ---

  Widget _buildLargeBtn(String label, String sub, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(25),
      child: Container(
        padding: const EdgeInsets.all(20), 
        decoration: BoxDecoration(
          color: color.withOpacity(0.15), 
          borderRadius: BorderRadius.circular(25), 
          border: Border.all(color: color.withOpacity(0.4), width: 1.5)
        ), 
        child: Row(
          children: [
            Icon(icon, color: color, size: 38), 
            const SizedBox(width: 20), 
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                Text(sub, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
              ],
            )
          ]
        )
      ),
    );
  }

  Widget _buildSmallBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15), 
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05), 
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1))
        ), 
        child: Column(
          children: [
            Icon(icon, color: color, size: 28), 
            const SizedBox(height: 5), 
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1))
          ]
        )
      ),
    );
  }

  Widget _buildThumb(int i, Color color) {
    return Container(
      width: 55, 
      margin: const EdgeInsets.only(right: 12), 
      decoration: BoxDecoration(
        color: Colors.black, 
        borderRadius: BorderRadius.circular(10), 
        border: Border.all(color: color, width: 1.5),
        // Asli Image dikhane ka logic yahan hai:
        image: DecorationImage(
          image: FileImage(scannedImages[i]),
          fit: BoxFit.cover,
          opacity: 0.7
        )
      ), 
      child: Stack(
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: Text("${i + 1}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            )
          ),
          Positioned(
            top: 0, right: 0,
            child: GestureDetector(
              onTap: () => setState(() => scannedImages.removeAt(i)),
              child: Container(
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          )
        ],
      ),
    );
  }
}
