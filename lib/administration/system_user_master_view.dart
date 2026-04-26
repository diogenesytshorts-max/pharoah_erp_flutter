// FILE: lib/administration/system_user_master_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../pharoah_manager.dart';
import 'system_user_model.dart'; // Naya model jo humne banaya tha

class SystemUserMasterView extends StatefulWidget {
  const SystemUserMasterView({super.key});

  @override
  State<SystemUserMasterView> createState() => _SystemUserMasterViewState();
}

class _SystemUserMasterViewState extends State<SystemUserMasterView> {

  // --- POPUP FORM FOR NEW/EDIT USER ---
  void _showUserForm({SystemUser? user}) {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    
    // Controllers
    final nameC = TextEditingController(text: user?.name);
    final userC = TextEditingController(text: user?.username);
    final passC = TextEditingController(text: user?.password);
    
    // Local state for Toggles (Switches)
    bool pDelete = user?.canDeleteBill ?? false;
    bool pRate = user?.canViewPurchaseRate ?? false;
    bool pFinance = user?.canViewFinance ?? false;
    bool pExport = user?.canExportData ?? false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(user == null ? "Create New Staff Login" : "Edit Staff Rights", style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("LOGIN CREDENTIALS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 10),
                  _buildInput(nameC, "Full Name (e.g. Amit Kumar)", Icons.person),
                  _buildInput(userC, "Login Username", Icons.login),
                  _buildInput(passC, "Login Password", Icons.password),
                  
                  const Divider(height: 30),
                  const Text("SOFTWARE PERMISSIONS (RIGHTS)", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 10),
                  
                  // The 4 Switches
                  _buildSwitch("Can Delete/Cancel Bills", pDelete, (v) => setDialogState(() => pDelete = v)),
                  _buildSwitch("Can View Purchase Rate & Profit", pRate, (v) => setDialogState(() => pRate = v)),
                  _buildSwitch("Can Access Finance & Ledgers", pFinance, (v) => setDialogState(() => pFinance = v)),
                  _buildSwitch("Can Export PDF & CSV Data", pExport, (v) => setDialogState(() => pExport = v)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL", style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900, foregroundColor: Colors.white),
              onPressed: () {
                if (nameC.text.isEmpty || userC.text.isEmpty || passC.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("All fields are mandatory!")));
                  return;
                }

                final newUser = SystemUser(
                  id: user?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameC.text.trim().toUpperCase(),
                  username: userC.text.trim().toLowerCase(),
                  password: passC.text.trim(),
                  canDeleteBill: pDelete,
                  canViewPurchaseRate: pRate,
                  canViewFinance: pFinance,
                  canExportData: pExport,
                );

                if (user == null) {
                  ph.addSystemUser(newUser);
                } else {
                  ph.updateSystemUser(newUser);
                }
                Navigator.pop(c);
              },
              child: const Text("SAVE LOGIN"),
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
      appBar: AppBar(
        title: const Text("Staff Login & Rights"),
        backgroundColor: Colors.red.shade900,
        foregroundColor: Colors.white,
      ),
      body: ph.systemUsers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.admin_panel_settings_outlined, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  const Text("No staff logins created yet.", style: TextStyle(color: Colors.grey)),
                  const Text("Currently only Owner (Admin) can login.", style: TextStyle(color: Colors.grey, fontSize: 10)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: ph.systemUsers.length,
              itemBuilder: (c, i) {
                final u = ph.systemUsers[i];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.red.shade100)),
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(backgroundColor: Colors.red, child: Icon(Icons.person, color: Colors.white)),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text("Username: ${u.username}", style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showUserForm(user: u)),
                            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _confirmDelete(ph, u)),
                          ],
                        ),
                        const Divider(height: 25),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _badge("Delete Bill", u.canDeleteBill),
                            _badge("View Pur.Rate", u.canViewPurchaseRate),
                            _badge("Access Finance", u.canViewFinance),
                            _badge("Export Data", u.canExportData),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUserForm(),
        backgroundColor: Colors.red.shade900,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text("CREATE STAFF LOGIN", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  // --- UI HELPERS ---
  Widget _buildInput(TextEditingController ctrl, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 20), border: const OutlineInputBorder(), isDense: true),
      ),
    );
  }

  Widget _buildSwitch(String title, bool val, Function(bool) onChanged) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      activeColor: Colors.green,
      title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      value: val,
      onChanged: onChanged,
    );
  }

  Widget _badge(String title, bool isGranted) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isGranted ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isGranted ? Colors.green.shade200 : Colors.red.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isGranted ? Icons.check : Icons.close, size: 12, color: isGranted ? Colors.green : Colors.red),
          const SizedBox(width: 4),
          Text(title, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isGranted ? Colors.green.shade800 : Colors.red.shade800)),
        ],
      ),
    );
  }

  void _confirmDelete(PharoahManager ph, SystemUser u) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Delete Login?"),
        content: Text("Are you sure you want to remove access for '${u.name}'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("NO")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () { ph.deleteSystemUser(u.id); Navigator.pop(c); }, 
            child: const Text("YES, DELETE", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }
}
