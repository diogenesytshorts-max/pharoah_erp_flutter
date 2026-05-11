// FILE: lib/export_selector_view.dart

import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_saver/file_saver.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'csv_engine.dart';

class ExportSelectorView extends StatefulWidget {
  final String exportType; // "SALE" or "PURCHASE"
  const ExportSelectorView({super.key, required this.exportType});

  @override State<ExportSelectorView> createState() => _ExportSelectorViewState();
}

class _ExportSelectorViewState extends State<ExportSelectorView> {
  String partySearch = "";
  List<String> selectedIds = [];
  Party? targetParty;

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    
    // 1. Data Source Selection (Sales or Purchases)
    List<dynamic> source = widget.exportType == "SALE" ? ph.sales : ph.purchases;
    
    // Active bills only if Sale
    if (widget.exportType == "SALE") {
      source = source.where((s) => s.status == "Active").toList();
    }
    
    // Latest bills at top
    source = source.reversed.toList();

    // 2. Filter Logic (Search by Name or Specific Party select)
    List<dynamic> filtered = source.where((b) {
      String pName = widget.exportType == "SALE" ? (b as Sale).partyName : (b as Purchase).distributorName;
      bool matchesSearch = pName.toLowerCase().contains(partySearch.toLowerCase());
      bool matchesTarget = targetParty == null || pName == targetParty!.name;
      return matchesSearch && matchesTarget;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: Text("Export ${widget.exportType} to CSV"), 
        backgroundColor: Colors.indigo.shade800, 
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(children: [
        // --- FILTER BAR ---
        Container(
          padding: const EdgeInsets.all(15), color: Colors.white,
          child: targetParty == null 
            ? TextField(
                decoration: InputDecoration(
                  hintText: "Search Party/Supplier to Export...", 
                  prefixIcon: const Icon(Icons.person_search, color: Colors.indigo), 
                  filled: true, fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
                ), 
                onChanged: (v) => setState(() => partySearch = v)
              )
            : ListTile(
                tileColor: Colors.indigo.shade50, 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), 
                leading: const Icon(Icons.person, color: Colors.indigo), 
                title: Text(targetParty!.name, style: const TextStyle(fontWeight: FontWeight.bold)), 
                trailing: IconButton(
                  icon: const Icon(Icons.close, color: Colors.red), 
                  onPressed: () => setState(() { targetParty = null; selectedIds.clear(); })
                )
              ),
        ),

        // --- SELECTION UTILITY ---
        if (filtered.isNotEmpty) 
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10), 
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text("${filtered.length} Bills Available", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    if (selectedIds.length == filtered.length) {
                      selectedIds.clear();
                    } else {
                      selectedIds = filtered.map((e) => (widget.exportType == "SALE" ? (e as Sale).id : (e as Purchase).id)).toList();
                    }
                  });
                }, 
                icon: Icon(selectedIds.length == filtered.length ? Icons.deselect : Icons.select_all),
                label: Text(selectedIds.length == filtered.length ? "UNSELECT ALL" : "SELECT ALL")
              ),
            ])
          ),

        // --- BILLS LIST ---
        Expanded(
          child: filtered.isEmpty 
            ? Center(child: Text("No ${widget.exportType} bills found.", style: const TextStyle(color: Colors.grey)))
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 100),
                itemCount: filtered.length, 
                itemBuilder: (c, i) {
                  final b = filtered[i];
                  String bId = widget.exportType == "SALE" ? (b as Sale).id : (b as Purchase).id;
                  String bNo = widget.exportType == "SALE" ? (b as Sale).billNo : (b as Purchase).billNo;
                  String pName = widget.exportType == "SALE" ? (b as Sale).partyName : (b as Purchase).distributorName;
                  DateTime dt = widget.exportType == "SALE" ? (b as Sale).date : (b as Purchase).date;
                  double amt = widget.exportType == "SALE" ? (b as Sale).totalAmount : (b as Purchase).totalAmount;

                  final isSel = selectedIds.contains(bId);
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), 
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: CheckboxListTile(
                      activeColor: Colors.indigo, 
                      value: isSel, 
                      title: Text(pName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), 
                      subtitle: Text("Inv: $bNo | Date: ${DateFormat('dd/MM/yy').format(dt)}"), 
                      secondary: Text("₹${amt.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.indigo)), 
                      onChanged: (v) {
                        setState(() {
                          if (v!) { selectedIds.add(bId); } 
                          else { selectedIds.remove(bId); }
                        });
                      },
                    )
                  );
                }
              )
        ),
      ]),
      
      // --- ACTION BUTTONS ---
      bottomNavigationBar: selectedIds.isEmpty ? null : Container(
        padding: const EdgeInsets.all(20), 
        decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, -5))]),
        child: Row(children: [
          Expanded(child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), 
            onPressed: () => _handleExportProcess(filtered, "SHARE"), 
            icon: const Icon(Icons.share), 
            label: const Text("SHARE CSV", style: TextStyle(fontWeight: FontWeight.bold)))),
          const SizedBox(width: 15),
          Expanded(child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), 
            onPressed: () => _handleExportProcess(filtered, "SAVE"), 
            icon: const Icon(Icons.download_for_offline), 
            label: const Text("SAVE FILE", style: TextStyle(fontWeight: FontWeight.bold)))),
        ]),
      ),
    );
  }

  // ===========================================================================
  // 🔥 FINAL SURGICAL FIX: Passing ALL Master Data to 36-Column Engine
  // ===========================================================================
  void _handleExportProcess(List<dynamic> allBills, String mode) async {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    
    // Filter out only selected bills
    List<dynamic> selectedData = allBills.where((b) {
      String id = widget.exportType == "SALE" ? (b as Sale).id : (b as Purchase).id;
      return selectedIds.contains(id);
    }).toList();
    
    String csvContent = "";

    // Hum ab Universal 36-column engine ko call kar rahe hain
    if (widget.exportType == "SALE") {
      csvContent = CsvEngine.convertSalesToCsv(
        sales: selectedData.cast<Sale>(), 
        shop: ph.activeCompany!,
        allMeds: ph.medicines,
        allComps: ph.companies,
        allSalts: ph.salts,
      );
    } else {
      csvContent = CsvEngine.convertPurchasesToCsv(
        purchases: selectedData.cast<Purchase>(), 
        shop: ph.activeCompany!,
        allMeds: ph.medicines,
        allComps: ph.companies,
        allSalts: ph.salts,
        allParties: ph.parties, // Yahan se N/A khatam hoga
      );
    }

    String timestamp = DateFormat('ddMMM_HHmm').format(DateTime.now());
    String fileName = "${widget.exportType}_EXPORT_$timestamp";

    if (mode == "SHARE") {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName.csv');
      await file.writeAsString(csvContent);
      await Share.shareXFiles([XFile(file.path)], subject: "Pharoah Data Export");
    } else {
      Uint8List bytes = Uint8List.fromList(utf8.encode(csvContent));
      await FileSaver.instance.saveAs(name: fileName, bytes: bytes, ext: "csv", mimeType: MimeType.csv);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ CSV File Ready with 36-column Data Sync!"), backgroundColor: Colors.green));
      }
    }
  }
}
