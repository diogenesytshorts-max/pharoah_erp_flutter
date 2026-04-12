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
import 'import_verification_view.dart';

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

  Future<void> _exportAndShare(String csvData, String fileName) async {
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName.csv');
      await file.writeAsString(csvData);
      await Share.shareXFiles([XFile(file.path)], text: 'Pharoah ERP Export: $fileName');
    } catch (e) {
      debugPrint("Export Error: $e");
    }
  }

  void _pickAndProcess(PharoahManager ph, String type) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      String content = await file.readAsString();
      List<List<dynamic>> rows = CsvEngine.parseCsv(content);

      if (mounted) {
        if (rows.length <= 1) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Selected file is empty!")));
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(builder: (c) => ImportVerificationView(csvData: rows, importType: type))
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
        title: const Text("DATA EXCHANGE HUB"),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orange,
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

  Widget _buildExportTab(PharoahManager ph) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text("BULK DATA EXPORT", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1)),
        const SizedBox(height: 10),
        Row(
          children: [
            _bulkBtn("SALES CSV", Icons.point_of_sale, Colors.blue, () => _exportAndShare(CsvEngine.convertSalesToCsv(ph.sales), "Full_Sales_${ph.currentFY}")),
            const SizedBox(width: 15),
            _bulkBtn("PURCHASE CSV", Icons.shopping_bag, Colors.orange, () => _exportAndShare(CsvEngine.convertPurchasesToCsv(ph.purchases), "Full_Purchase_${ph.currentFY}")),
          ],
        ),
        const SizedBox(height: 30),
        const Text("RECENT SALES (SINGLE EXPORT)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 10),
        ...ph.sales.reversed.take(15).map((s) => Card(
          child: ListTile(
            title: Text(s.partyName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Bill: ${s.billNo} | ₹${s.totalAmount}"),
            trailing: const Icon(Icons.share, color: Colors.blue),
            onTap: () => _exportAndShare(CsvEngine.convertSalesToCsv([s]), "Sale_${s.billNo}"),
          ),
        )),
      ],
    );
  }

  Widget _buildImportTab(PharoahManager ph) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        children: [
          const SizedBox(height: 30),
          _importBtn("IMPORT SALES CSV", "Sales entries record karein", Icons.add_shopping_cart, Colors.green, () => _pickAndProcess(ph, "SALE")),
          const SizedBox(height: 20),
          _importBtn("IMPORT PURCHASE CSV", "Stock aur Purchase jodein", Icons.download, Colors.orange, () => _pickAndProcess(ph, "PURCHASE")),
        ],
      ),
    );
  }

  Widget _bulkBtn(String t, IconData i, Color c, VoidCallback onTap) {
    return Expanded(child: InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: c.withOpacity(0.3))), child: Column(children: [Icon(i, color: c, size: 30), const SizedBox(height: 10), Text(t, style: TextStyle(fontWeight: FontWeight.bold, color: c, fontSize: 12))]))));
  }

  Widget _importBtn(String t, String s, IconData i, Color c, VoidCallback onTap) {
    return InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade300)), child: Row(children: [CircleAvatar(backgroundColor: c.withOpacity(0.1), child: Icon(i, color: c)), const SizedBox(width: 20), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontWeight: FontWeight.bold)), Text(s, style: const TextStyle(fontSize: 11, color: Colors.grey))])), const Icon(Icons.arrow_forward_ios, size: 14)])));
  }
}
