import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserMasterView extends StatefulWidget {
  final VoidCallback onLogout;
  const UserMasterView({super.key, required this.onLogout});
  @override State<UserMasterView> createState() => _UserMasterViewState();
}

class _UserMasterViewState extends State<UserMasterView> {
  final nC = TextEditingController(); final aC = TextEditingController(); final gC = TextEditingController();
  final dC = TextEditingController(); final pC = TextEditingController(); final eC = TextEditingController();
  final uC = TextEditingController(); final pwC = TextEditingController();

  @override void initState() { super.initState(); _load(); }
  _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      nC.text = p.getString('compName')??""; aC.text = p.getString('compAddr')??"";
      gC.text = p.getString('compGST')??""; dC.text = p.getString('compDL')??"";
      pC.text = p.getString('compPh')??""; eC.text = p.getString('compEmail')??"";
      uC.text = p.getString('adminUser')??""; pwC.text = p.getString('adminPass')??"";
    });
  }

  void _saveAll() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('compName', nC.text.toUpperCase()); await p.setString('compAddr', aC.text);
    await p.setString('compGST', gC.text.toUpperCase()); await p.setString('compDL', dC.text.toUpperCase());
    await p.setString('compPh', pC.text); await p.setString('compEmail', eC.text.toLowerCase());
    await p.setString('adminUser', uC.text.toLowerCase()); await p.setString('adminPass', pwC.text);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("All Details Updated Successfully!")));
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("User & Company Settings")),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text("COMPANY PROFILE", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        TextField(controller: nC, decoration: const InputDecoration(labelText: "Firm Name")),
        TextField(controller: aC, decoration: const InputDecoration(labelText: "Address")),
        Row(children: [Expanded(child: TextField(controller: gC, decoration: const InputDecoration(labelText: "GSTIN"))), const SizedBox(width: 10), Expanded(child: TextField(controller: dC, decoration: const InputDecoration(labelText: "Drug License")))]),
        Row(children: [Expanded(child: TextField(controller: pC, decoration: const InputDecoration(labelText: "Phone"))), const SizedBox(width: 10), Expanded(child: TextField(controller: eC, decoration: const InputDecoration(labelText: "Email")))]),
        const Divider(height: 50),
        const Text("ADMIN CREDENTIALS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        TextField(controller: uC, decoration: const InputDecoration(labelText: "Username")),
        TextField(controller: pwC, decoration: const InputDecoration(labelText: "Password")),
        const SizedBox(height: 30),
        ElevatedButton(onPressed: _saveAll, style: ElevatedButton.styleFrom(minimumSize: const Size(0, 50)), child: const Text("UPDATE ALL DETAILS")),
        const SizedBox(height: 10),
        ElevatedButton(onPressed: widget.onLogout, style: ElevatedButton.styleFrom(backgroundColor: Colors.red, minimumSize: const Size(0, 50)), child: const Text("LOGOUT & EXIT", style: TextStyle(color: Colors.white))),
      ]),
    );
  }
}
