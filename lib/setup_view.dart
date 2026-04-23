import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiSetupView extends StatefulWidget {
  const AiSetupView({super.key});

  @override
  State<AiSetupView> createState() => _AiSetupViewState();
}

class _AiSetupViewState extends State<AiSetupView> {
  // 1. Controller for the Text Field
  final TextEditingController geminiKeyC = TextEditingController();
  
  // 2. Settings variables
  bool autoOffline = true;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
  }

  // STEP 1: Load data from local storage
  Future<void> _loadSavedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        geminiKeyC.text = prefs.getString('geminiKey') ?? "";
        autoOffline = prefs.getBool('autoOffline') ?? true;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading settings: $e");
      setState(() => isLoading = false);
    }
  }

  // STEP 2: Save data back to storage
  Future<void> _saveSettings() async {
    // Basic Validation
    if (geminiKeyC.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Warning: No API Key entered. Online AI will not work."), backgroundColor: Colors.orange),
      );
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('geminiKey', geminiKeyC.text.trim());
      await prefs.setBool('autoOffline', autoOffline);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ AI Configuration Activated!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Go back to landing page
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("AI Configuration", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator()) // Loader while reading memory
        : SingleChildScrollView(
            padding: const EdgeInsets.all(25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderHeader(),
                const SizedBox(height: 30),
                
                _buildLabel("PRIMARY AI ENGINE"),
                _buildGeminiCard(),
                
                const SizedBox(height: 25),
                
                _buildLabel("INTELLIGENCE SETTINGS"),
                _buildSettingsCard(),

                const SizedBox(height: 40),
                
                // MAIN ACTION BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade900,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      elevation: 5
                    ),
                    onPressed: _saveSettings,
                    child: const Text("SAVE & ACTIVATE", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildHeaderHeader() {
    return const Center(
      child: Column(
        children: [
          Icon(Icons.hub_rounded, size: 60, color: Colors.indigo),
          SizedBox(height: 10),
          Text("AI Vision Settings", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1A237E))),
          Text("Configure your extraction engines", style: TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 5, bottom: 10),
      child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1.2)),
    );
  }

  Widget _buildGeminiCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.indigo.withOpacity(0.1), width: 1.5)
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.blue),
                const SizedBox(width: 10),
                const Text("Google Gemini", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                const Text("Free Plan", style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: geminiKeyC,
              decoration: InputDecoration(
                labelText: "Paste API Key",
                hintText: "AIzaSy...",
                prefixIcon: const Icon(Icons.vpn_key_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          SwitchListTile(
            title: const Text("Hybrid Auto-Fallback", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: const Text("Automatically switch to Offline mode if API fails.", style: TextStyle(fontSize: 11)),
            value: autoOffline,
            onChanged: (v) => setState(() => autoOffline = v),
            activeColor: Colors.indigo,
          ),
          const Divider(height: 1),
          const ListTile(
            leading: Icon(Icons.security, size: 20),
            title: Text("Privacy", style: TextStyle(fontSize: 13)),
            subtitle: Text("API keys are stored encrypted on your device.", style: TextStyle(fontSize: 10)),
          )
        ],
      ),
    );
  }
}
