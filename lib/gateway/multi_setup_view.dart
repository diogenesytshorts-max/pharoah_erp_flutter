import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../pharoah_manager.dart';
import '../app_date_logic.dart';
import 'company_registry_model.dart';

class MultiSetupView extends StatefulWidget {
  final bool isFirstRun; 
  const MultiSetupView({super.key, this.isFirstRun = false});

  @override
  State<MultiSetupView> createState() => _MultiSetupViewState();
}

class _MultiSetupViewState extends State<MultiSetupView> {
  // --- CONTROLLERS ---
  final nameC = TextEditingController();
  final addressC = TextEditingController();
  final phoneC = TextEditingController();
  final emailC = TextEditingController();
  final gstinC = TextEditingController();
  final dlNoC = TextEditingController();
  final usernameC = TextEditingController();
  final passwordC = TextEditingController();

  // --- SELECTIONS ---
  String selectedType = "WHOLESALE";
  String selectedState = "Rajasthan";
  String selectedFY = "";
  String generatedID = "";

  final List<String> states = [
    "Andhra Pradesh", "Arunachal Pradesh", "Assam", "Bihar", "Chhattisgarh", 
    "Goa", "Gujarat", "Haryana", "Himachal Pradesh", "Jharkhand", "Karnataka", 
    "Kerala", "Madhya Pradesh", "Maharashtra", "Manipur", "Meghalaya", "Mizoram", 
    "Nagaland", "Odisha", "Punjab", "Rajasthan", "Sikkim", "Tamil Nadu", 
    "Telangana", "Tripura", "Uttar Pradesh", "Uttarakhand", "West Bengal"
  ];

  @override
  void initState() {
    super.initState();
    // 1. Generate Unique ID
    generatedID = "PH-C-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";
    
    // 2. Smart Detect Current Financial Year
    selectedFY = AppDateLogic.getCurrentFYString();
  }

  // --- SAVE LOGIC ---
  void _handleCreateCompany() async {
    if (nameC.text.trim().isEmpty || usernameC.text.trim().isEmpty || passwordC.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Firm Name, Username and Password are mandatory!"), backgroundColor: Colors.red),
      );
      return;
    }

    final ph = Provider.of<PharoahManager>(context, listen: false);

    // Naya Merged Profile Object banana
    final newComp = CompanyProfile(
      id: generatedID,
      name: nameC.text.trim().toUpperCase(),
      businessType: selectedType,
      createdAt: DateTime.now(),
      address: addressC.text.trim(),
      state: selectedState,
      gstin: gstinC.text.trim().toUpperCase().isEmpty ? "N/A" : gstinC.text.trim().toUpperCase(),
      dlNo: dlNoC.text.trim().toUpperCase().isEmpty ? "N/A" : dlNoC.text.trim().toUpperCase(),
      phone: phoneC.text.trim(),
      email: emailC.text.trim().toLowerCase(),
      adminUser: usernameC.text.trim().toLowerCase(),
      password: passwordC.text.trim(),
      fYears: [selectedFY], // Pehla saal automatic add ho jayega
    );

    // Registry mein save karna
    ph.companiesRegistry.add(newComp);
    await ph.saveRegistry();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Company Registered Successfully!"), backgroundColor: Colors.green),
      );
      // Setup khatam, AppGateway ise automatic handle kar lega
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: Text(widget.isFirstRun ? "Initial ERP Setup" : "Add New Company"),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER IDENTITY ---
            _buildIdentityHeader(),
            const SizedBox(height: 25),

            // --- SECTION 1: BUSINESS TYPE & FY ---
            _buildSectionCard(
              title: "NATURE OF BUSINESS",
              icon: Icons.category_rounded,
              child: Column(
                children: [
                  _dropdownLabel("Business Type"),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Icons.storefront)),
                    items: ["WHOLESALE", "RETAIL"].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => setState(() => selectedType = v!),
                  ),
                  const SizedBox(height: 15),
                  _dropdownLabel("Base Financial Year"),
                  DropdownButtonFormField<String>(
                    value: selectedFY,
                    decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today)),
                    items: ["2024-25", "2025-26", "2026-27"].map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                    onChanged: (v) => setState(() => selectedFY = v!),
                  ),
                ],
              ),
            ),

            // --- SECTION 2: SHOP DETAILS ---
            _buildSectionCard(
              title: "COMPANY PROFILE",
              icon: Icons.business_rounded,
              child: Column(
                children: [
                  _inputField(nameC, "Firm / Shop Name *", Icons.business, isCaps: true),
                  _inputField(addressC, "Full Office Address", Icons.location_on),
                  _dropdownLabel("Shop State (For GST)"),
                  DropdownButtonFormField<String>(
                    value: selectedState,
                    decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Icons.map)),
                    items: states.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (v) => setState(() => selectedState = v!),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(child: _inputField(phoneC, "Mobile No", Icons.phone, isNum: true)),
                      const SizedBox(width: 10),
                      Expanded(child: _inputField(emailC, "Business Email", Icons.email)),
                    ],
                  ),
                ],
              ),
            ),

            // --- SECTION 3: STATUTORY ---
            _buildSectionCard(
              title: "STATUTORY & TAX",
              icon: Icons.receipt_long_rounded,
              child: Column(
                children: [
                  _inputField(gstinC, "GSTIN Number", Icons.fingerprint, isCaps: true),
                  _inputField(dlNoC, "Drug License (DL)", Icons.medical_services_outlined, isCaps: true),
                ],
              ),
            ),

            // --- SECTION 4: SECURITY ---
            _buildSectionCard(
              title: "ADMIN ACCESS",
              icon: Icons.admin_panel_settings_rounded,
              child: Column(
                children: [
                  _inputField(usernameC, "Set Admin Username *", Icons.person_add_alt_1),
                  _inputField(passwordC, "Set Login Password *", Icons.lock_outline, isPass: true),
                ],
              ),
            ),

            const SizedBox(height: 30),
            
            // --- ACTION BUTTON ---
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 5,
                ),
                onPressed: _handleCreateCompany,
                child: const Text("CREATE & REGISTER COMPANY", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildIdentityHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF0D47A1).withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("SYSTEM ID", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1)),
              Text("(LOCKED FOR FILES)", style: TextStyle(fontSize: 8, color: Colors.red, fontWeight: FontWeight.bold)),
            ],
          ),
          Text(generatedID, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0D47A1), fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required Widget child}) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 18, color: const Color(0xFF0D47A1)),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1), letterSpacing: 1)),
            ]),
            const Divider(height: 30),
            child,
          ],
        ),
      ),
    );
  }

  Widget _dropdownLabel(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 4),
    child: Text(t, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
  );

  Widget _inputField(TextEditingController ctrl, String label, IconData icon, {bool isNum = false, bool isPass = false, bool isCaps = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: ctrl,
        obscureText: isPass,
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
        textCapitalization: isCaps ? TextCapitalization.characters : (isPass ? TextCapitalization.none : TextCapitalization.words),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        ),
      ),
    );
  }
}
