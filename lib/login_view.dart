// FILE: lib/login_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';

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

    String savedUser = comp.adminUser.toLowerCase();
    String savedPass = comp.password;
    String enteredUser = userC.text.trim().toLowerCase();
    String enteredPass = passC.text;

    // 1. Check for Company Admin or Master Bypass
    if ((enteredUser == savedUser && enteredPass == savedPass) || 
        (enteredUser == "rawat" && enteredPass == "rawat")) {
      
      ph.loggedInStaff = null; // Clear staff session if admin logs in
      ph.authenticateAdmin(true); // Isse main.dart ko pata chalega ki login ho gaya
      
    } else {
      // 2. Check for Staff Logins
      try {
        final staff = ph.systemUsers.firstWhere(
          (u) => u.username == enteredUser && u.password == enteredPass
        );
        
        ph.loggedInStaff = staff;
        ph.authenticateAdmin(true);
        
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid Credentials for this Business!"), backgroundColor: Colors.red)
        );
      }
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
                Text(
                  comp?.name ?? "PHAROAH ERP", 
                  textAlign: TextAlign.center, 
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)
                ),
                
                const SizedBox(height: 40),

                Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.white, 
                    borderRadius: BorderRadius.circular(20), 
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 15)]
                  ),
                  child: Column(
                    children: [
                      const Text("ACCOUNT LOGIN", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1.5)),
                      const SizedBox(height: 20),
                      TextField(
                        controller: userC, 
                        decoration: const InputDecoration(labelText: "Username", prefixIcon: Icon(Icons.person_outline))
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: passC, 
                        obscureText: isObscured,
                        decoration: InputDecoration(
                          labelText: "Password", 
                          prefixIcon: const Icon(Icons.key),
                          suffixIcon: IconButton(
                            icon: Icon(isObscured ? Icons.visibility : Icons.visibility_off), 
                            onPressed: () => setState(() => isObscured = !isObscured)
                          ),
                        ),
                      ),
                      const SizedBox(height: 25),
                      SizedBox(
                        width: double.infinity, height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D47A1), 
                            foregroundColor: Colors.white, 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                          ),
                          onPressed: () => _handleLogin(ph),
                          child: const Text("LOGIN SECURELY", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                TextButton.icon(
                  onPressed: () => ph.clearSession(), 
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text("Back to Company List"),
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
}
