import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserMasterView extends StatefulWidget {
  final VoidCallback onLogout;
  const UserMasterView({super.key, required this.onLogout});
  @override State<UserMasterView> createState() => _UserMasterViewState();
}

class _UserMasterViewState extends State<UserMasterView> {
  final nameC = TextEditingController(); final addrC = TextEditingController(); final gstC = TextEditingController();
  final dlC = TextEditingController(); final phoneC = TextEditingController(); final emailC = TextEditingController();
  final userC = TextEditingController(); final passC = TextEditingController();

  @override void initState() { super.initState(); _load(); }
  _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      nameC.text = p.getString('compName') ?? ""; addrC.text = p.getString('compAddr') ?? "";
      gstC.text = p.getString('compGST') ?? ""; dlC.text = p.getString('compDL') ?? "";
      phoneC.text = p.getString('compPh') ?? ""; emailC.text = p.getString('compEmail') ?? "";
      userC.text = p.getString('adminUser') ?? ""; passC.text = p.getString('adminPass') ?? "";
    });
  }

  void _update() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('compName', nameC.text.toUpperCase()); await p.setString('compAddr', addrC.text);
    await p.setString('compGST', gstC.text.toUpperCase()); await p.setString('compDL', dlC.text.toUpperCase());
    await p.setString('compPh', phoneC.text); await p.setString('compEmail', emailC.text.toLowerCase());
    await p.setString('adminUser', userC.text.toLowerCase()); await p.setString('adminPass', passC.text);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Updated Successfully!")));
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("App Settings")),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text("Company Profile", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
        TextField(controller: nameC, decoration: const InputDecoration(labelText: "Firm Name")),
        TextField(controller: addrC, decoration: const InputDecoration(labelText: "Address")),
        Row(children: [
          Expanded(child: TextField(controller: gstC, decoration: const InputDecoration(labelText: "GSTIN"))),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: dlC, decoration: const InputDecoration(labelText: "DL Number"))),
        ]),
        Row(children: [
          Expanded(child: TextField(controller: phoneC, decoration: const InputDecoration(labelText: "Phone"))),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: emailC, decoration: const InputDecoration(labelText: "Email"))),
        ]),
        const SizedBox(height: 30),
        const Text("Security Credentials", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
        TextField(controller: userC, decoration: const InputDecoration(labelText: "Admin Username")),
        TextField(controller: passC, decoration: const InputDecoration(labelText: "Admin Password")),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: _update, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, minimumSize: const Size(0, 50)), child: const Text("UPDATE ALL DETAILS", style: TextStyle(color: Colors.white))),
        const Divider(height: 40),
        ElevatedButton(onPressed: widget.onLogout, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("LOGOUT & EXIT", style: TextStyle(color: Colors.white))),
      ]),
    );
  }
}
