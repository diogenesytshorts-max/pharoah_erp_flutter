import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'csv_engine.dart';

class DataExchangeView extends StatefulWidget {
  const DataExchangeView({super.key});

  @override
  State<DataExchangeView> createState() => _DataExchangeViewState();
}

class _DataExchangeViewState extends State<DataExchangeView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  // Helper to share files via WhatsApp/Mail
  Future<void> _exportAndShare(String csvData, String fileName) async {
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName.csv');
      await file.writeAsString(csvData);
      await Share.shareXFiles([XFile(file.path)], text: 'Pharoah ERP: $fileName');
    } catch (e) {
      debugPrint("Export Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("DATA EXCHANGE HUB"),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orange,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: "EXPORT (BAHIR)", icon: Icon(Icons.upload)),
            Tab(text: "IMPORT (ANDAR)", icon: Icon(Icons.download)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildExportTab(ph),
          _buildImportTab(ph),
        ],
      ),
    );
  }

  // --- TAB 1: EXPORT VIEW ---
  Widget _buildExportTab(PharoahManager ph) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _titleSection("BULK DATA EXPORT"),
        const SizedBox(height: 10),
        Row(
          children: [
            _actionBtn("Sale Register", Icons.file_upload, Colors.blue, () {
              String data = CsvEngine.convertSalesToCsv(ph.sales);
              _exportAndShare(data, "All_Sales_${ph.currentFY}");
            }),
            const SizedBox(width: 15),
            _actionBtn("Pur. Register", Icons.shopping_bag, Colors.orange, () {
              String data = CsvEngine.convertPurchasesToCsv(ph.purchases);
              _exportAndShare(data, "All_Purchases_${ph.currentFY}");
            }),
          ],
        ),
        const SizedBox(height: 30),
        _titleSection("EXPORT RECENT BILLS (SINGLE)"),
        const SizedBox(height: 10),
        if (ph.sales.isEmpty)
          const Center(child: Text("No records available to export."))
        else
          ...ph.sales.reversed.take(15).map((s) => Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              title: Text(s.partyName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("Inv: ${s.billNo} | Amt: ₹${s.totalAmount}"),
              trailing: const Icon(Icons.file_download, color: Colors.indigo),
              onTap: () {
                String data = CsvEngine.convertSalesToCsv([s]);
                _exportAndShare(data, "Bill_${s.billNo}");
              },
            ),
          )),
      ],
    );
  }

  // --- TAB 2: IMPORT VIEW ---
  Widget _buildImportTab(PharoahManager ph) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_download, size: 100, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            const Text(
              "CSV Import Utility", 
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 10),
            const Text(
              "Apni CSV file select karein. System naye items aur parties ko verify karne mein madad karega.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),
            _bigImportBtn("SELECT SALES CSV", Colors.green, () => _pickAndProcess(ph, "SALE")),
            const SizedBox(height: 15),
            _bigImportBtn("SELECT PURCHASE CSV", Colors.orange, () => _pickAndProcess(ph, "PURCHASE")),
          ],
        ),
      ),
    );
  }

  // File Picking Logic
  void _pickAndProcess(PharoahManager ph, String type) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      String content = await file.readAsString();
      List<List<dynamic>> rows = CsvEngine.parseCsv(content);

      if (mounted) {
        _showUnderConstruction(rows.length - 1);
      }
    }
  }

  // Temporary Alert until next phase
  void _showUnderConstruction(int count) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("File Read Success!"),
        content: Text("CSV mein $count records mile hain.\n\nPhase 2 mein hum 'Verification Screen' add karenge jahan aap Missing Parties/Items create kar sakenge."),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("OK"))],
      ),
    );
  }

  // --- UI COMPONENTS ---
  Widget _titleSection(String t) => Text(t, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1));

  Widget _actionBtn(String t, IconData i, Color c, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 25),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: c.withOpacity(0.3))),
          child: Column(children: [Icon(i, color: c, size: 30), const SizedBox(height: 10), Text(t, style: TextStyle(fontWeight: FontWeight.bold, color: c))]),
        ),
      ),
    );
  }

  Widget _bigImportBtn(String t, Color c, VoidCallback onTap) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: c, foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 65),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      onPressed: onTap,
      child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }
}
