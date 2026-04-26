// FILE: lib/administration/app_settings_view.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../pharoah_manager.dart';
import '../logic/app_settings_model.dart';

class AppSettingsView extends StatefulWidget {
  const AppSettingsView({super.key});

  @override
  State<AppSettingsView> createState() => _AppSettingsViewState();
}

class _AppSettingsViewState extends State<AppSettingsView> {
  // Controllers
  late TextEditingController sPre, scPre, srPre, pPre, prPre, termsC;
  String selectedFormat = "A4";
  String? logoPath;

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
    termsC = TextEditingController(text: ph.config.termsAndConditions);
    selectedFormat = ph.config.printFormat;
    logoPath = ph.config.logoPath;
  }

  // --- LOGO PICKER LOGIC ---
  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 500, // Square stability
      maxHeight: 500,
    );
    if (image != null) {
      setState(() => logoPath = image.path);
    }
  }

  void _saveAll(PharoahManager ph) {
    final newConfig = AppConfig(
      salePrefix: sPre.text.trim().toUpperCase(),
      saleChallanPrefix: scPre.text.trim().toUpperCase(),
      saleReturnPrefix: srPre.text.trim().toUpperCase(),
      purPrefix: pPre.text.trim().toUpperCase(),
      purReturnPrefix: prPre.text.trim().toUpperCase(),
      printFormat: selectedFormat,
      termsAndConditions: termsC.text.trim(),
      logoPath: logoPath,
    );
    ph.updateAppConfig(newConfig);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Settings Updated Successfully!"), backgroundColor: Colors.green));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("Global ERP Settings"),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: () => _saveAll(ph), icon: const Icon(Icons.save_rounded))
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- SECTION 1: LOGO SETUP ---
            _sectionHeader("SHOP LOGO (BILL HEADER)", Icons.image),
            _buildLogoCard(),

            const SizedBox(height: 25),

            // --- SECTION 2: PREFIX SETTINGS ---
            _sectionHeader("TRANSACTION PREFIXES", Icons.tag),
            _buildPrefixGrid(),

            const SizedBox(height: 25),

            // --- SECTION 3: PRINTING ---
            _sectionHeader("PRINTING & TERMS", Icons.print),
            _buildPrintSettings(),

            const SizedBox(height: 25),

            // --- SECTION 4: DATA MAINTENANCE ---
            _sectionHeader("NUMBERING MAINTENANCE", Icons.restart_alt),
            _buildResetCounterPanel(ph),

            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        color: Colors.white,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade900, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 55)),
          onPressed: () => _saveAll(ph),
          child: const Text("SAVE CONFIGURATION", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildLogoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          if (logoPath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(File(logoPath!), height: 80, width: 80, fit: BoxFit.cover),
            )
          else
            Container(height: 80, width: 80, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.store, size: 40, color: Colors.grey)),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(onPressed: _pickLogo, icon: const Icon(Icons.upload), label: const Text("Upload Logo")),
              if (logoPath != null)
                TextButton.icon(onPressed: () => setState(() => logoPath = null), icon: const Icon(Icons.delete, color: Colors.red), label: const Text("Remove", style: TextStyle(color: Colors.red))),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildPrefixGrid() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          Row(children: [
            Expanded(child: _input(sPre, "Sale Bill", "e.g. INV-")),
            const SizedBox(width: 10),
            Expanded(child: _input(scPre, "Sale Challan", "e.g. SCH-")),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _input(srPre, "Sale Return", "e.g. SRN-")),
            const SizedBox(width: 10),
            Expanded(child: _input(pPre, "Pur. Bill", "e.g. PUR-")),
          ]),
          const SizedBox(height: 10),
          _input(prPre, "Pur. Return", "e.g. PRN-"),
        ],
      ),
    );
  }

  Widget _buildPrintSettings() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          const Text("Select Default Print Format", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: [
              _formatOpt("A4 Professional", "A4"),
              const SizedBox(width: 10),
              _formatOpt("3-Inch Thermal", "Thermal"),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: termsC,
            maxLines: 3,
            decoration: const InputDecoration(labelText: "Billing Terms & Conditions", border: OutlineInputBorder()),
          ),
        ],
      ),
    );
  }

  Widget _buildResetCounterPanel(PharoahManager ph) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.red.shade100)),
      child: Column(
        children: [
          const Text("Danger Zone: Reset bill numbers to 1 for this dukan.", style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
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

  // --- UI COMPONENTS ---
  Widget _sectionHeader(String t, IconData i) => Padding(
    padding: const EdgeInsets.only(bottom: 10, left: 5),
    child: Row(children: [Icon(i, size: 16, color: Colors.blueGrey), const SizedBox(width: 8), Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1))]),
  );

  Widget _input(TextEditingController c, String l, String h) => TextField(controller: c, decoration: InputDecoration(labelText: l, hintText: h, border: const OutlineInputBorder(), isDense: true));

  Widget _formatOpt(String label, String value) {
    bool isSel = selectedFormat == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => selectedFormat = value),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: isSel ? Colors.indigo : Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(color: isSel ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ),
    );
  }

  Widget _resetBtn(String label, VoidCallback onReset) => TextButton(
    onPressed: () {
      showDialog(context: context, builder: (c) => AlertDialog(
        title: const Text("Reset Counter?"),
        content: Text("This will start $label numbering from 1. Proceed?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("NO")),
          TextButton(onPressed: () { onReset(); Navigator.pop(c); }, child: const Text("YES, RESET", style: TextStyle(color: Colors.red))),
        ],
      ));
    },
    child: Text(label, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11)),
  );
}
