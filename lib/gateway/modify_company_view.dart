import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../pharoah_manager.dart';
import 'company_registry_model.dart';

class ModifyCompanyView extends StatefulWidget {
  final CompanyProfile comp;
  const ModifyCompanyView({super.key, required this.comp});

  @override
  State<ModifyCompanyView> createState() => _ModifyCompanyViewState();
}

class _ModifyCompanyViewState extends State<ModifyCompanyView> {
  late TextEditingController nameC;
  late TextEditingController addressC;
  late TextEditingController passwordC;

  @override
  void initState() {
    super.initState();
    nameC = TextEditingController(text: widget.comp.name);
    addressC = TextEditingController(text: ""); // Address registry mein nahi hai filhal, par hum add kar sakte hain future mein
    passwordC = TextEditingController(text: widget.comp.password);
  }

  void _handleUpdate() async {
    if (nameC.text.trim().isEmpty || passwordC.text.trim().isEmpty) return;

    final ph = Provider.of<PharoahManager>(context, listen: false);
    
    // Registry mein dukan dhoondo aur update karo
    int idx = ph.companiesRegistry.indexWhere((c) => c.id == widget.comp.id);
    if (idx != -1) {
      ph.companiesRegistry[idx] = CompanyProfile(
        id: widget.comp.id,
        name: nameC.text.trim().toUpperCase(),
        businessType: widget.comp.businessType,
        password: passwordC.text.trim(),
        fYears: widget.comp.fYears,
        createdAt: widget.comp.createdAt,
      );
      
      await ph.saveRegistry();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Company Profile Updated!"), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Modify Company Profile"), backgroundColor: Colors.blueGrey),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            _inputField(nameC, "Edit Firm Name", Icons.business),
            _inputField(passwordC, "Edit Password", Icons.lock_outline),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
                onPressed: _handleUpdate,
                child: const Text("SAVE CHANGES", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _inputField(TextEditingController ctrl, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), border: const OutlineInputBorder()),
      ),
    );
  }
}
