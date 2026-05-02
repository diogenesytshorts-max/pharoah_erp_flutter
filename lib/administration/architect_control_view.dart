// FILE: lib/administration/architect_control_view.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../pharoah_manager.dart';
import '../logic/app_settings_model.dart';
import 'series_master_view.dart';

class ArchitectControlView extends StatefulWidget {
  const ArchitectControlView({super.key});

  @override
  State<ArchitectControlView> createState() => _ArchitectControlViewState();
}

class _ArchitectControlViewState extends State<ArchitectControlView> {
  // Controllers to prevent UI jumping
  late TextEditingController labelC, nameC, numC, ifscC, bankC, termsC;

  @override
  void initState() {
    super.initState();
    final ph = Provider.of<PharoahManager>(context, listen: false);
    labelC = TextEditingController(text: ph.config.signLabel);
    nameC = TextEditingController(text: ph.config.bankAccName);
    numC = TextEditingController(text: ph.config.bankAccNumber);
    ifscC = TextEditingController(text: ph.config.bankIfsc);
    bankC = TextEditingController(text: ph.config.bankNameBranch);
    termsC = TextEditingController(text: ph.config.termsAndConditions);
  }

  // --- LOGIC: SAVE ALL ---
  void _saveSettings(PharoahManager ph) {
    final updated = ph.config;
    updated.signLabel = labelC.text;
    updated.bankAccName = nameC.text;
    updated.bankAccNumber = numC.text;
    updated.bankIfsc = ifscC.text;
    updated.bankNameBranch = bankC.text;
    updated.termsAndConditions = termsC.text;

    ph.updateAppConfig(updated);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("✅ System Configuration Updated!"),
      backgroundColor: Colors.green,
    ));
  }

  // --- LOGIC: IMAGE PICKER ---
  Future<void> _pickImage(PharoahManager ph, bool isLogo) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      if (isLogo) ph.config.logoPath = image.path;
      else ph.config.qrCodePath = image.path;
      ph.updateAppConfig(ph.config);
      setState(() {});
    }
  }

  // --- UI: CUSTOMER SIGN DIALOG ---
  void _showCustomerSignDialog(PharoahManager ph) {
    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Customer Signature Setup", style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Control receiver sign area on documents.", style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 15),
              SwitchListTile(
                title: const Text("Sale Challan Signature", style: TextStyle(fontWeight: FontWeight.bold)),
                value: ph.config.showCustomerSignChallan,
                onChanged: (v) {
                  setDialogState(() => ph.config.showCustomerSignChallan = v);
                  ph.updateAppConfig(ph.config);
                },
              )
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("DONE"))],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F9),
      appBar: AppBar(
        title: const Text("User Control Center", style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [IconButton(onPressed: () => _saveSettings(ph), icon: const Icon(Icons.save_rounded))],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // STEP 1: SERIES MASTER
            _architectCard(
              step: "01", title: "INVOICE SERIES ARCHITECT", icon: Icons.format_list_numbered_rounded, color: Colors.purple,
              child: Column(children: [
                _statusRow("Default Sale Prefix", ph.getDefaultSeries("SALE").prefix),
                const SizedBox(height: 15),
                _actionBtn("MANAGE NUMBERING SERIES", Icons.settings_rounded, Colors.purple.shade700, 
                  () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SeriesMasterView()))),
              ]),
            ),

            // STEP 2: SIGNATURES
            _architectCard(
              step: "02", title: "MASTER SIGNATURE CONTROL", icon: Icons.border_color_rounded, color: Colors.indigo,
              child: Column(children: [
                _switchTile("Enable Staff Signature", ph.config.showStaffSign, (v) {
                  ph.config.showStaffSign = v; ph.updateAppConfig(ph.config);
                }),
                _inputField(labelC, "Signature Label", "Authorised Signatory"),
                const SizedBox(height: 15),
                _actionBtn("CUSTOMER SIGNATURE", Icons.person_pin_rounded, Colors.indigo.shade800, () => _showCustomerSignDialog(ph)),
              ]),
            ),

            // STEP 3: LOGO
            _architectCard(
              step: "03", title: "LOGO & BRANDING ENGINE", icon: Icons.branding_watermark_rounded, color: Colors.blue,
              child: Column(children: [
                _switchTile("Show Logo on PDF", ph.config.showLogo, (v) {
                  ph.config.showLogo = v; ph.updateAppConfig(ph.config);
                }),
                _actionBtn("UPLOAD SHOP LOGO", Icons.add_a_photo_rounded, Colors.blue.shade700, () => _pickImage(ph, true)),
                if(ph.config.logoPath != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text("Logo selected: ...${ph.config.logoPath!.split('/').last}", style: const TextStyle(fontSize: 9, color: Colors.green, fontWeight: FontWeight.bold))),
              ]),
            ),

            // STEP 4: PRINT ENGINE
            _architectCard(
              step: "04", title: "SMART PRINT ENGINE", icon: Icons.print_rounded, color: Colors.pink.shade800,
              child: Row(children: [
                _formatTile("A4 PRO", "Landscape", "A4", Icons.description_outlined, ph),
                const SizedBox(width: 12),
                _formatTile("THERMAL", "3-Inch POS", "Thermal", Icons.receipt_long_rounded, ph),
              ]),
            ),

            // STEP 5: FINANCE
            _architectCard(
              step: "05", title: "FINANCIAL IDENTITY", icon: Icons.account_balance_rounded, color: Colors.teal,
              child: Column(children: [
                _switchTile("Enable UPI QR Code", ph.config.showQrCode, (v) {
                  ph.config.showQrCode = v; ph.updateAppConfig(ph.config);
                }),
                _actionBtn("UPLOAD UPI QR IMAGE", Icons.qr_code_scanner_rounded, Colors.teal.shade800, () => _pickImage(ph, false)),
                const SizedBox(height: 15),
                _inputField(nameC, "Account Holder Name", "Name"),
                _inputField(numC, "Bank Account Number", "Digits"),
                _inputField(ifscC, "IFSC Code", "SBIN..."),
                _inputField(bankC, "Bank Name & Branch", "Branch"),
              ]),
            ),

            // STEP 6: TERMS
            _architectCard(
              step: "06", title: "SMART TERMS & CONDITIONS", icon: Icons.gavel_rounded, color: Colors.orange.shade900,
              child: Column(children: [
                _switchTile("Display Terms", ph.config.showTerms, (v) {
                  ph.config.showTerms = v; ph.updateAppConfig(ph.config);
                }),
                const SizedBox(height: 10),
                TextField(
                  controller: termsC, maxLines: 3,
                  decoration: InputDecoration(hintText: "Enter Terms...", filled: true, fillColor: const Color(0xFFF9FAFB), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ]),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20), color: Colors.white,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A237E), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
          onPressed: () => _saveSettings(ph),
          child: const Text("SAVE ARCHITECT CONFIG", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  // --- UI BUILDERS ---
  Widget _architectCard({required String step, required String title, required IconData icon, required Color color, required Widget child}) => Container(
    margin: const EdgeInsets.only(bottom: 25),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))]),
    child: Column(children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15), decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: const BorderRadius.vertical(top: Radius.circular(25))), child: Row(children: [CircleAvatar(backgroundColor: color, radius: 15, child: Text(step, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))), const SizedBox(width: 12), Icon(icon, size: 20, color: color), const SizedBox(width: 10), Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: color))])),
      Padding(padding: const EdgeInsets.all(20), child: child),
    ]),
  );

  Widget _switchTile(String l, bool v, Function(bool) onChanged) => SwitchListTile(title: Text(l, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), value: v, onChanged: onChanged, contentPadding: EdgeInsets.zero, activeColor: Colors.green, dense: true);

  Widget _inputField(TextEditingController c, String l, String h) => Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: c, decoration: InputDecoration(labelText: l, hintText: h, isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))));

  Widget _actionBtn(String l, IconData i, Color c, VoidCallback onTap) => Container(width: double.infinity, height: 48, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(12)), child: TextButton.icon(onPressed: onTap, icon: Icon(i, color: Colors.white, size: 18), label: Text(l, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))));

  Widget _statusRow(String l, String v) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(color: Colors.grey, fontSize: 12)), Text(v, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))]);

  Widget _formatTile(String t, String s, String v, IconData i, PharoahManager ph) {
    bool isSel = ph.config.printFormat == v;
    return Expanded(child: InkWell(
      onTap: () { ph.config.printFormat = v; ph.updateAppConfig(ph.config); },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: isSel ? const Color(0xFF0D47A1) : Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: isSel ? const Color(0xFF0D47A1) : Colors.grey.shade300, width: 2)),
        child: Column(children: [Icon(i, color: isSel ? Colors.white : Colors.grey, size: 28), Text(t, style: TextStyle(color: isSel ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 12)), Text(s, style: TextStyle(color: isSel ? Colors.white70 : Colors.grey, fontSize: 8))]),
      ),
    ));
  }
}
