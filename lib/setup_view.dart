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
  final dlC = TextEditingController();
  final phoneC = TextEditingController();
  final emailC = TextEditingController();
  final userC = TextEditingController();
  final passC = TextEditingController();

  void _saveSetup() async {
    if(nameC.text.isEmpty || userC.text.isEmpty || passC.text.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('compName', nameC.text.toUpperCase());
    await prefs.setString('compAddr', addrC.text);
    await prefs.setString('compGST', gstC.text.toUpperCase());
    await prefs.setString('compDL', dlC.text.toUpperCase());
    await prefs.setString('compPh', phoneC.text);
    await prefs.setString('compEmail', emailC.text.toLowerCase());
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
        child: Column(children: [
          const Text("Firm Details", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          const SizedBox(height: 10),
          TextField(controller: nameC, decoration: const InputDecoration(labelText: "Firm / Shop Name", border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: addrC, decoration: const InputDecoration(labelText: "Full Address", border: OutlineInputBorder())),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: gstC, decoration: const InputDecoration(labelText: "GSTIN", border: OutlineInputBorder()))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: dlC, decoration: const InputDecoration(labelText: "Drug License (DL)", border: OutlineInputBorder()))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: phoneC, decoration: const InputDecoration(labelText: "Mobile No", border: OutlineInputBorder()))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: emailC, decoration: const InputDecoration(labelText: "Email ID", border: OutlineInputBorder()))),
          ]),
          const SizedBox(height: 20),
          const Text("Admin Credentials", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          const SizedBox(height: 10),
          TextField(controller: userC, decoration: const InputDecoration(labelText: "Username")),
          TextField(controller: passC, decoration: const InputDecoration(labelText: "Password"), obscureText: true),
          const SizedBox(height: 30),
          ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), backgroundColor: Colors.blue), onPressed: _saveSetup, child: const Text("SAVE & START", style: TextStyle(color: Colors.white)))
        ]),
      ),
    );
  }
}
