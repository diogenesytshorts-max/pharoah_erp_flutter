import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserMasterView extends StatefulWidget {
  final VoidCallback onLogout;
  const UserMasterView({super.key, required this.onLogout});
  @override
  State<UserMasterView> createState() => _UserMasterViewState();
}

class _UserMasterViewState extends State<UserMasterView> {
  final nameC = TextEditingController();
  final gstC = TextEditingController();
  final addrC = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }
  _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() { nameC.text = p.getString('compName') ?? ""; gstC.text = p.getString('compGST') ?? ""; addrC.text = p.getString('compAddr') ?? ""; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("User Settings")),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text("Company Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        TextField(controller: nameC, decoration: const InputDecoration(labelText: "Firm Name")),
        TextField(controller: gstC, decoration: const InputDecoration(labelText: "GSTIN")),
        TextField(controller: addrC, decoration: const InputDecoration(labelText: "Address")),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: () async {
          final p = await SharedPreferences.getInstance();
          await p.setString('compName', nameC.text); await p.setString('compGST', gstC.text); await p.setString('compAddr', addrC.text);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saved Successfully")));
        }, child: const Text("Update Profile")),
        const Divider(height: 50),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: widget.onLogout, child: const Text("LOGOUT", style: TextStyle(color: Colors.white)))
      ]),
    );
  }
}
