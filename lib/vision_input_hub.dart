import 'dart:io';
import 'package:flutter/material.dart';

class VisionInputHub extends StatefulWidget {
  final String mode; // "PURCHASE" ya "SALE"
  const VisionInputHub({super.key, required this.mode});

  @override
  State<VisionInputHub> createState() => _VisionInputHubState();
}

class _VisionInputHubState extends State<VisionInputHub> {
  // Simulating scanned pages list (Filhal empty, baad me actual files aayengi)
  List<String> scannedPages = []; 

  @override
  Widget build(BuildContext context) {
    bool isPurchase = widget.mode == "PURCHASE";
    Color themeColor = isPurchase ? Colors.orange.shade800 : Colors.blue.shade900;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21), // Dark futuristic background
      appBar: AppBar(
        title: Text("${widget.mode} VISION HUB", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // --- 1. SCANNING ANIMATION AREA ---
          Expanded(
            flex: 3,
            child: _buildScannerVisuals(themeColor),
          ),

          // --- 2. MAIN INPUT BUTTONS ---
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLargeInputBtn(
                    icon: Icons.camera_enhance_rounded,
                    label: "SMART CAMERA",
                    sub: "Flash & Auto-Focus Enabled",
                    color: themeColor,
                    onTap: () {
                      // TODO: Open Native Camera Logic
                      setState(() => scannedPages.add("Page ${scannedPages.length + 1}"));
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSmallInputBtn(Icons.photo_library, "GALLERY", Colors.purple),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildSmallInputBtn(Icons.file_present_rounded, "DOCUMENTS", Colors.teal),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // --- 3. THUMBNAIL TRAY (The Scanned Pages) ---
          _buildThumbnailTray(themeColor),
        ],
      ),
    );
  }

  Widget _buildScannerVisuals(Color color) {
    return Center(
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.5), width: 2),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Stack(
          children: [
            // Scanner Line Animation Placeholder
            Align(
              alignment: Alignment.center,
              child: Icon(Icons.qr_code_scanner_rounded, size: 80, color: color.withOpacity(0.3)),
            ),
            // Corner Accents
            _buildCorner(0, 0, color), _buildCorner(0, 1, color),
            _buildCorner(1, 0, color), _buildCorner(1, 1, color),
          ],
        ),
      ),
    );
  }

  Widget _buildCorner(double top, double left, Color color) {
    return Positioned(
      top: top == 0 ? 0 : null, bottom: top == 1 ? 0 : null,
      left: left == 0 ? 0 : null, right: left == 1 ? 0 : null,
      child: Container(width: 20, height: 20, decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: top == 0 ? color : Colors.transparent, width: 4),
          bottom: BorderSide(color: top == 1 ? color : Colors.transparent, width: 4),
          left: BorderSide(color: left == 0 ? color : Colors.transparent, width: 4),
          right: BorderSide(color: left == 1 ? color : Colors.transparent, width: 4),
        )
      )),
    );
  }

  Widget _buildLargeInputBtn({required IconData icon, required String label, required String sub, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 20)],
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 45),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
                Text(sub, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallInputBtn(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildThumbnailTray(Color color) {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
      ),
      padding: const EdgeInsets.all(25),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${scannedPages.length} PAGES READY", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
              if (scannedPages.isNotEmpty)
                TextButton(onPressed: () => setState(() => scannedPages.clear()), child: const Text("CLEAR ALL", style: TextStyle(color: Colors.red, fontSize: 10))),
            ],
          ),
          const SizedBox(height: 15),
          Expanded(
            child: scannedPages.isEmpty 
              ? Center(child: Text("No pages captured yet", style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 12)))
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: scannedPages.length,
                  itemBuilder: (c, i) => _buildPageThumbnail(i, color),
                ),
          ),
          if (scannedPages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: color, 
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 45),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                ),
                onPressed: () {
                  // TODO: Navigate to AI Engine
                },
                child: const Text("PROCEED TO AI ANALYSIS", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildPageThumbnail(int index, Color color) {
    return Container(
      width: 60,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color),
      ),
      child: Stack(
        children: [
          Center(child: Text("${index + 1}", style: TextStyle(color: color, fontWeight: FontWeight.bold))),
          Positioned(
            top: 2, right: 2,
            child: GestureDetector(
              onTap: () => setState(() => scannedPages.removeAt(index)),
              child: const Icon(Icons.cancel, size: 16, color: Colors.white70),
            ),
          )
        ],
      ),
    );
  }
}
