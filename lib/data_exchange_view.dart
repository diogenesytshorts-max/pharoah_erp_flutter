import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
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
  
  // --- FILTERS & STATE ---
  DateTime fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime toDate = DateTime.now();
  String exportType = "SALES"; // "SALES" or "PURCHASE"
  List<String> selectedIds = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  // --- CSV GENERATE AUR SHARE LOGIC ---
  Future<void> _generateAndShare(List<dynamic> filteredData) async {
    if (filteredData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No bills selected!")));
      return;
    }

    try {
      String csvData = "";
      String fileName = "";
      String dateStr = DateFormat('ddMMyy').format(DateTime.now());

      if (exportType == "SALES") {
        csvData = CsvEngine.convertSalesToCsv(filteredData.cast<Sale>());
        fileName = "Sales_Export_$dateStr.csv";
      } else {
        csvData = CsvEngine.convertPurchasesToCsv(filteredData.cast<Purchase>());
        fileName = "Purchase_Export_$dateStr.csv";
      }

      // Temporary file create karein
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csvData);

      // --- FIX: SHARE OPTION WITH MIME TYPE ---
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: fileName,
        text: 'Exported $exportType CSV from Pharoah ERP',
      );
    } catch (e) {
      debugPrint("Export Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Sharing failed: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("DATA HUB / CSV EXCHANGE"),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orange,
          tabs: const [Tab(text: "EXPORT DATA"), Tab(text: "IMPORT CSV")],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildExportInterface(ph),
          _buildImportTab(ph),
        ],
      ),
    );
  }

  // --- 1. EXPORT INTERFACE WITH LISTING & FILTERS ---
  Widget _buildExportInterface(PharoahManager ph) {
    // Current Type ke hisab se data filter karein
    List<dynamic> listToDisplay = [];
    if (exportType == "SALES") {
      listToDisplay = ph.sales.where((s) => 
        s.date.isAfter(fromDate.subtract(const Duration(days: 1))) && 
        s.date.isBefore(toDate.add(const Duration(days: 1)))
      ).toList().reversed.toList();
    } else {
      listToDisplay = ph.purchases.where((p) => 
        p.date.isAfter(fromDate.subtract(const Duration(days: 1))) && 
        p.date.isBefore(toDate.add(const Duration(days: 1)))
      ).toList().reversed.toList();
    }

    return Column(
      children: [
        // FILTER PANEL
        Container(
          padding: const EdgeInsets.all(15),
          color: Colors.white,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _dateBtn("START DATE", fromDate, (d) => setState(() => fromDate = d))),
                  const SizedBox(width: 10),
                  Expanded(child: _dateBtn("END DATE", toDate, (d) => setState(() => toDate = d))),
                ],
              ),
              const SizedBox(height: 15),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: "SALES", label: Text("Sales Register"), icon: Icon(Icons.outbox)),
                  ButtonSegment(value: "PURCHASE", label: Text("Purchase Register"), icon: Icon(Icons.inbox)),
                ],
                selected: {exportType},
                onSelectionChanged: (val) => setState(() {
                  exportType = val.first;
                  selectedIds.clear();
                }),
              ),
            ],
          ),
        ),

        // SELECTION CONTROLS
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${listToDisplay.length} Bills Found", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    if (selectedIds.length == listToDisplay.length) selectedIds.clear();
                    else selectedIds = listToDisplay.map((e) => e.id as String).toList();
                  });
                }, 
                icon: Icon(selectedIds.length == listToDisplay.length ? Icons.deselect : Icons.select_all, size: 18),
                label: Text(selectedIds.length == listToDisplay.length ? "Deselect All" : "Select All")
              ),
            ],
          ),
        ),

        // SCROLLABLE BILL LIST
        Expanded(
          child: listToDisplay.isEmpty 
          ? const Center(child: Text("No records found in this date range."))
          : ListView.builder(
              itemCount: listToDisplay.length,
              padding: const EdgeInsets.only(bottom: 80),
              itemBuilder: (context, index) {
                final item = listToDisplay[index];
                bool isSelected = selectedIds.contains(item.id);

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: CheckboxListTile(
                    activeColor: Colors.indigo,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(item.billNo, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("${DateFormat('dd/MM/yy').format(item.date)} | ${exportType == "SALES" ? item.partyName : item.distributorName}"),
                    secondary: Text("₹${item.totalAmount.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                    value: isSelected,
                    onChanged: (val) {
                      setState(() {
                        if (val!) selectedIds.add(item.id);
                        else selectedIds.remove(item.id);
                      });
                    },
                  ),
                );
              },
            ),
        ),

        // BOTTOM ACTION BUTTON
        if (selectedIds.isNotEmpty)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -2))]),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 55),
                  backgroundColor: Colors.indigo.shade800,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
                onPressed: () {
                  var filtered = listToDisplay.where((e) => selectedIds.contains(e.id)).toList();
                  _generateAndShare(filtered);
                },
                icon: const Icon(Icons.share_outlined),
                label: Text("SHARE ${selectedIds.length} BILLS AS CSV", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          )
      ],
    );
  }

  // --- 2. IMPORT INTERFACE ---
  Widget _buildImportTab(PharoahManager ph) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _importCard("IMPORT SALES CSV", "Consolidate CSV bills into Sales Register.", Icons.cloud_upload, Colors.green, () => _pickAndProcess(ph, "SALE")),
            const SizedBox(height: 20),
            _importCard("IMPORT PURCHASE CSV", "Consolidate CSV items into Purchase/Stock.", Icons.download_for_offline, Colors.orange, () => _pickAndProcess(ph, "PURCHASE")),
            const SizedBox(height: 40),
            const Text("Note: CSV must follow Pharoah Standard Template.", style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }

  void _pickAndProcess(PharoahManager ph, String type) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      String content = await file.readAsString();
      List<List<dynamic>> rows = CsvEngine.parseCsv(content);
      if (mounted) {
        if (rows.length <= 1) { 
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Selected file is empty!"))); 
          return; 
        }
        Navigator.push(context, MaterialPageRoute(builder: (c) => ImportVerificationView(csvData: rows, importType: type)));
      }
    }
  }

  // --- UI HELPERS ---
  Widget _dateBtn(String label, DateTime dt, Function(DateTime) onPick) {
    return InkWell(
      onTap: () async {
        DateTime? p = await showDatePicker(context: context, initialDate: dt, firstDate: DateTime(2020), lastDate: DateTime(2100));
        if (p != null) onPick(p);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(DateFormat('dd/MM/yyyy').format(dt), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const Icon(Icons.calendar_month, size: 14, color: Colors.indigo),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _importCard(String t, String s, IconData i, Color c, VoidCallback onTap) {
    return InkWell(
      onTap: onTap, 
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(20), 
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)), 
        child: Row(
          children: [
            CircleAvatar(backgroundColor: c.withOpacity(0.1), child: Icon(i, color: c)), 
            const SizedBox(width: 20), 
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontWeight: FontWeight.bold)), Text(s, style: const TextStyle(fontSize: 11, color: Colors.grey))])), 
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey)
          ]
        )
      )
    );
  }
}
