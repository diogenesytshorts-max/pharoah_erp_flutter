import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

// App Imports
import 'pharoah_manager.dart';
import 'models.dart';
import 'csv_engine.dart';
import 'import_verification_view.dart';
import 'widgets.dart'; // ActionIconBtn ke liye agar dashboard jaisa style chahiye

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
    // 2 Tabs: Export (Bahar) aur Import (Andar)
    _tabController = TabController(length: 2, vsync: this);
  }

  // --- LOGIC: CSV FILE SHARE ---
  Future<void> _exportAndShare(String csvData, String fileName) async {
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName.csv');
      await file.writeAsString(csvData);
      
      await Share.shareXFiles(
        [XFile(file.path)], 
        text: 'Pharoah ERP Data Export: $fileName'
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Export Failed: $e"), backgroundColor: Colors.red)
      );
    }
  }

  // --- LOGIC: FILE PICKER & NAVIGATE TO VERIFICATION ---
  void _pickAndProcess(PharoahManager ph, String type) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      String content = await file.readAsString();
      
      // CSV Engine se list mein badalna
      List<List<dynamic>> rows = CsvEngine.parseCsv(content);

      if (mounted) {
        if (rows.length <= 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Selected file is empty or invalid!"))
          );
          return;
        }

        // Verification Screen par bhejna (Phase 2 Screen)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (c) => ImportVerificationView(csvData: rows, importType: type),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("DATA EXCHANGE HUB", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orange,
          indicatorWeight: 4,
          tabs: const [
            Tab(text: "EXPORT (SEND)", icon: Icon(Icons.upload_rounded)),
            Tab(text: "IMPORT (RECEIVE)", icon: Icon(Icons.download_rounded)),
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

  // ==========================================
  // TAB 1: EXPORT (DATA BAHAR BHEJNA)
  // ==========================================
  Widget _buildExportTab(PharoahManager ph) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _sectionHeader("BULK DATA EXPORT (FULL REGISTER)"),
        const SizedBox(height: 10),
        Row(
          children: [
            _bulkExportCard(
              "SALES CSV", 
              Icons.point_of_sale, 
              Colors.blue.shade700, 
              () => _exportAndShare(CsvEngine.convertSalesToCsv(ph.sales), "Full_Sales_${ph.currentFY}")
            ),
            const SizedBox(width: 15),
            _bulkExportCard(
              "PURCHASE CSV", 
              Icons.shopping_bag, 
              Colors.orange.shade800, 
              () => _exportAndShare(CsvEngine.convertPurchasesToCsv(ph.purchases), "Full_Purchase_${ph.currentFY}")
            ),
          ],
        ),
        
        const SizedBox(height: 35),
        _sectionHeader("SINGLE BILL EXPORT (SELECT FROM LIST)"),
        const SizedBox(height: 10),
        
        if (ph.sales.isEmpty)
          _emptyState("No bills found to export.")
        else
          ...ph.sales.reversed.take(20).map((s) => Card(
            margin: const EdgeInsets.only(bottom: 10),
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.indigo.shade50,
                child: const Icon(Icons.receipt_long, color: Colors.indigo, size: 20),
              ),
              title: Text(s.partyName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text("Bill: ${s.billNo} | Date: ${DateFormat('dd/MM/yy').format(s.date)}\nTotal: ₹${s.totalAmount}"),
              trailing: IconButton(
                icon: const Icon(Icons.share, color: Colors.blue),
                onPressed: () => _exportAndShare(CsvEngine.convertSalesToCsv([s]), "Sale_Bill_${s.billNo}"),
              ),
            ),
          )),
      ],
    );
  }

  // ==========================================
  // TAB 2: IMPORT (DATA ANDAR LANA)
  // ==========================================
  Widget _buildImportTab(PharoahManager ph) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Icon(Icons.cloud_download_rounded, size: 80, color: Colors.indigo.withOpacity(0.2)),
          const SizedBox(height: 20),
          const Text(
            "Select CSV file to import data into Pharoah ERP.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.blueGrey),
          ),
          const SizedBox(height: 40),
          
          _importActionBtn(
            "IMPORT SALES CSV", 
            "CSV se Sales entries auto-fill karein", 
            Icons.add_shopping_cart_rounded, 
            Colors.green.shade700, 
            () => _pickAndProcess(ph, "SALE")
          ),
          
          const SizedBox(height: 20),
          
          _importActionBtn(
            "IMPORT PURCHASE CSV", 
            "Supplier bill ko inventory mein jodein", 
            Icons.file_download_outlined, 
            Colors.orange.shade700, 
            () => _pickAndProcess(ph, "PURCHASE")
          ),
          
          const SizedBox(height: 50),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade100)
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Import ke waqt system naye Party aur Medicine ko pehchan kar wahi banane ka option dega.",
                    style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- UI HELPERS ---

  Widget _sectionHeader(String t) => Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1));

  Widget _emptyState(String msg) => Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(msg, style: const TextStyle(color: Colors.grey))));

  Widget _bulkExportCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 25),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: color.withOpacity(0.2)),
            boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 10)]
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 12),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _importActionBtn(String title, String sub, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
                  Text(sub, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
