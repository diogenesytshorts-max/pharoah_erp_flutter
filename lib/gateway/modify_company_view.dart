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
  late TextEditingController passwordC;
  late String selectedType;

  @override
  void initState() {
    super.initState();
    // Purani details load karna
    nameC = TextEditingController(text: widget.comp.name);
    passwordC = TextEditingController(text: widget.comp.password);
    selectedType = widget.comp.businessType;
  }

  void _handleUpdate() async {
    if (nameC.text.trim().isEmpty || passwordC.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Name and Password cannot be empty!")),
      );
      return;
    }

    final ph = Provider.of<PharoahManager>(context, listen: false);

    // 1. Registry mein is company ko dhoondhna
    int idx = ph.companiesRegistry.indexWhere((c) => c.id == widget.comp.id);
    
    if (idx != -1) {
      // 2. Nayi details update karna
      ph.companiesRegistry[idx] = CompanyProfile(
        id: widget.comp.id, // ID hamesha locked rahegi
        name: nameC.text.trim().toUpperCase(),
        businessType: selectedType,
        password: passwordC.text.trim(),
        fYears: widget.comp.fYears,
        createdAt: widget.comp.createdAt,
      );

      // 3. Registry file save karna
      await ph.saveRegistry();
      
      // 4. Active session update karna taaki dashboard par naya naam dikhe
      ph.activeCompany = ph.companiesRegistry[idx];
      ph.notifyListeners();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Company Profile Updated!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Edit Company Profile"),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ID Display (No Change Allowed)
            Text("COMPANY SYSTEM ID: ${widget.comp.id}", 
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
            const Divider(height: 30),

            _inputLabel("FIRM NAME"),
            TextField(
              controller: nameC,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Icons.business)),
            ),
            const SizedBox(height: 20),

            _inputLabel("NATURE OF BUSINESS"),
            DropdownButtonFormField<String>(
              value: selectedType,
              decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Icons.category)),
              items: ["WHOLESALE", "RETAIL"].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => selectedType = v!),
            ),
            const SizedBox(height: 20),

            _inputLabel("LOGIN PASSWORD"),
            TextField(
              controller: passwordC,
              decoration: const InputDecoration(
                border: OutlineInputBorder(), 
                prefixIcon: Icon(Icons.lock_reset),
                hintText: "Enter new password",
              ),
            ),

            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _handleUpdate,
                child: const Text("UPDATE SETTINGS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputLabel(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 4),
    child: Text(t, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
  );
}
