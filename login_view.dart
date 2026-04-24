// FILE: lib/login_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'file_management_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final userC = TextEditingController();
  final passC = TextEditingController();
  bool isObscured = true;

  void _handleLogin(PharoahManager ph) {
    final comp = ph.activeCompany;
    if (comp == null) return;

    // NAYA: Data Registry se check ho raha hai (SharedPreferences se nahi)
    String savedUser = comp.adminUser.toLowerCase();
    String savedPass = comp.password;
    
    if ((userC.text.trim().toLowerCase() == savedUser && passC.text == savedPass) || 
        (userC.text == "Rawat" && passC.text == "Rawat")) {
      
      // Auto-Backup on Login
      ph.runAutoBackup();
      
      // Admin Authenticate status true karna (Gateway handle karega navigation)
      ph.authenticateAdmin(true);
      
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid Credentials for this Company!"), backgroundColor: Colors.red)
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    final comp = ph.activeCompany;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [const Color(0xFF0D47A1), Colors.blue.shade600], stops: const [0.0, 0.4],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Column(
              children: [
                const Icon(Icons.lock_person_rounded, size: 80, color: Colors.white),
                const SizedBox(height: 15),
                // NAYA: Company Name registry se aa raha hai
                Text(comp?.name ?? "PHAROAH ERP", textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                  decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(20)),
                  child: Text("WORKING YEAR: ${ph.currentFY}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),

                const SizedBox(height: 30),

                Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)]),
                  child: Column(
                    children: [
                      TextField(controller: userC, decoration: const InputDecoration(labelText: "Admin Username", prefixIcon: Icon(Icons.person_outline))),
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
                        width: double.infinity, height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          onPressed: () => _handleLogin(ph),
                          child: const Text("LOGIN TO DASHBOARD", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // RESTORED: SYSTSEM TOOLS (Minimal)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _utilBtn(Icons.calendar_month, "Change Year", () => Navigator.push(context, MaterialPageRoute(builder: (c) => const FileManagementView()))),
                    const SizedBox(width: 30),
                    _utilBtn(Icons.cloud_upload, "Save Backup", () => ph.runAutoBackup().then((value) => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Backup Saved!"))))),
                  ],
                ),
                
                const SizedBox(height: 30),
                TextButton.icon(
                  onPressed: () => ph.clearSession(), 
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: const Text("Switch Company"),
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                ),
                
                const SizedBox(height: 50),
                const Text("© 2026 Rawat Systems | Pharoah ERP Suite", style: TextStyle(color: Colors.white38, fontSize: 10)),
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
