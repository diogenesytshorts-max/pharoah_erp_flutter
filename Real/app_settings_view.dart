// FILE: lib/administration/app_settings_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../pharoah_manager.dart';
import '../logic/app_settings_model.dart';
import 'architect_control_view.dart'; // NAYA GATEWAY LINK

class AppSettingsView extends StatefulWidget {
  const AppSettingsView({super.key});

  @override
  State<AppSettingsView> createState() => _AppSettingsViewState();
}

class _AppSettingsViewState extends State<AppSettingsView> {
  // Controllers for prefixes
  late TextEditingController sPre, scPre, srPre, pPre, prPre;

  @override
  void initState() {
    super.initState();
    final ph = Provider.of<PharoahManager>(context, listen: false);
    
    // Initializing with current config values
    sPre = TextEditingController(text: ph.config.salePrefix);
    scPre = TextEditingController(text: ph.config.saleChallanPrefix);
    srPre = TextEditingController(text: ph.config.saleReturnPrefix);
    pPre = TextEditingController(text: ph.config.purPrefix);
    prPre = TextEditingController(text: ph.config.purReturnPrefix);
  }

  // --- LOGIC: SAVE PREFIXES ---
  void _savePrefixSettings(PharoahManager ph) {
    final updatedConfig = ph.config;
    updatedConfig.salePrefix = sPre.text.trim().toUpperCase();
    updatedConfig.saleChallanPrefix = scPre.text.trim().toUpperCase();
    updatedConfig.saleReturnPrefix = srPre.text.trim().toUpperCase();
    updatedConfig.purPrefix = pPre.text.trim().toUpperCase();
    updatedConfig.purReturnPrefix = prPre.text.trim().toUpperCase();
    
    ph.updateAppConfig(updatedConfig);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("✅ Prefix settings saved successfully!"),
      backgroundColor: Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC), // Premium Background
      appBar: AppBar(
        title: const Text("Global ERP Settings", style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: const Color(0xFF1A237E), // Deep Navy
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- SECTION 1: THE ARCHITECT GATEWAY (Advanced Controls) ---
            _buildArchitectGateway(context),

            const SizedBox(height: 35),
            _sectionLabel("TRANSACTION NUMBERING PREFIXES"),
            const SizedBox(height: 10),
            _buildPrefixCard(),

            const SizedBox(height: 35),
            _sectionLabel("DATA MAINTENANCE (DANGER ZONE)"),
            const SizedBox(height: 10),
            _buildResetCounterPanel(ph),

            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        color: Colors.white,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A237E), 
            foregroundColor: Colors.white, 
            minimumSize: const Size(double.infinity, 55),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            elevation: 8,
            shadowColor: Colors.indigo.withOpacity(0.4),
          ),
          onPressed: () => _savePrefixSettings(ph),
          child: const Text("SAVE GLOBAL PREFIXES", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        ),
      ),
    );
  }

  // --- PREMIUM UI COMPONENTS ---

  Widget _buildArchitectGateway(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ArchitectControlView())),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.indigo.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: const Row(
          children: [
            Icon(Icons.architecture_rounded, color: Colors.orangeAccent, size: 45),
            SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("ARCHITECT CONTROL CENTER", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  SizedBox(height: 5),
                  Text("Manage Logo, Signatures, QR Code, Print Formats & Bank Details", style: TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildPrefixCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(25), 
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(children: [
            Expanded(child: _input(sPre, "Sale Bill", "e.g. INV-")),
            const SizedBox(width: 15),
            Expanded(child: _input(scPre, "Sale Challan", "e.g. SCH-")),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: _input(srPre, "Sale Return", "e.g. SRN-")),
            const SizedBox(width: 15),
            Expanded(child: _input(pPre, "Purchase Bill", "e.g. PUR-")),
          ]),
          const SizedBox(height: 20),
          _input(prPre, "Purchase Return", "e.g. PRN-"),
        ],
      ),
    );
  }

  Widget _buildResetCounterPanel(PharoahManager ph) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.shade50, 
        borderRadius: BorderRadius.circular(20), 
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
              SizedBox(width: 12),
              Text("Reset Transaction Numbering", style: TextStyle(fontSize: 14, color: Colors.red, fontWeight: FontWeight.bold)),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 36),
            child: Text("Danger: This will start your bill numbering from 1 again. Use only at start of month/year.", 
              style: TextStyle(fontSize: 10, color: Colors.blueGrey)),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _resetBtn("SALE", () => ph.resetCounter("SALE_BILL")),
              _resetBtn("PURCHASE", () => ph.resetCounter("PUR_BILL")),
              _resetBtn("CHALLAN", () => ph.resetCounter("SALE_CHALLAN")),
            ],
          )
        ],
      ),
    );
  }

  // --- UI ATOMS ---

  Widget _sectionLabel(String t) => Padding(
    padding: const EdgeInsets.only(left: 5),
    child: Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade400, letterSpacing: 1.5)),
  );

  Widget _input(TextEditingController c, String l, String h) => TextField(
    controller: c,
    textCapitalization: TextCapitalization.characters,
    decoration: InputDecoration(
      labelText: l, 
      hintText: h, 
      filled: true, 
      fillColor: const Color(0xFFF9FAFB),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE0E6ED))),
      isDense: true,
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
    ),
  );

  Widget _resetBtn(String label, VoidCallback onReset) => OutlinedButton(
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.red, 
      side: const BorderSide(color: Colors.red, width: 1.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    ),
    onPressed: () {
      showDialog(context: context, builder: (c) => AlertDialog(
        title: const Text("Confirm Reset?"),
        content: Text("Are you sure you want to start $label numbering from 1?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("NO")),
          TextButton(onPressed: () { onReset(); Navigator.pop(c); }, child: const Text("YES, RESET", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      ));
    },
    child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
  );
}
