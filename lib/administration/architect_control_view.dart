// FILE: lib/administration/architect_control_view.dart (UPDATED WITH 2-WAY DRIVE SYNC & HINDI GUIDE)

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart'; 
import '../../pharoah_manager.dart';
import '../logic/app_settings_model.dart';
import '../logic/google_drive_sync_service.dart';
import 'series_master_view.dart';

class ArchitectControlView extends StatefulWidget {
  const ArchitectControlView({super.key});

  @override
  State<ArchitectControlView> createState() => _ArchitectControlViewState();
}

class _ArchitectControlViewState extends State<ArchitectControlView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Controllers
  late TextEditingController labelC, nameC, numC, ifscC, bankC, termsC;
  late TextEditingController emailC, passC, hostC, portC;
  late TextEditingController webUrlC, driveWebhookC, driveEmailC;

  bool isSyncing = false;

  @override
  void initState() {
    super.initState();
    // 5 Tabs (Web Server, Branding, Signatures, Finance, Mail Setup)
    _tabController = TabController(length: 5, vsync: this);
    
    final ph = Provider.of<PharoahManager>(context, listen: false);
    
    labelC = TextEditingController(text: ph.config.signLabel);
    nameC = TextEditingController(text: ph.config.bankAccName);
    numC = TextEditingController(text: ph.config.bankAccNumber);
    ifscC = TextEditingController(text: ph.config.bankIfsc);
    bankC = TextEditingController(text: ph.config.bankNameBranch);
    termsC = TextEditingController(text: ph.config.termsAndConditions);
    
    emailC = TextEditingController(text: ph.config.smtpMailID);
    passC = TextEditingController(text: ph.config.smtpMailPass);
    hostC = TextEditingController(text: ph.config.smtpHost);
    portC = TextEditingController(text: ph.config.smtpPort.toString());
    
    // Live Cloudflare Website URL & Drive Hook
    webUrlC = TextEditingController(text: "https://pharoah-erp-flutter.diogenesytshorts.workers.dev");
    driveWebhookC = TextEditingController(text: ph.config.smtpHost.startsWith("http") ? ph.config.smtpHost : "");
    driveEmailC = TextEditingController(text: ph.activeCompany?.email ?? "");
  }

  @override
  void dispose() {
    labelC.dispose();
    nameC.dispose();
    numC.dispose();
    ifscC.dispose();
    bankC.dispose();
    termsC.dispose();
    emailC.dispose();
    passC.dispose();
    hostC.dispose();
    portC.dispose();
    webUrlC.dispose();
    driveWebhookC.dispose();
    driveEmailC.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _launchWebPortal() async {
    final Uri url = Uri.parse(webUrlC.text.trim());
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not launch web portal.")));
      }
    }
  }

  // --- 🔄 2-WAY SYNC ACTIONS ---
  Future<void> _pushAppToDrive(PharoahManager ph) async {
    String url = driveWebhookC.text.trim();
    String email = driveEmailC.text.trim();

    if (url.isEmpty || !url.startsWith("http")) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("कृपया सही Google Apps Script Webhook URL दर्ज करें!"), backgroundColor: Colors.orange));
      return;
    }

    setState(() => isSyncing = true);
    bool success = await GoogleDriveSyncService.pushDataToDrive(webhookUrl: url, userEmail: email, ph: ph);
    setState(() => isSyncing = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? "✅ ऐप का डेटा Google Drive में सफलतापूर्वक सिंक हुआ!" : "❌ सिंक नहीं हो सका। URL चेक करें।"),
        backgroundColor: success ? Colors.green : Colors.red,
      ));
    }
  }

  Future<void> _pullWebFromDrive(PharoahManager ph) async {
    String url = driveWebhookC.text.trim();
    String email = driveEmailC.text.trim();

    if (url.isEmpty || !url.startsWith("http")) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("कृपया सही Google Apps Script Webhook URL दर्ज करें!"), backgroundColor: Colors.orange));
      return;
    }

    setState(() => isSyncing = true);
    bool success = await GoogleDriveSyncService.pullDataFromDrive(webhookUrl: url, userEmail: email, ph: ph);
    setState(() => isSyncing = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? "✅ वेबसाइट के नए बिल Google Drive से ऐप में आ गए!" : "ℹ️ कोई नया डेटा नहीं मिला।"),
        backgroundColor: success ? Colors.green : Colors.blueGrey,
      ));
    }
  }

  // --- 📖 HINDI USER MANUAL GUIDE MODAL ---
  void _showHindiUserGuide() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: const Row(
          children: [
            Icon(Icons.menu_book_rounded, color: Colors.cyanAccent),
            SizedBox(width: 10),
            Text("हिंदी यूजर गाइड (ERP Manual)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _guideSection("1. 2-वे सिंक (Web ⟷ App)", "आप चाहे कंप्यूटर पर वेबसाइट खोलकर बिल बनाएं या मोबाइल ऐप से, दोनों का डेटा आपके Google Drive के जरिए हमेशा एक जैसा रहेगा।"),
              _guideSection("2. 10 अलग-अलग यूजर्स की प्राइवेसी", "हर दुकानदार का डेटा उसके अपने Gmail / Google Drive में सेव रहता है। कोई दूसरा दुकानदार आपका डेटा कभी नहीं देख सकता।"),
              _guideSection("3. ऑफलाइन सुरक्षा", "अगर इंटरनेट नहीं है या आपने स्विच OFF कर दिया है, तो ऐप 100% ऑफलाइन चलेगी और कोई डेटा बाहर नहीं जाएगा।"),
              _guideSection("4. प्रिंटिंग सपोर्ट", "A4 फुल साइज इनवॉइस या 80mm थर्मल रोल प्रिंटर दोनों को सपोर्ट करता है।"),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(c), 
            child: const Text("समझ गया (OK)", style: TextStyle(fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }

  Widget _guideSection(String title, String desc) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 12)),
        const SizedBox(height: 3),
        Text(desc, style: const TextStyle(fontSize: 11, color: Colors.black87, height: 1.4)),
      ],
    ),
  );

  void _saveSettings(PharoahManager ph) {
    final updated = ph.config;
    updated.signLabel = labelC.text.trim();
    updated.bankAccName = nameC.text.trim();
    updated.bankAccNumber = numC.text.trim();
    updated.bankIfsc = ifscC.text.trim();
    updated.bankNameBranch = bankC.text.trim();
    updated.termsAndConditions = termsC.text.trim();
    
    updated.smtpMailID = emailC.text.trim();
    updated.smtpMailPass = passC.text.trim();
    updated.smtpHost = hostC.text.trim();
    updated.smtpPort = int.tryParse(portC.text) ?? 587;

    ph.updateAppConfig(updated); 
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("✅ All Settings & Web Server Synchronized!"),
      backgroundColor: Colors.indigo,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), 
      appBar: AppBar(
        title: const Text("Architect Control & Web Live Hub", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white)),
        backgroundColor: const Color(0xFF1E1B4B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded, color: Colors.cyanAccent),
            tooltip: "हिंदी यूजर गाइड",
            onPressed: _showHindiUserGuide,
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF1E1B4B),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: Colors.cyanAccent,
              labelColor: Colors.cyanAccent,
              unselectedLabelColor: Colors.white54,
              tabs: const [
                Tab(icon: Icon(Icons.language_rounded, size: 20), text: "Web Server"),
                Tab(icon: Icon(Icons.palette_rounded, size: 20), text: "Branding"),
                Tab(icon: Icon(Icons.security, size: 20), text: "Signatures"),
                Tab(icon: Icon(Icons.account_balance_rounded, size: 20), text: "Finance"),
                Tab(icon: Icon(Icons.alternate_email_rounded, size: 20), text: "Mail Setup"),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildWebServerTab(ph),
                _buildBrandingTab(ph),
                _buildSignaturesTab(ph),
                _buildFinanceTab(ph),
                _buildMailSetupTab(ph),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildSaveBar(ph),
    );
  }

  // --- 🌐 TAB 1: WEB LIVE SERVER & CLOUDFLARE PORTAL HUB ---
  Widget _buildWebServerTab(PharoahManager ph) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildCardHeader("CLOUDFLARE LIVE WEB SERVER & 2-WAY SYNC", Icons.language_rounded, Colors.cyanAccent),
        const SizedBox(height: 10),
        
        // Master Toggle Switch
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("Enable Cloud Web Server Sync", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: const Text("Toggles real-time 2-way sync with Google Drive and Web POS", style: TextStyle(color: Colors.white54, fontSize: 11)),
          value: ph.config.isArchitectMode,
          onChanged: (v) {
            ph.config.isArchitectMode = v;
            ph.updateAppConfig(ph.config);
            setState(() {});
          },
          activeColor: Colors.cyanAccent,
        ),
        
        const Divider(color: Colors.white10, height: 30),

        // Live Web Portal Launcher Link
        _buildInputField(webUrlC, "Cloudflare Live Website URL"),
        const SizedBox(height: 10),
        
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black, minimumSize: const Size(double.infinity, 45)),
                onPressed: _launchWebPortal,
                icon: const Icon(Icons.open_in_browser_rounded),
                label: const Text("OPEN LIVE WEBSITE", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.cyanAccent, side: const BorderSide(color: Colors.cyanAccent), minimumSize: const Size(double.infinity, 45)),
                onPressed: _showHindiUserGuide,
                icon: const Icon(Icons.menu_book_rounded),
                label: const Text("📖 हिंदी यूजर गाइड"),
              ),
            ),
          ],
        ),

        const Divider(color: Colors.white10, height: 35),
        _buildCardHeader("GOOGLE DRIVE 2-WAY CLOUD SYNC", Icons.cloud_sync_rounded, Colors.greenAccent),
        const SizedBox(height: 10),

        _buildInputField(driveEmailC, "Your Gmail ID (User Email)"),
        _buildInputField(driveWebhookC, "Google Apps Script Webhook URL"),

        const SizedBox(height: 10),
        if (isSyncing)
          const Center(child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(color: Colors.cyanAccent)))
        else
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent.shade700, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 45)),
                  onPressed: () => _pushAppToDrive(ph),
                  icon: const Icon(Icons.cloud_upload_rounded),
                  label: const Text("PUSH TO DRIVE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent.shade700, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 45)),
                  onPressed: () => _pullWebFromDrive(ph),
                  icon: const Icon(Icons.cloud_download_rounded),
                  label: const Text("PULL FROM DRIVE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ),
            ],
          ),

        const SizedBox(height: 25),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.shield_rounded, color: Colors.greenAccent, size: 18),
                  SizedBox(width: 8),
                  Text("MULTI-TENANT 100% ISOLATION", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                ],
              ),
              SizedBox(height: 6),
              Text(
                "सभी 10 यूज़र्स का डेटा उनके व्यक्तिगत Google Drive में सुरक्षित और अलग रहेगा। जब स्विच OFF होगा तो कोई भी डेटा बाहर सिंक नहीं होगा।",
                style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- BRANDING TAB ---
  Widget _buildBrandingTab(PharoahManager ph) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildCardHeader("BRANDING & DOCUMENT STYLE", Icons.palette_rounded, Colors.purple),
        _buildSwitchTile("Show Shop Logo on PDF", "Toggles top branding block", ph.config.showLogo, (v) {
          ph.config.showLogo = v; ph.updateAppConfig(ph.config);
        }),
        const SizedBox(height: 15),
        _buildInputField(termsC, "Terms & Conditions Rules", maxLines: 3),
      ],
    );
  }

  // --- SIGNATURES TAB ---
  Widget _buildSignaturesTab(PharoahManager ph) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildCardHeader("SIGNATURE & SERIES AUDIT", Icons.security, Colors.blue),
        _buildSwitchTile("Enable Staff Signature", "Toggles signature drawing screen in challans", ph.config.showCustomerSignChallan, (v) {
          ph.config.showCustomerSignChallan = v; ph.updateAppConfig(ph.config);
        }),
        _buildSwitchTile("Show Authorised Signatory Block", "Requires receiver's stamp area on bills", ph.config.showStaffSign, (v) {
          ph.config.showStaffSign = v; ph.updateAppConfig(ph.config);
        }),
        const SizedBox(height: 15),
        _buildInputField(labelC, "Authorised Signatory Designation"),
        const SizedBox(height: 15),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SeriesMasterView())),
          icon: const Icon(Icons.settings),
          label: const Text("MANAGE NUMBERING SCHEMES"),
        ),
      ],
    );
  }

  // --- FINANCE TAB ---
  Widget _buildFinanceTab(PharoahManager ph) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildCardHeader("PAYMENT GATEWAY CONFIG", Icons.account_balance_rounded, Colors.teal),
        _buildInputField(nameC, "Beneficiary Name"),
        _buildInputField(bankC, "Bank Name & Branch"),
        _buildInputField(numC, "Account Number", isNum: true),
        _buildInputField(ifscC, "IFSC Code"),
      ],
    );
  }

  // --- MAIL SETUP TAB ---
  Widget _buildMailSetupTab(PharoahManager ph) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildCardHeader("SMTP MAIL AUTOMATION HUB", Icons.alternate_email_rounded, Colors.deepOrange),
        _buildInputField(emailC, "Sender Mail ID"),
        _buildInputField(passC, "Google App Password (16-Digit)", isPass: true),
        _buildInputField(hostC, "SMTP Host"),
        _buildInputField(portC, "SMTP Port", isNum: true),
      ],
    );
  }

  Widget _buildCardHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color, letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildSwitchTile(String title, String sub, bool val, ValueChanged<bool> onChange) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(sub, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      value: val,
      onChanged: onChange,
      activeColor: Colors.cyanAccent,
    );
  }

  Widget _buildInputField(TextEditingController ctrl, String label, {bool isNum = false, bool isPass = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        obscureText: isPass,
        maxLines: maxLines,
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          filled: true,
          fillColor: const Color(0xFF1E293B),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildSaveBar(PharoahManager ph) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: const Color(0xFF1E1B4B),
      child: Row(
        children: [
          const Expanded(child: Text("Live Web Server sync settings updated automatically.", style: TextStyle(color: Colors.white54, fontSize: 11))),
          const SizedBox(width: 15),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => _saveSettings(ph),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Text("SAVE SETTINGS", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}
