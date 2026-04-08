import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SetupView extends StatefulWidget {
  final VoidCallback onComplete;
  const SetupView({super.key, required this.onComplete});
  @override State<SetupView> createState() => _SetupViewState();
}

class _SetupViewState extends State<SetupView> {
  final nC = TextEditingController(); final aC = TextEditingController(); final gC = TextEditingController();
  final dC = TextEditingController(); final pC = TextEditingController(); final eC = TextEditingController();
  final uC = TextEditingController(); final pwC = TextEditingController();
  String fy = "2025-26";

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Setup Company")),
      body: SingleChildScrollView(padding: const EdgeInsets.all(25), child: Column(children: [
        TextField(controller: nC, decoration: const InputDecoration(labelText: "Firm / Shop Name", border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: aC, decoration: const InputDecoration(labelText: "Full Address", border: OutlineInputBorder())),
        Row(children: [Expanded(child: TextField(controller: gC, decoration: const InputDecoration(labelText: "GSTIN", border: OutlineInputBorder()))), const SizedBox(width: 10), Expanded(child: TextField(controller: dC, decoration: const InputDecoration(labelText: "DL No", border: OutlineInputBorder())))]),
        Row(children: [Expanded(child: TextField(controller: pC, decoration: const InputDecoration(labelText: "Phone No", border: OutlineInputBorder()))), const SizedBox(width: 10), Expanded(child: TextField(controller: eC, decoration: const InputDecoration(labelText: "Email ID", border: OutlineInputBorder())))]),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(value: fy, items: ["2024-25", "2025-26", "2026-27"].map((e)=>DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v)=>setState(()=>fy=v!), decoration: const InputDecoration(labelText: "Financial Year", border: OutlineInputBorder())),
        const Divider(height: 30),
        TextField(controller: uC, decoration: const InputDecoration(labelText: "Admin Username")),
        TextField(controller: pwC, decoration: const InputDecoration(labelText: "Admin Password"), obscureText: true),
        const SizedBox(height: 30),
        ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), backgroundColor: Colors.blue), onPressed: () async {
          if(nC.text.isEmpty || uC.text.isEmpty || pwC.text.isEmpty) return;
          final p = await SharedPreferences.getInstance();
          await p.setString('compName', nC.text.toUpperCase()); await p.setString('compAddr', aC.text); await p.setString('compGST', gC.text.toUpperCase()); await p.setString('compDL', dC.text.toUpperCase()); await p.setString('compPh', pC.text); await p.setString('compEmail', eC.text.toLowerCase()); await p.setString('adminUser', uC.text.toLowerCase()); await p.setString('adminPass', pwC.text); await p.setString('fy', fy); await p.setBool('isSetupDone', true);
          widget.onComplete();
        }, child: const Text("CREATE COMPANY & START", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
      ])),
    );
  }
}
