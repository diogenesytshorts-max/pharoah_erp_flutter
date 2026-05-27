import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../pharoah_manager.dart';

class CaProfileView extends StatefulWidget {
  const CaProfileView({super.key});

  @override
  State<CaProfileView> createState() => _CaProfileViewState();
}

class _CaProfileViewState extends State<CaProfileView> {
  late TextEditingController nameC, emailC, phoneC;

  @override
  void initState() {
    super.initState();
    final ph = Provider.of<PharoahManager>(context, listen: false);
    nameC = TextEditingController(text: ph.config.caName);
    emailC = TextEditingController(text: ph.config.caEmail);
    phoneC = TextEditingController(text: ph.config.caPhone);
  }

  void _saveCaSettings(PharoahManager ph) {
    ph.config.caName = nameC.text.trim().toUpperCase();
    ph.config.caEmail = emailC.text.trim().toLowerCase();
    ph.config.caPhone = phoneC.text.trim();
    ph.updateAppConfig(ph.config);
    ph.save(); // Config को परमानेंट सेव करना
    
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("✅ CA Profile Synchronized!"),
      backgroundColor: Colors.indigo,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("CA Audit Configuration"),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // --- THE MASTER TOGGLE (Very Important) ---
            Container(
              decoration: BoxDecoration(
                color: ph.config.isAuditMode ? Colors.orange.shade50 : Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: ph.config.isAuditMode ? Colors.orange : Colors.grey.shade300),
              ),
              child: SwitchListTile(
                title: const Text("ACTIVATE CA AUDIT MODE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text("Redirection to CA email will be enabled app-wide.", style: TextStyle(fontSize: 10)),
                value: ph.config.isAuditMode,
                activeColor: Colors.orange.shade900,
                onChanged: (v) {
                  setState(() => ph.config.isAuditMode = v);
                  ph.updateAppConfig(ph.config);
                },
              ),
            ),
            const SizedBox(height: 25),

            // --- CA DETAILS CARD ---
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.shade200)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("AUDITOR / CA INFORMATION", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1.2)),
                    const Divider(height: 30),
                    _inputField(nameC, "CA Full Name", Icons.person),
                    _inputField(emailC, "CA Official Email ID", Icons.email),
                    _inputField(phoneC, "Mobile Number", Icons.phone, isNum: true),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _saveCaSettings(ph),
                child: const Text("SAVE CA PROFILE", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputField(TextEditingController ctrl, String label, IconData icon, {bool isNum = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: ctrl,
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: const OutlineInputBorder(),
          filled: true, fillColor: Colors.white,
        ),
      ),
    );
  }
}
