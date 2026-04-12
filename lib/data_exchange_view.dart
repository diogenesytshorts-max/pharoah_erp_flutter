import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'csv_engine.dart';
import 'import_verification_view.dart';

class DataExchangeView extends StatefulWidget {
  const DataExchangeView({super.key});
  @override State<DataExchangeView> createState() => _DataExchangeViewState();
}

class _DataExchangeViewState extends State<DataExchangeView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Party? selectedExportParty;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  // FIXED SHARE LOGIC: Adding mimeType ensures "Save to Files" appears
  Future<void> _exportAndShare(String csvData, String fileName) async {
    try {
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/$fileName.csv';
      final file = File(path);
      await file.writeAsString(csvData);
      
      await Share.shareXFiles(
        [XFile(path, mimeType: 'text/csv')],
        text: 'Export: $fileName',
        subject: fileName,
      );
    } catch (e) {
      debugPrint("Export Error: $e");
    }
  }

  // --- NEW: PARTY SEARCH DIALOG FOR FILTERED EXPORT ---
  void _showPartySearchDialog(List<Party> parties) {
    showDialog(
      context: context,
      builder: (c) {
        String query = "";
        return StatefulBuilder(builder: (context, setDialogState) {
          final list = parties.where((p) => p.name.toLowerCase().contains(query.toLowerCase())).toList();
          return AlertDialog(
            title: const Text("Select Party for Export"),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(hintText: "Search Party Name...", prefixIcon: Icon(Icons.search)),
                    onChanged: (v) => setDialogState(() => query = v),
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: list.length,
                      itemBuilder: (c, i) => ListTile(
                        title: Text(list[i].name),
                        onTap: () { setState(() => selectedExportParty = list[i]); Navigator.pop(c); },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("DATA HUB"),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: "EXPORT CSV"), Tab(text: "IMPORT CSV")],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildExportTab(ph), _buildImportTab(ph)],
      ),
    );
  }

  Widget _buildExportTab(PharoahManager ph) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // --- SECTION 1: FILTERED EXPORT ---
        const Text("PARTY-WISE EXPORT", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1)),
        const SizedBox(height: 10),
        InkWell(
          onTap: () => _showPartySearchDialog(ph.parties),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.indigo.shade100)),
            child: Row(children: [
              const Icon(Icons.person_search, color: Colors.indigo),
              const SizedBox(width: 15),
              Text(selectedExportParty?.name ?? "TAP TO SELECT PARTY / SUPPLIER", style: TextStyle(fontWeight: FontWeight.bold, color: selectedExportParty == null ? Colors.grey : Colors.indigo)),
              const Spacer(),
              const Icon(Icons.arrow_drop_down)
            ]),
          ),
        ),
        const SizedBox(height: 15),
        if (selectedExportParty != null) ...[
          Row(children: [
            Expanded(child: _actionBtn("PARTY SALES", Icons.upload, Colors.blue, () {
              var list = ph.sales.where((s) => s.partyName == selectedExportParty!.name).toList();
              _exportAndShare(CsvEngine.convertSalesToCsv(list), "${selectedExportParty!.name}_Sales");
            })),
            const SizedBox(width: 10),
            Expanded(child: _actionBtn("PARTY PURCHASE", Icons.download, Colors.orange, () {
              var list = ph.purchases.where((p) => p.distributorName == selectedExportParty!.name).toList();
              _exportAndShare(CsvEngine.convertPurchasesToCsv(list), "${selectedExportParty!.name}_Purchase");
            })),
          ]),
          Center(child: TextButton(onPressed: () => setState(() => selectedExportParty = null), child: const Text("Clear Filter", style: TextStyle(color: Colors.red)))),
        ],

        const Divider(height: 50),

        // --- SECTION 2: BULK EXPORT ---
        const Text("BULK DATA EXPORT (FULL YEAR)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 15),
        Row(
          children: [
            _bulkBtn("FULL SALES", Icons.all_inbox, Colors.blue, () => _exportAndShare(CsvEngine.convertSalesToCsv(ph.sales), "Full_Sales_${ph.currentFY}")),
            const SizedBox(width: 15),
            _bulkBtn("FULL PURCHASE", Icons.shopping_bag, Colors.orange, () => _exportAndShare(CsvEngine.convertPurchasesToCsv(ph.purchases), "Full_Purchase_${ph.currentFY}")),
          ],
        ),
      ],
    );
  }

  Widget _buildImportTab(PharoahManager ph) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(children: [
        const SizedBox(height: 30),
        _importCard("IMPORT SALES CSV", "Items will be grouped by Bill No.", Icons.add_shopping_cart, Colors.green, () => _pickAndProcess(ph, "SALE")),
        const SizedBox(height: 20),
        _importCard("IMPORT PURCHASE CSV", "Stock inward consolidation active.", Icons.download, Colors.orange, () => _pickAndProcess(ph, "PURCHASE")),
      ]),
    );
  }

  void _pickAndProcess(PharoahManager ph, String type) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      String content = await file.readAsString();
      List<List<dynamic>> rows = CsvEngine.parseCsv(content);
      if (mounted) {
        if (rows.length <= 1) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("File is empty!"))); return; }
        Navigator.push(context, MaterialPageRoute(builder: (c) => ImportVerificationView(csvData: rows, importType: type)));
      }
    }
  }

  Widget _actionBtn(String t, IconData i, Color c, VoidCallback onTap) {
    return ElevatedButton.icon(onPressed: onTap, icon: Icon(i, size: 18), label: Text(t, style: const TextStyle(fontSize: 11)), style: ElevatedButton.styleFrom(backgroundColor: c, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)));
  }

  Widget _bulkBtn(String t, IconData i, Color c, VoidCallback onTap) {
    return Expanded(child: InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: c.withOpacity(0.3))), child: Column(children: [Icon(i, color: c, size: 30), const SizedBox(height: 10), Text(t, style: TextStyle(fontWeight: FontWeight.bold, color: c, fontSize: 10))]))));
  }

  Widget _importCard(String t, String s, IconData i, Color c, VoidCallback onTap) {
    return InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade300)), child: Row(children: [CircleAvatar(backgroundColor: c.withOpacity(0.1), child: Icon(i, color: c)), const SizedBox(width: 20), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontWeight: FontWeight.bold)), Text(s, style: const TextStyle(fontSize: 11, color: Colors.grey))])), const Icon(Icons.arrow_forward_ios, size: 14)])));
  }
}
