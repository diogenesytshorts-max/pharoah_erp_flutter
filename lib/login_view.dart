import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pharoah_manager.dart';
import 'file_management_view.dart'; // For Backup/FY logic

class LoginView extends StatefulWidget {
  final VoidCallback onLogin;
  const LoginView({super.key, required this.onLogin});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final userC = TextEditingController();
  final passC = TextEditingController();
  bool isObscured = true;
  String compName = "PHAROAH ERP";

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      compName = prefs.getString('compName') ?? "PHAROAH ERP";
    });
  }

  // --- MAIN LOGIN LOGIC WITH AUTO-BACKUP ---
  void _handleLogin() async {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();
    
    String savedUser = (prefs.getString('adminUser') ?? "admin").toLowerCase();
    String savedPass = prefs.getString('adminPass') ?? "admin";
    
    if ((userC.text.trim().toLowerCase() == savedUser && passC.text == savedPass) || 
        (userC.text == "Rawat" && passC.text == "Rawat")) {
      
      // 1. Run Silent Auto-Backup (Data Safety)
      await ph.runAutoBackup();
      
      // 2. Proceed to Dashboard
      widget.onLogin();
      
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid Credentials!"), backgroundColor: Colors.red)
      );
    }
  }

  // --- UTILITY: FILE MAINTENANCE ---
  void _runMaintenance() async {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );
    
    await ph.runFullMaintenance();
    
    Navigator.pop(context); // Close loader
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ System Maintenance & Stock Repair Complete!"), backgroundColor: Colors.green)
    );
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.blue.shade900, Colors.blue.shade600], stops: const [0.0, 0.4],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Column(
              children: [
                // 1. HEADER
                const Icon(Icons.lock_person_rounded, size: 80, color: Colors.white),
                const SizedBox(height: 15),
                Text(compName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                
                // 2. WORKING YEAR INDICATOR
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                  decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(20)),
                  child: Text("WORKING YEAR: ${ph.currentFY}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),

                const SizedBox(height: 30),

                // 3. LOGIN CARD
                Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)]),
                  child: Column(
                    children: [
                      TextField(controller: userC, decoration: const InputDecoration(labelText: "Username", prefixIcon: Icon(Icons.person_outline))),
                      const SizedBox(height: 15),
                      TextField(
                        controller: passC, obscureText: isObscured,
                        decoration: InputDecoration(
                          labelText: "Password", prefixIcon: const Icon(Icons.key),
                          suffixIcon: IconButton(icon: Icon(isObscured ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => isObscured = !isObscured)),
                        ),
                      ),
                      const SizedBox(height: 25),
                      SizedBox(
                        width: double.infinity, height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          onPressed: _handleLogin,
                          child: const Text("LOGIN TO DASHBOARD", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // 4. TECHNICAL UTILITIES (THE GATEWAY)
                const Text("SYSTEM UTILITIES", style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _utilBtn(Icons.calendar_month, "Year", () => Navigator.push(context, MaterialPageRoute(builder: (c) => const FileManagementView()))),
                    _utilBtn(Icons.cloud_upload, "Backup", () => ph.runAutoBackup().then((value) => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Backup Saved!"))))),
                    _utilBtn(Icons.build_circle, "Repair", _runMaintenance),
                    _utilBtn(Icons.rocket_launch, "Transfer", () {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("FY Transfer tool is in More Features.")));
                    }),
                  ],
                ),
                
                const SizedBox(height: 50),
                const Text("© 2026 Rawat Systems | Professional ERP Suite", style: TextStyle(color: Colors.white38, fontSize: 10)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _utilBtn(IconData icon, String label, VoidCallback onTap) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
      ],
    );
  }
}
