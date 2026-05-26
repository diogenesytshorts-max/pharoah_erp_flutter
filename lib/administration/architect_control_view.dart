// FILE: lib/administration/architect_control_view.dart (FINAL UPDATED VERSION)

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart'; // 🔥 NAYA IMPORT
import '../../pharoah_manager.dart';
import '../logic/app_settings_model.dart';
import 'series_master_view.dart';

class ArchitectControlView extends StatefulWidget {
  const ArchitectControlView({super.key});

  @override
  State<ArchitectControlView> createState() => _ArchitectControlViewState();
}

class _ArchitectControlViewState extends State<ArchitectControlView> {
  // 1. Core Controllers
  late TextEditingController labelC, nameC, numC, ifscC, bankC, termsC;
  
  // 2. Email Controllers
  late TextEditingController emailC, passC, hostC, portC;

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
    
    emailC = TextEditingController(text: ph.config.smtpEmail);
    passC = TextEditingController(text: ph.config.smtpPassword);
    hostC = TextEditingController(text: ph.config.smtpHost);
    portC = TextEditingController(text: ph.config.smtpPort.toString());
  }

  // ===========================================================================
  // 📧 NAYA: EMAIL SETUP HELPERS (LINK & GUIDE)
  // ===========================================================================

  // 1. Browser me Google Link kholne ke liye
  Future<void> _launchGmailSecurity() async {
    final Uri url = Uri.parse('https://myaccount.google.com/apppasswords');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not open browser. Check Internet.")));
    }
  }

  // 2. Step-by-Step Guide Dialog
  void _showEmailSetupGuide() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: const Row(children: [Icon(Icons.auto_awesome, color: Colors.orange), SizedBox(width: 10), Text("Quick Email Setup")]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Google security requires an 'App Password' for ERP billing. Regular passwords won't work.", style: TextStyle(fontSize: 11, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            _stepRow("1", "Go to your Google Account > Security."),
            _stepRow("2", "Enable '2-Step Verification' (If OFF)."),
            _stepRow("3", "Search for 'App Passwords' in Search Bar."),
            _stepRow("4", "Type 'Pharoah ERP' as App Name."),
            _stepRow("5", "Copy the 16-digit code & paste it here."),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("GOT IT")),
          ElevatedButton(onPressed: () { Navigator.pop(c); _launchGmailSecurity(); }, child: const Text("OPEN LINK")),
        ],
      ),
    );
  }

  Widget _stepRow(String num, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CircleAvatar(radius: 9, backgroundColor: Colors.indigo, child: Text(num, style: const TextStyle(fontSize: 9, color: Colors.white))),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 11))),
    ]),
  );

  // --- LOGIC: SAVE ALL ---
  void _saveSettings(PharoahManager ph) {
    final updated = ph.config;
    updated.signLabel = labelC.text.trim();
    updated.bankAccName = nameC.text.trim();
    updated.bankAccNumber = numC.text.trim();
    updated.bankIfsc = ifscC.text.trim();
    updated.bankNameBranch = bankC.text.trim();
    updated.termsAndConditions = termsC.text.trim();
    
    updated.smtpEmail = emailC.text.trim();
    updated.smtpPassword = passC.text.trim();
    updated.smtpHost = hostC.text.trim();
    updated.smtpPort = int.tryParse(portC.text) ?? 587;

    ph.updateAppConfig(updated); 
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("✅ All Settings Synchronized!"),
      backgroundColor: Colors.indigo,
    ));
  }

  // --- LOGIC: IMAGE PICKER ---
  Future<void> _pickImage(PharoahManager ph, bool isLogo) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image != null) {
      if (isLogo) ph.config.logoPath = image.path;
      else ph.config.qrCodePath = image.path;
      ph.updateAppConfig(ph.config);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F9),
      appBar: AppBar(
        title: const Text("Architect Control Center", style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [IconButton(onPressed: () => _saveSettings(ph), icon: const Icon(Icons.save_rounded))],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildArchitectMasterBanner(ph),
            const SizedBox(height: 25),

            // STEP 01: SERIES
            _architectCard(
              step: "01", title: "INVOICE SERIES ARCHITECT", icon: Icons.format_list_numbered_rounded, color: Colors.purple,
              child: Column(children: [
                _statusRow("Current Billing Series", ph.getDefaultSeries("SALE").name),
                const SizedBox(height: 15),
                _actionBtn("MANAGE NUMBERING SERIES", Icons.settings_rounded, Colors.purple.shade700, 
                  () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SeriesMasterView()))),
              ]),
            ),

            // STEP 02: SIGNATURES
            _architectCard(
              step: "02", title: "MASTER SIGNATURE CONTROL", icon: Icons.border_color_rounded, color: Colors.indigo,
              child: Column(children: [
                _switchTile("Enable Staff Signature", "Authorised Signatory area", ph.config.showStaffSign, (v) {
                  ph.config.showStaffSign = v; ph.updateAppConfig(ph.config);
                }),
                _inputField(labelC, "Signature Label", "Authorised Signatory"),
              ]),
            ),

            // STEP 03: LOGO
            _architectCard(
              step: "03", title: "LOGO & BRANDING ENGINE", icon: Icons.branding_watermark_rounded, color: Colors.blue,
              child: Column(children: [
                _switchTile("Show Logo on PDF", "Global branding visibility", ph.config.showLogo, (v) {
                  ph.config.showLogo = v; ph.updateAppConfig(ph.config);
                }),
                _actionBtn("UPLOAD SHOP LOGO", Icons.add_a_photo_rounded, Colors.blue.shade700, () => _pickImage(ph, true)),
                if(ph.config.logoPath != null) _imageIndicator(ph.config.logoPath!),
              ]),
            ),

            // STEP 04: PRINT FORMAT
            _architectCard(
              step: "04", title: "SMART PRINT ENGINE", icon: Icons.print_rounded, color: Colors.pink.shade800,
              child: Row(children: [
                _formatTile("A4 PRO", "A4", Icons.description_outlined, ph),
                const SizedBox(width: 12),
                _formatTile("THERMAL", "Thermal", Icons.receipt_long_rounded, ph),
              ]),
            ),

            // 🔥 STEP 08: EMAIL AUTOMATION ENGINE (THE UPDATED HUB)
            _architectCard(
              step: "05", title: "EMAIL AUTOMATION HUB", icon: Icons.alternate_email_rounded, color: Colors.deepOrange,
              child: Column(children: [
                _switchTile("Activate Email Service", "Send bills directly from ERP", ph.config.isEmailActive, (v) {
                  ph.config.isEmailActive = v; ph.updateAppConfig(ph.config);
                }),
                const SizedBox(height: 10),
                _inputField(emailC, "Sender Gmail ID", "dukan@gmail.com"),
                _inputField(passC, "App Password (16-Digit)", "xxxx xxxx xxxx xxxx", isPass: true),
                
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showEmailSetupGuide,
                      icon: const Icon(Icons.help_outline, size: 16),
                      label: const Text("SETUP GUIDE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _launchGmailSecurity,
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text("GENERATE LINK", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
                    ),
                  ),
                ]),
                const SizedBox(height: 15),
                Row(children: [
                  Expanded(child: _inputField(hostC, "SMTP Host", "smtp.gmail.com")),
                  const SizedBox(width: 10),
                  Expanded(child: _inputField(portC, "Port", "587", isNum: true)),
                ]),
              ]),
            ),

            // STEP 05: FINANCE
            _architectCard(
              step: "06", title: "FINANCIAL IDENTITY", icon: Icons.account_balance_rounded, color: Colors.teal,
              child: Column(children: [
                _switchTile("Enable UPI QR Code", "Scan-to-pay on bills", ph.config.showQrCode, (v) {
                  ph.config.showQrCode = v; ph.updateAppConfig(ph.config);
                }),
                _actionBtn("UPLOAD UPI QR IMAGE", Icons.qr_code_scanner_rounded, Colors.teal.shade800, () => _pickImage(ph, false)),
                const SizedBox(height: 15),
                _inputField(nameC, "Account Holder Name", "Name on Bank"),
                _inputField(numC, "Bank Account Number", "Digits"),
                _inputField(ifscC, "IFSC Code", "SBIN000XXXX"),
              ]),
            ),

            // STEP 07: TERMS
            _architectCard(
              step: "07", title: "SMART TERMS & CONDITIONS", icon: Icons.gavel_rounded, color: Colors.orange.shade900,
              child: Column(children: [
                _switchTile("Display Terms", "Show rules at bottom", ph.config.showTerms, (v) {
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
          child: const Text("SAVE FULL CONFIGURATION", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
        ),
      ),
    );
  }

  // --- UI HELPERS ---

  Widget _buildArchitectMasterBanner(PharoahManager ph) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.indigo.shade900, Colors.indigo.shade700]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: SwitchListTile(
        title: const Text("ACTIVATE ARCHITECT SERIES", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: const Text("Switch to advanced precision layout", style: TextStyle(color: Colors.white70, fontSize: 11)),
        value: ph.config.isArchitectMode,
        activeColor: Colors.cyanAccent,
        onChanged: (v) { ph.config.isArchitectMode = v; ph.updateAppConfig(ph.config); },
      ),
    );
  }

  Widget _architectCard({required String step, required String title, required IconData icon, required Color color, required Widget child}) => Container(
    margin: const EdgeInsets.only(bottom: 25),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 10))]),
    child: Column(children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15), decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: const BorderRadius.vertical(top: Radius.circular(25))), child: Row(children: [CircleAvatar(backgroundColor: color, radius: 15, child: Text(step, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))), const SizedBox(width: 12), Icon(icon, size: 20, color: color), const SizedBox(width: 10), Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: color))])),
      Padding(padding: const EdgeInsets.all(20), child: child),
    ]),
  );

  Widget _switchTile(String l, String s, bool v, Function(bool) onChanged) => SwitchListTile(title: Text(l, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), subtitle: Text(s, style: const TextStyle(fontSize: 11, color: Colors.grey)), value: v, onChanged: onChanged, contentPadding: EdgeInsets.zero, activeColor: Colors.green, dense: true);

  // 🔥 FIXED HELPER: added isNum and isPass support
  Widget _inputField(TextEditingController c, String l, String h, {bool isNum = false, bool isPass = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 12), 
    child: TextField(
      controller: c, obscureText: isPass,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: l, hintText: h, isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))
    )
  );

  Widget _actionBtn(String l, IconData i, Color c, VoidCallback onTap) => Container(width: double.infinity, height: 48, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(12)), child: TextButton.icon(onPressed: onTap, icon: Icon(i, color: Colors.white, size: 18), label: Text(l, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))));

  Widget _statusRow(String l, String v) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(color: Colors.grey, fontSize: 12)), Text(v, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))]);

  Widget _imageIndicator(String path) => Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [const Icon(Icons.check_circle, color: Colors.green, size: 14), const SizedBox(width: 5), Text("Selected: ${path.split('/').last}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey))]));

  Widget _formatTile(String t, String v, IconData i, PharoahManager ph) {
    bool isSel = ph.config.printFormat == v;
    return Expanded(child: InkWell(
      onTap: () { ph.config.printFormat = v; ph.updateAppConfig(ph.config); },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: isSel ? const Color(0xFF0D47A1) : Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: isSel ? const Color(0xFF0D47A1) : Colors.grey.shade300, width: 2)),
        child: Column(children: [Icon(i, color: isSel ? Colors.white : Colors.grey, size: 24), Text(t, style: TextStyle(color: isSel ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 10))]),
      ),
    ));
  }
}
