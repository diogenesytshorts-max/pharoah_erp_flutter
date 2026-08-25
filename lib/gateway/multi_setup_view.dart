// FILE: lib/gateway/multi_setup_view.dart (WEB-SAFE & INSTANT ENVIRONMENT SETUP)

import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../pharoah_manager.dart";
import "company_registry_model.dart";

class MultiSetupView extends StatefulWidget {
  final bool isFirstRun;
  const MultiSetupView({super.key, this.isFirstRun = false});

  @override
  State<MultiSetupView> createState() => _MultiSetupViewState();
}

class _MultiSetupViewState extends State<MultiSetupView> {
  final _formKey = GlobalKey<FormState>();
  final nameC = TextEditingController();
  final gstinC = TextEditingController();
  final addressC = TextEditingController();
  final phoneC = TextEditingController();
  final emailC = TextEditingController();
  final adminUserC = TextEditingController(text: "admin");
  final adminPassC = TextEditingController(text: "admin123");
  
  String businessType = "WHOLESALE";
  String selectedFY = "2026-27";
  bool isProcessing = false;

  Future<void> _handleCreateCompany(PharoahManager ph) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isProcessing = true;
    });

    final newCompany = CompanyProfile(
      id: "PH-C-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}",
      name: nameC.text.trim().toUpperCase(),
      businessType: businessType,
      gstin: gstinC.text.trim().toUpperCase().isEmpty ? "N/A" : gstinC.text.trim().toUpperCase(),
      address: addressC.text.trim(),
      phone: phoneC.text.trim(),
      email: emailC.text.trim().toLowerCase(),
      adminUser: adminUserC.text.trim().toLowerCase(),
      password: adminPassC.text.trim(),
      createdAt: DateTime.now(),
    );

    await ph.setupNewCompanyEnvironment(newCompany, selectedFY);
    ph.authenticateAdmin(true);

    if (mounted) {
      setState(() {
        isProcessing = false;
      });
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: Text(widget.isFirstRun ? "Initial ERP Setup" : "Register New Firm / Shop"),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: isProcessing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF0D47A1)),
                  SizedBox(height: 15),
                  Text("Configuring Environment... Please wait.", style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle("FIRM / SHOP DETAILS"),
                    _textInput(nameC, "Company / Firm Name *", Icons.business, isRequired: true),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: businessType,
                            decoration: const InputDecoration(labelText: "Trade Type", border: OutlineInputBorder()),
                            items: ["WHOLESALE", "RETAIL", "DISTRIBUTOR"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                            onChanged: (v) => setState(() => businessType = v!),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedFY,
                            decoration: const InputDecoration(labelText: "Working FY", border: OutlineInputBorder()),
                            items: ["2024-25", "2025-26", "2026-27", "2027-28"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                            onChanged: (v) => setState(() => selectedFY = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _textInput(gstinC, "GSTIN Number", Icons.receipt_long),
                    _textInput(addressC, "Address", Icons.location_on),
                    Row(
                      children: [
                        Expanded(child: _textInput(phoneC, "Phone Number", Icons.phone, isNum: true)),
                        const SizedBox(width: 10),
                        Expanded(child: _textInput(emailC, "Business Email", Icons.email)),
                      ],
                    ),
                    const SizedBox(height: 25),
                    _sectionTitle("ADMIN SECURITY CREDENTIALS"),
                    _textInput(adminUserC, "Admin Username *", Icons.person, isRequired: true),
                    _textInput(adminPassC, "Admin Password *", Icons.lock, isRequired: true),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D47A1),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _handleCreateCompany(ph),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text("INITIALIZE & START ERP", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey, letterSpacing: 1.2),
      ),
    );
  }

  Widget _textInput(TextEditingController ctrl, String label, IconData icon, {bool isRequired = false, bool isNum = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: isNum ? TextInputType.phone : TextInputType.text,
        validator: isRequired ? (v) => (v == null || v.trim().isEmpty) ? "Required field" : null : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }
}
