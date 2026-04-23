import 'package:flutter/material.dart';
import 'ai_setup_view.dart'; // Naya configuration page link karne ke liye

class PharoahAiVision extends StatefulWidget {
  const PharoahAiVision({super.key});

  @override
  State<PharoahAiVision> createState() => _PharoahAiVisionState();
}

class _PharoahAiVisionState extends State<PharoahAiVision> {
  // Baad me isse actual settings se link karenge
  bool isOnlineActive = true; 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Pharoah AI Vision", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_suggest_rounded),
            tooltip: "AI Configuration",
            onPressed: () {
              // Nayi Configuration Screen par bhejne ke liye
              Navigator.push(context, MaterialPageRoute(builder: (c) => const AiSetupView()));
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- AI STATUS INDICATOR ---
            _buildStatusCard(),

            const SizedBox(height: 30),
            const Text(
              "SELECT SCANNING MODE",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1.5),
            ),
            const SizedBox(height: 15),

            // --- PURCHASE AI BUTTON ---
            _buildActionCard(
              title: "PURCHASE AI",
              subtitle: "Scan Vendor bills to auto-fill Stock Inward.",
              icon: Icons.document_scanner_rounded,
              gradient: const LinearGradient(colors: [Color(0xFFFF9800), Color(0xFFF44336)]),
              onTap: () {
                // Future Step: Start Camera for Purchase
              },
            ),

            const SizedBox(height: 20),

            // --- SALE AI BUTTON ---
            _buildActionCard(
              title: "SALE AI",
              subtitle: "Quick scan customer orders or invoices.",
              icon: Icons.bolt_rounded,
              gradient: const LinearGradient(colors: [Color(0xFF2196F3), Color(0xFF0D47A1)]),
              onTap: () {
                // Future Step: Start Camera for Sale
              },
            ),

            const SizedBox(height: 40),
            
            // --- QUICK TIP ---
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.indigo.withOpacity(0.1))
              ),
              child: const Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.orange),
                  SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      "Tip: Keep the bill flat and ensure good lighting for high AI accuracy.",
                      style: TextStyle(fontSize: 11, color: Colors.blueGrey),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isOnlineActive ? Colors.green.shade50 : Colors.grey.shade100,
            radius: 25,
            child: Icon(
              isOnlineActive ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
              color: isOnlineActive ? Colors.green : Colors.grey,
            ),
          ),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isOnlineActive ? "PHAROAH AI - ONLINE" : "PHAROAH AI - OFFLINE",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              Text(
                isOnlineActive ? "Smart Hybrid Mode Active" : "Basic Offline Mode Active",
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(25),
      child: Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(icon, color: Colors.white, size: 35),
          ],
        ),
      ),
    );
  }
}
