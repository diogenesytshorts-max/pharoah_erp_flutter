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
  final bool maskPurchaseRate; // NAYA: C2V mode ke liye true aayega

  const ExportSelectorView({
    super.key, 
    required this.exportType, 
    this.maskPurchaseRate = false
  });

  @override State<ExportSelectorView> createState() => _ExportSelectorViewState();
}

class _ExportSelectorViewState extends State<ExportSelectorView> {
  String partySearch = "";
  List<String> selectedIds = [];
  Party? targetParty;

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    
    // 1. Logic: Filter Source (Sale/Purchase)
    List<dynamic> source = widget.exportType == "SALE" ? ph.sales : ph.purchases;
    if (widget.exportType == "SALE") {
      source = source.where((s) => s.status == "Active").toList();
    }
    source = source.reversed.toList();

    // 2. Logic: Search Filter
    List<dynamic> filtered = source.where((b) {
      String pName = widget.exportType == "SALE" ? (b as Sale).partyName : (b as Purchase).distributorName;
      bool matchesSearch = pName.toLowerCase().contains(partySearch.toLowerCase());
      bool matchesTarget = targetParty == null || pName == targetParty!.name;
      return matchesSearch && matchesTarget;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: Text("${widget.exportType} Export (${widget.maskPurchaseRate ? 'C2V' : 'C2C'})", 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), 
        backgroundColor: Colors.indigo.shade800, 
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(children: [
        // --- SEARCH/PARTY SELECTOR ---
        Container(
          padding: const EdgeInsets.all(15), color: Colors.white,
          child: targetParty == null 
            ? TextField(
                decoration: InputDecoration(
                  hintText: "Search Ledger to export...", 
                  prefixIcon: const Icon(Icons.person_search, color: Colors.indigo), 
                  filled: true, fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
                ), 
                onChanged: (v) => setState(() => partySearch = v)
              )
            : ListTile(
                tileColor: Colors.indigo.shade50, 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), 
                leading: const Icon(Icons.person, color: Colors.indigo), 
                title: Text(targetParty!.name, style: const TextStyle(fontWeight: FontWeight.bold)), 
                trailing: IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => setState(() { targetParty = null; selectedIds.clear(); }))
              ),
        ),

        // --- UTILITY BAR ---
        if (filtered.isNotEmpty) 
          Padding(
            padding: const EdgeInsets.all(15), 
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text("${filtered.length} Bills", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    if (selectedIds.length == filtered.length) selectedIds.clear();
                    else selectedIds = filtered.map((e) => (widget.exportType == "SALE" ? (e as Sale).id : (e as Purchase).id)).toList();
                  });
                }, 
                icon: const Icon(Icons.select_all, size: 18),
                label: Text(selectedIds.length == filtered.length ? "UNSELECT ALL" : "SELECT ALL")
              ),
            ])
          ),

        // --- BILLS CHECKLIST ---
        Expanded(
          child: ListView.builder(
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
                    elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: CheckboxListTile(
                      activeColor: Colors.indigo, 
                      value: isSel, 
                      title: Text(pName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), 
                      subtitle: Text("Invoice: $bNo | ${DateFormat('dd/MM/yy').format(dt)}"), 
                      secondary: Text("₹${amt.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.indigo)), 
                      onChanged: (v) {
                        setState(() { if (v!) selectedIds.add(bId); else selectedIds.remove(bId); });
                      },
                    )
                  );
                }
              )
        ),
      ]),
      
      // --- FINAL ACTIONS ---
      bottomNavigationBar: selectedIds.isEmpty ? null : Container(
        padding: const EdgeInsets.all(20), 
        decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, -5))]),
        child: Row(children: [
          Expanded(child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), 
            onPressed: () => _startExport(filtered, "SHARE"), 
            icon: const Icon(Icons.share), label: const Text("SHARE CSV", style: TextStyle(fontWeight: FontWeight.bold)))),
          const SizedBox(width: 15),
          Expanded(child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), 
            onPressed: () => _startExport(filtered, "SAVE"), 
            icon: const Icon(Icons.download), label: const Text("SAVE FILE", style: TextStyle(fontWeight: FontWeight.bold)))),
        ]),
      ),
    );
  }

  // ===========================================================================
  // 🔥 FINAL EXPORT LOGIC: CALLING 36-COLUMN ENGINE
  // ===========================================================================
  void _startExport(List<dynamic> all, String mode) async {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    
    // Filter selected items
    List<dynamic> selected = all.where((b) {
      String id = widget.exportType == "SALE" ? (b as Sale).id : (b as Purchase).id;
      return selectedIds.contains(id);
    }).toList();
    
    String csv = "";

    if (widget.exportType == "SALE") {
      csv = CsvEngine.convertSalesToCsv(
        sales: selected.cast<Sale>(), 
        shop: ph.activeCompany!,
        allMeds: ph.medicines,
        allComps: ph.companies,
        allSalts: ph.salts,
        allParties: ph.parties,
        maskPurchaseRate: widget.maskPurchaseRate, // PRIVACY COMMAND
      );
    } else {
      csv = CsvEngine.convertPurchasesToCsv(
        purchases: selected.cast<Purchase>(), 
        shop: ph.activeCompany!,
        allMeds: ph.medicines,
        allComps: ph.companies,
        allSalts: ph.salts,
        allParties: ph.parties,
      );
    }

    String fn = "${widget.exportType}_${DateFormat('ddMMM_HHmm').format(DateTime.now())}";

    if (mode == "SHARE") {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fn.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles([XFile(file.path)], subject: "Pharoah Data Export");
    } else {
      Uint8List bytes = Uint8List.fromList(utf8.encode(csv));
      await FileSaver.instance.saveAs(name: fn, bytes: bytes, ext: "csv", mimeType: MimeType.csv);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ CSV Exported successfully!"), backgroundColor: Colors.green));
    }
  }
}
