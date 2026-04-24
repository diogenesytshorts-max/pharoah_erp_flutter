import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../pharoah_manager.dart';
import 'company_registry_model.dart';

class MultiSetupView extends StatefulWidget {
  final bool isFirstRun; // Pehli dukan hai ya purani ke baad nayi
  const MultiSetupView({super.key, this.isFirstRun = false});

  @override
  State<MultiSetupView> createState() => _MultiSetupViewState();
}

class _MultiSetupViewState extends State<MultiSetupView> {
  // --- CONTROLLERS ---
  final nameC = TextEditingController();
  final addressC = TextEditingController();
  final passwordC = TextEditingController();
  final phoneC = TextEditingController();
  final gstinC = TextEditingController();

  String selectedType = "WHOLESALE";
  String generatedID = "";

  @override
  void initState() {
    super.initState();
    // Screen load hote hi Manager se unique ID mangna
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ph = Provider.of<PharoahManager>(context, listen: false);
      setState(() {
        generatedID = ph.generateCompanyID();
      });
    });
  }

  // --- SAVE LOGIC ---
  void _handleCreateCompany() async {
    if (nameC.text.trim().isEmpty || passwordC.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Firm Name and Password are mandatory!"), backgroundColor: Colors.red),
      );
      return;
    }

    final ph = Provider.of<PharoahManager>(context, listen: false);

    // 1. Naya Profile Object banana
    final newComp = CompanyProfile(
      id: generatedID,
      name: nameC.text.trim().toUpperCase(),
      businessType: selectedType,
      password: passwordC.text.trim(),
      createdAt: DateTime.now(),
      fYears: [], // Shuruat mein koi saal nahi hoga
    );

    // 2. Registry mein jodhna aur save karna
    ph.companiesRegistry.add(newComp);
    await ph.saveRegistry();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Company Registered Successfully!"), backgroundColor: Colors.green),
      );
      // Setup khatam, ab main.dart automatic isse Selection Screen par le jayega
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.isFirstRun ? "Initial ERP Setup" : "Add New Company"),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- ID DISPLAY (LOCKED) ---
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("SYSTEM ID (LOCKED):", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 12)),
                  Text(generatedID, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0D47A1), fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(height: 25),

            _sectionLabel("BUSINESS TYPE"),
            DropdownButtonFormField<String>(
              value: selectedType,
              decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Icons.storefront)),
              items: ["WHOLESALE", "RETAIL"].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => selectedType = v!),
            ),
            
            const SizedBox(height: 20),
            _sectionLabel("COMPANY DETAILS"),
            _inputField(nameC, "Firm / Shop Name *", Icons.business),
            _inputField(addressC, "Full Address", Icons.location_on),
            _inputField(phoneC, "Contact Number", Icons.phone, isNum: true),
            _inputField(gstinC, "GSTIN (Optional)", Icons.receipt_long),

            const SizedBox(height: 20),
            _sectionLabel("SECURITY ACCESS"),
            _inputField(passwordC, "Set Login Password *", Icons.lock_outline, isPass: true),

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _handleCreateCompany,
                child: const Text("CREATE & REGISTER COMPANY", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 4),
    child: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1)),
  );

  Widget _inputField(TextEditingController ctrl, String label, IconData icon, {bool isNum = false, bool isPass = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: ctrl,
        obscureText: isPass,
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
        textCapitalization: isPass ? TextCapitalization.none : TextCapitalization.words,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
