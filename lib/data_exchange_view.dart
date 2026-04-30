import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'pharoah_manager.dart';
import 'csv_engine.dart';
import 'import_verification_view.dart';
import 'export_selector_view.dart';
import 'pharoah_ai_vision.dart'; // <--- YE IMPORT ZAROORI HAI

class DataExchangeView extends StatefulWidget {
  const DataExchangeView({super.key});
  @override State<DataExchangeView> createState() => _DataExchangeViewState();
}

class _DataExchangeViewState extends State<DataExchangeView> {
  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(title: const Text("DATA HUB / CSV EXCHANGE"), backgroundColor: Colors.indigo.shade900, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("SELECT DATA SOURCE", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1)),
          const SizedBox(height: 15),
          
          // --- OPTION 1: PHAROAH AI VISION (NEW) ---
          _buildMainActionCard(
            title: "PHAROAH AI VISION", 
            subtitle: "Scan physical bills using AI to auto-fill entries.", 
            icon: Icons.auto_awesome_rounded, 
            color: Colors.purple.shade700, 
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const PharoahAiVision()))
          ),

          const SizedBox(height: 20),
          
          // --- OPTION 2: PHAROAH CSV ---
          _buildMainActionCard(
            title: "PHAROAH CSV", 
            subtitle: "Import/Export in native Pharoah format for perfect sync.", 
            icon: Icons.account_tree_rounded, 
            color: Colors.blue.shade800, 
            onTap: () => _showOptions(context, ph, "PHAROAH")
          ),
          
          const SizedBox(height: 20),
          
          // --- OPTION 3: OTHER CSV ---
          _buildMainActionCard(
            title: "OTHER CSV", 
            subtitle: "Import from Distributors or generic Excel sheets.", 
            icon: Icons.grid_on_rounded, 
            color: Colors.teal.shade700, 
            onTap: () => _showOptions(context, ph, "OTHER")
          ),
        ]),
      ),
    );
  }

  // Baki functions (जैसे _showOptions, _buildMainActionCard) waise hi rahenge...
  void _showOptions(BuildContext context, PharoahManager ph, String mode) {
    showModalBottomSheet(
      context: context, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))), 
      builder: (c) => Container(
        padding: const EdgeInsets.all(25), 
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text("$mode DATA OPTIONS", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.indigo)),
          const Divider(height: 30),
          _subOptionTile(Icons.download_rounded, "Import Sale Bills", Colors.green, () { Navigator.pop(c); _pickFile(ph, "SALE", mode); }),
          _subOptionTile(Icons.shopping_cart_outlined, "Import Purchase Bills", Colors.orange, () { Navigator.pop(c); _pickFile(ph, "PURCHASE", mode); }),
          const Divider(),
          _subOptionTile(Icons.upload_rounded, "Export Sale Bills", Colors.blue, () { Navigator.pop(c); Navigator.push(context, MaterialPageRoute(builder: (c) => const ExportSelectorView(exportType: "SALE"))); }),
          _subOptionTile(Icons.inventory_2_outlined, "Export Purchase Bills", Colors.brown, () { Navigator.pop(c); Navigator.push(context, MaterialPageRoute(builder: (c) => const ExportSelectorView(exportType: "PURCHASE"))); }),
        ]),
      )
    );
  }

  void _pickFile(PharoahManager ph, String type, String mode) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom, 
      allowedExtensions: ['csv']
    );

    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      String content = await file.readAsString();
      
      // Smart Parsing
      List<List<dynamic>> rows = CsvEngine.parseCsv(content);
      
      if (mounted) {
        if (rows.isEmpty || rows.length < 2) { 
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("⚠️ Selected file is empty or invalid!"))
          ); 
          return; 
        }

        // --- NAVIGATION TO WIZARD ---
        Navigator.push(context, MaterialPageRoute(
          builder: (c) => ImportVerificationView(
            csvData: rows, 
            importType: type, // "SALE" or "PURCHASE"
            isOtherFormat: mode == "OTHER" // Detects if it's distributor file
          )
        ));
      }
    }
  }

  Widget _buildMainActionCard({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap, 
      borderRadius: BorderRadius.circular(20), 
      child: Container(
        padding: const EdgeInsets.all(20), 
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(20), 
          border: Border.all(color: color.withOpacity(0.2)), 
          boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]
        ), 
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 30)), 
            const SizedBox(width: 20), 
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)), const SizedBox(height: 5), Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey))])), 
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey)
          ]
        )
      )
    );
  }

  Widget _subOptionTile(IconData icon, String title, Color color, VoidCallback onTap) {
    return ListTile(leading: Icon(icon, color: color), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)), trailing: const Icon(Icons.chevron_right), onTap: onTap);
  }
}
