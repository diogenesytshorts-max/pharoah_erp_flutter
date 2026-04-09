import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserMasterView extends StatefulWidget {
  final VoidCallback onLogout;
  const UserMasterView({super.key, required this.onLogout});

  @override
  State<UserMasterView> createState() => _UserMasterViewState();
}

class _UserMasterViewState extends State<UserMasterView> {
  // --- FORM CONTROLLERS ---
  final nameC = TextEditingController();
  final addressC = TextEditingController();
  final gstinC = TextEditingController();
  final dlNoC = TextEditingController();
  final phoneC = TextEditingController();
  final emailC = TextEditingController();
  final usernameC = TextEditingController();
  final passwordC = TextEditingController();
  
  String selectedState = "Rajasthan";

  // List of Indian States for GST consistency
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
    _loadCurrentDetails();
  }

  // Load existing details from SharedPreferences
  Future<void> _loadCurrentDetails() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      nameC.text = prefs.getString('compName') ?? "";
      addressC.text = prefs.getString('compAddr') ?? "";
      selectedState = prefs.getString('compState') ?? "Rajasthan";
      gstinC.text = prefs.getString('compGST') ?? "";
      dlNoC.text = prefs.getString('compDL') ?? "";
      phoneC.text = prefs.getString('compPh') ?? "";
      emailC.text = prefs.getString('compEmail') ?? "";
      usernameC.text = prefs.getString('adminUser') ?? "";
      passwordC.text = prefs.getString('adminPass') ?? "";
    });
  }

  // Save all updated details back to SharedPreferences
  Future<void> _saveAllDetails() async {
    if (nameC.text.trim().isEmpty || usernameC.text.trim().isEmpty || passwordC.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Name, Username and Password cannot be empty!"))
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('compName', nameC.text.trim().toUpperCase());
    await prefs.setString('compAddr', addressC.text.trim());
    await prefs.setString('compState', selectedState);
    await prefs.setString('compGST', gstinC.text.trim().toUpperCase());
    await prefs.setString('compDL', dlNoC.text.trim().toUpperCase());
    await prefs.setString('compPh', phoneC.text.trim());
    await prefs.setString('compEmail', emailC.text.trim().toLowerCase());
    await prefs.setString('adminUser', usernameC.text.trim().toLowerCase());
    await prefs.setString('adminPass', passwordC.text.trim());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("All details updated successfully!"),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("User & Company Settings"),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // --- SECTION 1: COMPANY PROFILE ---
          _buildSectionHeader("COMPANY PROFILE", Icons.business_rounded, Colors.blue.shade900),
          _inputField(nameC, "Firm / Shop Name"),
          _inputField(addressC, "Full Address"),
          
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: selectedState,
            decoration: const InputDecoration(labelText: "State (For GST)", border: OutlineInputBorder()),
            items: states.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => selectedState = v!),
          ),
          const SizedBox(height: 15),

          Row(
            children: [
              Expanded(child: _inputField(gstinC, "GSTIN No.")),
              const SizedBox(width: 10),
              Expanded(child: _inputField(dlNoC, "Drug License")),
            ],
          ),
          Row(
            children: [
              Expanded(child: _inputField(phoneC, "Phone No.", isNum: true)),
              const SizedBox(width: 10),
              Expanded(child: _inputField(emailC, "Business Email")),
            ],
          ),

          const SizedBox(height: 30),

          // --- SECTION 2: ADMIN CREDENTIALS ---
          _buildSectionHeader("ADMIN SECURITY", Icons.admin_panel_settings_rounded, Colors.red.shade800),
          _inputField(usernameC, "Login Username"),
          _inputField(passwordC, "Login Password"), // Not obscured here for admin to see what they are setting

          const SizedBox(height: 30),

          // --- ACTION BUTTONS ---
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade900,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ).onPressed(
              onPressed: _saveAllDetails,
              child: const Text("UPDATE ALL DETAILS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),

          const SizedBox(height: 15),

          SizedBox(
            width: double.infinity,
            height: 55,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text("Logout?"),
                    content: const Text("Are you sure you want to logout and exit to the login screen?"),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
                      TextButton(onPressed: () {
                        Navigator.pop(c);
                        widget.onLogout();
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      }, child: const Text("LOGOUT", style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded),
                  SizedBox(width: 10),
                  Text("LOGOUT & EXIT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // --- UI HELPERS ---

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15, top: 10),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.2),
          ),
        ],
      ),
    );
  }

  Widget _inputField(TextEditingController ctrl, String label, {bool isNum = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: ctrl,
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
        style: const TextStyle(fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        ),
      ),
    );
  }
}

// Simple extension to fix ElevatedButton syntax in older flutter versions if needed
extension on ButtonStyle {
  ElevatedButton onPressed({required VoidCallback onPressed, required Widget child}) {
    return ElevatedButton(onPressed: onPressed, style: this, child: child);
  }
}
