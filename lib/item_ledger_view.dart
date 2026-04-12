import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'pharoah_manager.dart';
import 'models.dart';

// --- SCREEN 1: PRODUCT SEARCH ---
class ItemLedgerSearchView extends StatefulWidget {
  const ItemLedgerSearchView({super.key});
  @override State<ItemLedgerSearchView> createState() => _ItemLedgerSearchViewState();
}

class _ItemLedgerSearchViewState extends State<ItemLedgerSearchView> {
  String search = "";

  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    final filteredMeds = ph.medicines.where((m) => m.name.toLowerCase().contains(search.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("Stock Ledger & Tracker"), 
        backgroundColor: Colors.teal.shade800, foregroundColor: Colors.white, elevation: 0
      ),
      body: Column(children: [
        Container(
          padding: const EdgeInsets.all(15), color: Colors.teal.shade50,
          child: TextField(
            decoration: InputDecoration(hintText: "Search Product (e.g. DOLO)...", prefixIcon: const Icon(Icons.search, color: Colors.teal), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
            onChanged: (v) => setState(() => search = v),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(10), itemCount: filteredMeds.length,
            itemBuilder: (c, i) {
              final med = filteredMeds[i];
              return Card(
                elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.medication, color: Colors.white)),
                  title: Text(med.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Text("Pack: ${med.packing} | Current Stock: ${med.stock}"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => ItemLedgerDetailView(medicine: med))),
                ),
              );
            }
          ),
        )
      ]),
    );
  }
}

// --- CLASS FOR COMBINED TIMELINE ENTRY ---
class LedgerEntry {
  final DateTime date; final String type; final String refNo; final String party; final String batch; final double qty; final double rate;
  LedgerEntry({required this.date, required this.type, required this.refNo, required this.party, required this.batch, required this.qty, required this.rate});
}

// --- SCREEN 2: THE MASTER LEDGER (TIMELINE) ---
class ItemLedgerDetailView extends StatefulWidget {
  final Medicine medicine;
  const ItemLedgerDetailView({super.key, required this.medicine});
  @override State<ItemLedgerDetailView> createState() => _ItemLedgerDetailViewState();
}

class _ItemLedgerDetailViewState extends State<ItemLedgerDetailView> {
  String selectedBatch = "ALL";

  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    
    // 1. Extract Data from Purchases (IN)
    List<LedgerEntry> entries = [];
    double totalIn = 0; double totalOut = 0;
    Set<String> uniqueBatches = {"ALL"};

    for (var p in ph.purchases) {
      for (var it in p.items) {
        if (it.medicineID == widget.medicine.id) {
          entries.add(LedgerEntry(date: p.date, type: "IN", refNo: p.billNo, party: p.distributorName, batch: it.batch, qty: it.qty + it.freeQty, rate: it.purchaseRate));
          totalIn += (it.qty + it.freeQty);
          uniqueBatches.add(it.batch);
        }
      }
    }

    // 2. Extract Data from Sales (OUT)
    for (var s in ph.sales.where((s) => s.status == "Active")) {
      for (var it in s.items) {
        if (it.medicineID == widget.medicine.id) {
          entries.add(LedgerEntry(date: s.date, type: "OUT", refNo: s.billNo, party: s.partyName, batch: it.batch, qty: it.qty, rate: it.rate));
          totalOut += it.qty;
          uniqueBatches.add(it.batch);
        }
      }
    }

    // 3. Sort Chronologically (Newest First)
    entries.sort((a, b) => b.date.compareTo(a.date));

    // 4. Apply Batch Filter
    List<LedgerEntry> displayEntries = selectedBatch == "ALL" ? entries : entries.where((e) => e.batch == selectedBatch).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(title: Text(widget.medicine.name), backgroundColor: Colors.teal.shade800, foregroundColor: Colors.white, elevation: 0),
      body: Column(children: [
        
        // --- SECTION A: SUMMARY BOX ---
        Container(
          padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _sumBox("TOTAL IN", totalIn.toInt().toString(), Colors.green),
            _sumBox("TOTAL OUT", totalOut.toInt().toString(), Colors.red),
            _sumBox("BALANCE", widget.medicine.stock.toString(), Colors.blue.shade800),
          ]),
        ),

        // --- SECTION B: BATCH FILTER CHIPS ---
        if (uniqueBatches.length > 1)
          Container(
            height: 50, width: double.infinity, color: Colors.teal.shade50,
            child: ListView(
              scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              children: uniqueBatches.map((b) {
                bool isSel = selectedBatch == b;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(b, style: TextStyle(color: isSel ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 12)),
                    selected: isSel, selectedColor: Colors.teal, backgroundColor: Colors.white,
                    onSelected: (val) => setState(() => selectedBatch = b),
                  ),
                );
              }).toList(),
            ),
          ),

        // --- SECTION C: TIMELINE (PASSBOOK) ---
        Expanded(
          child: displayEntries.isEmpty 
          ? const Center(child: Text("No transaction history found.", style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(10), itemCount: displayEntries.length,
              itemBuilder: (c, i) {
                final e = displayEntries[i];
                bool isIn = e.type == "IN";
                return Card(
                  margin: const EdgeInsets.only(bottom: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: isIn ? Colors.green.shade200 : Colors.red.shade200, width: 1)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                    leading: CircleAvatar(backgroundColor: isIn ? Colors.green.shade100 : Colors.red.shade100, child: Icon(isIn ? Icons.arrow_downward : Icons.arrow_upward, color: isIn ? Colors.green : Colors.red)),
                    title: Text(e.party, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text("Date: ${DateFormat('dd/MM/yyyy').format(e.date)} | Ref: ${e.refNo}\nBatch: ${e.batch} | Rate: ₹${e.rate}", style: const TextStyle(fontSize: 12)),
                    trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(isIn ? "+ ${e.qty.toInt()}" : "- ${e.qty.toInt()}", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: isIn ? Colors.green : Colors.red)),
                      Text("Qty", style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                    ]),
                  ),
                );
              }
            )
        )
      ]),
    );
  }

  Widget _sumBox(String title, String val, Color c) {
    return Column(children: [
      Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
      const SizedBox(height: 5),
      Text(val, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: c)),
    ]);
  }
}
