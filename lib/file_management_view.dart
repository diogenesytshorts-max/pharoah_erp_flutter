import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FileManagementView extends StatefulWidget {
  const FileManagementView({super.key});
  @override State<FileManagementView> createState() => _FileManagementViewState();
}

class _FileManagementViewState extends State<FileManagementView> {
  String currentFy = "";
  @override void initState() { super.initState(); _load(); }
  _load() async { final p = await SharedPreferences.getInstance(); setState(() => currentFy = p.getString('fy') ?? "2025-26"); }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("File Management")),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        ListTile(
          tileColor: Colors.blue[50],
          leading: const Icon(Icons.calendar_month),
          title: const Text("Change Financial Year"),
          subtitle: Text("Current: $currentFy"),
          onTap: () {
            showDialog(context: context, builder: (c)=>SimpleDialog(title: const Text("Select Year"), children: ["2024-25", "2025-26", "2026-27"].map((y)=>SimpleDialogOption(child: Text(y), onPressed: () async {
              final p = await SharedPreferences.getInstance(); await p.setString('fy', y); Navigator.pop(c); _load();
            })).toList()));
          },
        )
      ]),
    );
  }
}
