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
  String selectedState = "Rajasthan";

  final List<String> states = [
    "Andhra Pradesh", "Arunachal Pradesh", "Assam", "Bihar", "Chhattisgarh", "Goa", "Gujarat", "Haryana", "Himachal Pradesh", "Jharkhand", "Karnataka", "Kerala", "Madhya Pradesh", "Maharashtra", "Manipur", "Meghalaya", "Mizoram", "Nagaland", "Odisha", "Punjab", "Rajasthan", "Sikkim", "Tamil Nadu", "Telangana", "Tripura", "Uttar Pradesh", "Uttarakhand", "West Bengal"
  ];

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Initial Setup - Company Profile")),
      body: SingleChildScrollView(padding: const EdgeInsets.all(25), child: Column(children: [
        TextField(controller: nC, decoration: const InputDecoration(labelText: "Firm / Shop Name", border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: aC, decoration: const InputDecoration(labelText: "Full Address", border: OutlineInputBorder())),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: selectedState,
          items: states.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (v) => setState(() => selectedState = v!),
          decoration: const InputDecoration(labelText: "Shop State (For GST)", border: OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        Row(children: [Expanded(child: TextField(controller: gC, decoration: const InputDecoration(labelText: "GSTIN", border: OutlineInputBorder()))), const SizedBox(width: 10), Expanded(child: TextField(controller: dC, decoration: const InputDecoration(labelText: "DL No", border: OutlineInputBorder())))]),
        Row(children: [Expanded(child: TextField(controller: pC, decoration: const InputDecoration(labelText: "Phone No", border: OutlineInputBorder()))), const SizedBox(width: 10), Expanded(child: TextField(controller: eC, decoration: const InputDecoration(labelText: "Email ID", border: OutlineInputBorder())))]),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(value: fy, items: ["2024-25", "2025-26", "2026-27"].map((e)=>DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v)=>setState(()=>fy=v!), decoration: const InputDecoration(labelText: "Current Financial Year", border: OutlineInputBorder())),
        const Divider(height: 40),
        TextField(controller: uC, decoration: const InputDecoration(labelText: "Create Admin Username")),
        TextField(controller: pwC, decoration: const InputDecoration(labelText: "Create Admin Password"), obscureText: true),
        const SizedBox(height: 30),
        ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), backgroundColor: Colors.blue), onPressed: () async {
          if(nC.text.isEmpty || uC.text.isEmpty || pwC.text.isEmpty) return;
          final p = await SharedPreferences.getInstance();
          await p.setString('compName', nC.text.toUpperCase()); 
          await p.setString('compAddr', aC.text); 
          await p.setString('compState', selectedState);
          await p.setString('compGST', gC.text.toUpperCase()); 
          await p.setString('compDL', dC.text.toUpperCase()); 
          await p.setString('compPh', pC.text); 
          await p.setString('compEmail', eC.text.toLowerCase()); 
          await p.setString('adminUser', uC.text.toLowerCase()); 
          await p.setString('adminPass', pwC.text); 
          await p.setString('fy', fy); 
          await p.setBool('isSetupDone', true);
          widget.onComplete();
        }, child: const Text("FINISH & START ERP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
      ])),
    );
  }
}
