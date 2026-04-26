// FILE: lib/administration/staff_management_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../pharoah_manager.dart';
import '../../models.dart';

class StaffManagementView extends StatefulWidget {
  const StaffManagementView({super.key});

  @override
  State<StaffManagementView> createState() => _StaffManagementViewState();
}

class _StaffManagementViewState extends State<StaffManagementView> {
  void _showSalesmanForm({Salesman? sman}) {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    final nameC = TextEditingController(text: sman?.name);
    final phoneC = TextEditingController(text: sman?.phone);
    String selectedRoute = sman?.route ?? (ph.routes.isNotEmpty ? ph.routes[0].name : "");

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(sman == null ? "Add New Salesman" : "Edit Salesman"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameC, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: "Salesman Name", prefixIcon: Icon(Icons.person))),
              const SizedBox(height: 10),
              TextField(controller: phoneC, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Phone Number", prefixIcon: Icon(Icons.phone))),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: selectedRoute.isEmpty ? null : selectedRoute,
                decoration: const InputDecoration(labelText: "Assigned Route", border: OutlineInputBorder()),
                items: ph.routes.map((r) => DropdownMenuItem(value: r.name, child: Text(r.name))).toList(),
                onChanged: (v) => setDialogState(() => selectedRoute = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
            ElevatedButton(
              onPressed: () {
                if (nameC.text.isEmpty) return;
                final nSman = Salesman(
                  id: sman?.id ?? DateTime.now().toString(),
                  name: nameC.text.toUpperCase(),
                  phone: phoneC.text,
                  route: selectedRoute,
                );
                if (sman == null) ph.addSalesman(nSman);
                else {
                  int i = ph.salesmen.indexWhere((x) => x.id == sman.id);
                  if (i != -1) ph.salesmen[i] = nSman;
                  ph.save();
                }
                Navigator.pop(c);
              },
              child: const Text("SAVE STAFF"),
            )
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(title: const Text("Security & Staff"), backgroundColor: Colors.red.shade900, foregroundColor: Colors.white),
      body: ListView.builder(
        padding: const EdgeInsets.all(15),
        itemCount: ph.salesmen.length,
        itemBuilder: (c, i) {
          final s = ph.salesmen[i];
          return Card(
            child: ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.red, child: Icon(Icons.badge, color: Colors.white)),
              title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("Phone: ${s.phone} | Route: ${s.route}"),
              trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => ph.deleteSalesman(s.id)),
              onTap: () => _showSalesmanForm(sman: s),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSalesmanForm(),
        backgroundColor: Colors.red.shade900,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text("ADD SALESMAN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
