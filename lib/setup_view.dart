import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SetupView extends StatefulWidget {
  final VoidCallback onComplete;
  const SetupView({super.key, required this.onComplete});

  @override
  State<SetupView> createState() => _SetupViewState();
}

class _SetupViewState extends State<SetupView> {
  final nameC = TextEditingController();
  final addrC = TextEditingController();
  final gstC = TextEditingController();
  final userC = TextEditingController();
  final passC = TextEditingController();

  void _saveSetup() async {
    if(nameC.text.isEmpty || userC.text.isEmpty || passC.text.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('compName', nameC.text.toUpperCase());
    await prefs.setString('compAddr', addrC.text);
    await prefs.setString('compGST', gstC.text.toUpperCase());
    await prefs.setString('adminUser', userC.text.toLowerCase());
    await prefs.setString('adminPass', passC.text);
    await prefs.setBool('isSetupDone', true);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Company Setup")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.business, size: 80, color: Colors.blue),
            const Text("Welcome to Pharoah ERP", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(controller: nameC, decoration: const InputDecoration(labelText: "Firm Name", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: addrC, decoration: const InputDecoration(labelText: "Address", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: gstC, decoration: const InputDecoration(labelText: "GSTIN", border: OutlineInputBorder())),
            const SizedBox(height: 20),
            const Text("Create Admin Login", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 10),
            TextField(controller: userC, decoration: const InputDecoration(labelText: "Username", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: passC, decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder()), obscureText: true),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), backgroundColor: Colors.blue),
              onPressed: _saveSetup,
              child: const Text("CREATE COMPANY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}
