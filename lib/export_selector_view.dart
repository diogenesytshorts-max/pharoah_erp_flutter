import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'csv_engine.dart';

class ExportSelectorView extends StatefulWidget {
  final String exportType; // "SALE" or "PURCHASE"
  const ExportSelectorView({super.key, required this.exportType});

  @override
  State<ExportSelectorView> createState() => _ExportSelectorViewState();
}

class _ExportSelectorViewState extends State<ExportSelectorView> {
  String partySearchQuery = "";
  List<String> selectedBillIds = [];
  Party? targetParty;

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    // 1. Filter Bills based on Type (Sale/Purchase) and Selected Party
    List<dynamic> allBills = widget.exportType == "SALE" ? ph.sales : ph.purchases;
    
    // Sort: Newest first
    allBills = allBills.reversed.toList();

    // Filter by Party if selected
    List<dynamic> filteredBills = allBills.where((bill) {
      String bParty = widget.exportType == "SALE" ? (bill as Sale).partyName : (bill as Purchase).distributorName;
      if (targetParty == null) return true;
      return bParty == targetParty!.name;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: Text("Select ${widget.exportType} Bills"),
        backgroundColor: Colors.indigo.shade800,
        foregroundColor: Colors.white,
        actions: [
          if (selectedBillIds.isNotEmpty)
            TextButton.icon(
              onPressed: () => _processExport(allBills),
              icon: const Icon(Icons.share, color: Colors.white),
              label: Text("EXPORT (${selectedBillIds.length})", 
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
        ],
      ),
      body: Column(
        children: [
          // --- SECTION: PARTY SELECTION ---
          Container(
            padding: const EdgeInsets.all(15),
            color: Colors.white,
            child: Column(
              children: [
                if (targetParty == null)
                  TextField(
                    decoration: InputDecoration(
                      hintText: "Search Party to filter bills...",
                      prefixIcon: const Icon(Icons.person_search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (v) => setState(() => partySearchQuery = v),
                  )
                else
                  ListTile(
                    tileColor: Colors.indigo.shade50,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    leading: const Icon(Icons.person, color: Colors.indigo),
                    title: Text(targetParty!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => setState(() { targetParty = null; selectedBillIds.clear(); }),
                    ),
                  ),
                
                if (targetParty == null && partySearchQuery.isNotEmpty)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView(
                      shrinkWrap: true,
                      children: ph.parties
                          .where((p) => p.name.toLowerCase().contains(partySearchQuery.toLowerCase()))
                          .map((p) => ListTile(
                                title: Text(p.name),
                                onTap: () => setState(() { targetParty = p; partySearchQuery = ""; }),
                              ))
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),

          // --- SECTION: SELECT ALL TOGGLE ---
          if (filteredBills.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("  Found ${filteredBills.length} Bills", style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (selectedBillIds.length == filteredBills.length) {
                          selectedBillIds.clear();
                        } else {
                          selectedBillIds = filteredBills.map((b) => b.id as String).toList();
                        }
                      });
                    },
                    child: Text(selectedBillIds.length == filteredBills.length ? "UNSELECT ALL" : "SELECT ALL"),
                  )
                ],
              ),
            ),

          // --- SECTION: BILLS LIST WITH CHECKBOX ---
          Expanded(
            child: filteredBills.isEmpty
                ? const Center(child: Text("No bills found for this selection."))
                : ListView.builder(
                    itemCount: filteredBills.length,
                    itemBuilder: (context, index) {
                      final bill = filteredBills[index];
                      final bool isSelected = selectedBillIds.contains(bill.id);
                      
                      String title = widget.exportType == "SALE" ? (bill as Sale).partyName : (bill as Purchase).distributorName;
                      String subtitle = "Bill No: ${bill.billNo} | Date: ${DateFormat('dd/MM/yy').format(bill.date)}";
                      String amt = "₹${bill.totalAmount.toStringAsFixed(2)}";

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        child: CheckboxListTile(
                          activeColor: Colors.indigo,
                          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(subtitle),
                          secondary: Text(amt, style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                selectedBillIds.add(bill.id);
                              } else {
                                selectedBillIds.remove(bill.id);
                              }
                            });
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // --- EXPORT LOGIC ---
  void _processExport(List<dynamic> allSourceBills) async {
    // 1. Filter only selected items
    List<dynamic> selectedData = allSourceBills.where((b) => selectedBillIds.contains(b.id)).toList();

    String csvData = "";
    if (widget.exportType == "SALE") {
      csvData = CsvEngine.convertSalesToCsv(selectedData.cast<Sale>());
    } else {
      csvData = CsvEngine.convertPurchasesToCsv(selectedData.cast<Purchase>());
    }

    // 2. Save and Share
    final directory = await getTemporaryDirectory();
    String dateStr = DateFormat('dd-MMM-yyyy').format(DateTime.now());
String fileName = "${widget.exportType}_REPORTS_$dateStr.csv"; 
final file = File('${directory.path}/$fileName');
    await file.writeAsString(csvData);
    
    await Share.shareXFiles([XFile(file.path, mimeType: 'text/csv')], 
      subject: '${widget.exportType} Selected Export');
  }
}
