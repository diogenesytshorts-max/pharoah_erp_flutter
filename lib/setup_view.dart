import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SetupView extends StatefulWidget {
  final VoidCallback onComplete;
  const SetupView({super.key, required this.onComplete});

  @override
  State<SetupView> createState() => _SetupViewState();
}

class _SetupViewState extends State<SetupView> {
  // --- FORM CONTROLLERS ---
  final nameC = TextEditingController();
  final addressC = TextEditingController();
  final gstinC = TextEditingController();
  final dlNoC = TextEditingController();
  final phoneC = TextEditingController();
  final emailC = TextEditingController();
  final usernameC = TextEditingController();
  final passwordC = TextEditingController();

  String selectedFY = "2025-26";
  String selectedState = "Rajasthan";

  // List of Indian States for GST Compliance
  final List<String> states = [
    "Andhra Pradesh", "Arunachal Pradesh", "Assam", "Bihar", "Chhattisgarh", 
    "Goa", "Gujarat", "Haryana", "Himachal Pradesh", "Jharkhand", "Karnataka", 
    "Kerala", "Madhya Pradesh", "Maharashtra", "Manipur", "Meghalaya", "Mizoram", 
    "Nagaland", "Odisha", "Punjab", "Rajasthan", "Sikkim", "Tamil Nadu", 
    "Telangana", "Tripura", "Uttar Pradesh", "Uttarakhand", "West Bengal"
  ];

  // --- SAVE SETUP LOGIC ---
  Future<void> _handleFinishSetup() async {
    // Basic Validation
    if (nameC.text.trim().isEmpty || usernameC.text.trim().isEmpty || passwordC.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Firm Name, Admin Username and Password are mandatory!"))
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    
    // Save Company Details
    await prefs.setString('compName', nameC.text.trim().toUpperCase());
    await prefs.setString('compAddr', addressC.text.trim());
    await prefs.setString('compState', selectedState);
    await prefs.setString('compGST', gstinC.text.trim().toUpperCase().isEmpty ? "N/A" : gstinC.text.trim().toUpperCase());
    await prefs.setString('compDL', dlNoC.text.trim().toUpperCase().isEmpty ? "N/A" : dlNoC.text.trim().toUpperCase());
    await prefs.setString('compPh', phoneC.text.trim());
    await prefs.setString('compEmail', emailC.text.trim().toLowerCase());
    
    // Save Admin Credentials
    await prefs.setString('adminUser', usernameC.text.trim().toLowerCase());
    await prefs.setString('adminPass', passwordC.text.trim());
    
    // Save System Settings
    await prefs.setString('fy', selectedFY);
    await prefs.setBool('isSetupDone', true); // Mark setup as complete

    // Trigger callback to switch to Login/Dashboard
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Initial Company Setup"),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Welcome Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: Colors.blue.shade900,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Welcome to Pharoah ERP", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(height: 5),
                  Text("Please configure your business details to get started.", style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- SECTION 1: BUSINESS PROFILE ---
                  _buildSectionTitle("BUSINESS PROFILE"),
                  _setupField(nameC, "Firm / Shop Name", Icons.store_mall_directory),
                  _setupField(addressC, "Full Office Address", Icons.location_on),
                  
                  // State Selection (Crucial for GST)
                  DropdownButtonFormField<String>(
                    value: selectedState,
                    decoration: const InputDecoration(labelText: "Shop State (For GST)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.map)),
                    items: states.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setState(() => selectedState = v!),
                  ),
                  
                  const SizedBox(height: 15),

                  Row(
                    children: [
                      Expanded(child: _setupField(phoneC, "Mobile No", Icons.phone, isNum: true)),
                      const SizedBox(width: 10),
                      Expanded(child: _setupField(emailC, "Business Email", Icons.email)),
                    ],
                  ),

                  // --- SECTION 2: STATUTORY & TAX ---
                  _buildSectionTitle("STATUTORY & TAX DETAILS"),
                  Row(
                    children: [
                      Expanded(child: _setupField(gstinC, "GSTIN Number", Icons.receipt_long)),
                      const SizedBox(width: 10),
                      Expanded(child: _setupField(dlNoC, "Drug License (DL)", Icons.medical_services)),
                    ],
                  ),

                  DropdownButtonFormField<String>(
                    value: selectedFY,
                    decoration: const InputDecoration(labelText: "Current Financial Year", border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today)),
                    items: ["2024-25", "2025-26", "2026-27"].map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                    onChanged: (v) => setState(() => selectedFY = v!),
                  ),

                  // --- SECTION 3: ADMIN SECURITY ---
                  _buildSectionTitle("ADMIN LOGIN ACCESS"),
                  _setupField(usernameC, "Create Admin Username", Icons.person_add),
                  _setupField(passwordC, "Create Admin Password", Icons.lock_outline, isPassword: true),

                  const SizedBox(height: 30),

                  // Finish Button
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade900,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 5,
                      ),
                      onPressed: _handleFinishSetup,
                      child: const Text("FINISH & CREATE COMPANY", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI HELPERS ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Text(title, style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2)),
    );
  }

  Widget _setupField(TextEditingController ctrl, String label, IconData icon, {bool isNum = false, bool isPassword = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: ctrl,
        obscureText: isPassword,
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
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
