import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SetupView extends StatefulWidget {
  final VoidCallback onComplete;
  const SetupView({super.key, required this.onComplete});
  @override State<SetupView> createState() => _SetupViewState();
}

class _SetupViewState extends State<SetupView> {
  final nameC = TextEditingController(); final addrC = TextEditingController(); final gstC = TextEditingController();
  final dlC = TextEditingController(); final phoneC = TextEditingController(); final emailC = TextEditingController();
  final userC = TextEditingController(); final passC = TextEditingController();
  String fy = "2025-26";

  void _saveSetup() async {
    if(nameC.text.isEmpty || userC.text.isEmpty || passC.text.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    await p.setString('compName', nameC.text.toUpperCase());
    await p.setString('compAddr', addrC.text);
    await p.setString('compGST', gstC.text.toUpperCase());
    await p.setString('compDL', dlC.text.toUpperCase());
    await p.setString('compPh', phoneC.text);
    await p.setString('compEmail', emailC.text.toLowerCase());
    await p.setString('adminUser', userC.text.toLowerCase());
    await p.setString('adminPass', passC.text);
    await p.setString('fy', fy);
    await p.setBool('isSetupDone', true);
    widget.onComplete();
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Company Setup")),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
        TextField(controller: nameC, decoration: const InputDecoration(labelText: "Firm Name", border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: addrC, decoration: const InputDecoration(labelText: "Address", border: OutlineInputBorder())),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(controller: gstC, decoration: const InputDecoration(labelText: "GSTIN"))),
          Expanded(child: TextField(controller: dlC, decoration: const InputDecoration(labelText: "Drug License"))),
        ]),
        const SizedBox(height: 10),
        DropdownButtonFormField(value: fy, items: ["2024-25", "2025-26", "2026-27"].map((e)=>DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v)=>setState(()=>fy=v!), decoration: const InputDecoration(labelText: "Financial Year")),
        const Divider(height: 40),
        TextField(controller: userC, decoration: const InputDecoration(labelText: "Admin Username")),
        TextField(controller: passC, decoration: const InputDecoration(labelText: "Admin Password"), obscureText: true),
        const SizedBox(height: 20),
        ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55)), onPressed: _saveSetup, child: const Text("SAVE & START"))
      ])),
    );
  }
}
