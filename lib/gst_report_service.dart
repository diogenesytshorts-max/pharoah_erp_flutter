import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'pharoah_manager.dart';
import 'models.dart';

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
      appBar: AppBar(title: const Text("Stock Ledger & Tracker"), backgroundColor: Colors.teal.shade800, foregroundColor: Colors.white, elevation: 0),
      body: Column(children: [
        Container(padding: const EdgeInsets.all(15), color: Colors.teal.shade50, child: TextField(decoration: InputDecoration(hintText: "Search Product...", prefixIcon: const Icon(Icons.search, color: Colors.teal), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)), onChanged: (v) => setState(() => search = v))),
        Expanded(child: ListView.builder(padding: const EdgeInsets.all(10), itemCount: filteredMeds.length, itemBuilder: (c, i) {
          final med = filteredMeds[i];
          return Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), child: ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.medication, color: Colors.white)),
            title: Text(med.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Text("Pack: ${med.packing} | Current Stock: ${med.stock.toStringAsFixed(1)}"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => ItemLedgerDetailView(medicine: med))),
          ));
        }))
      ]),
    );
  }
}

class LedgerEntry {
  final DateTime date; final String type, refNo, party, batch; final double qty, free, rate;
  LedgerEntry({required this.date, required this.type, required this.refNo, required this.party, required this.batch, required this.qty, required this.free, required this.rate});
}

class ItemLedgerDetailView extends StatefulWidget {
  final Medicine medicine;
  const ItemLedgerDetailView({super.key, required this.medicine});
  @override State<ItemLedgerDetailView> createState() => _ItemLedgerDetailViewState();
}

class _ItemLedgerDetailViewState extends State<ItemLedgerDetailView> {
  String selectedBatch = "ALL";

  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    List<LedgerEntry> entries = [];
    double totalIn = 0, totalOut = 0;
    Set<String> uniqueBatches = {"ALL"};

    for (var p in ph.purchases) { 
      for (var it in p.items) { 
        if (it.medicineID == widget.medicine.id) { 
          entries.add(LedgerEntry(date: p.date, type: "IN", refNo: p.billNo, party: p.distributorName, batch: it.batch, qty: it.qty, free: it.freeQty, rate: it.purchaseRate)); 
          totalIn += (it.qty + it.freeQty); uniqueBatches.add(it.batch); 
        } 
      } 
    }
    for (var s in ph.sales.where((s) => s.status == "Active")) { 
      for (var it in s.items) { 
        if (it.medicineID == widget.medicine.id) { 
          entries.add(LedgerEntry(date: s.date, type: "OUT", refNo: s.billNo, party: s.partyName, batch: it.batch, qty: it.qty, free: it.freeQty, rate: it.rate)); 
          totalOut += (it.qty + it.freeQty); uniqueBatches.add(it.batch); 
        } 
      } 
    }

    entries.sort((a, b) => b.date.compareTo(a.date));
    List<LedgerEntry> displayEntries = selectedBatch == "ALL" ? entries : entries.where((e) => e.batch == selectedBatch).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(title: Text(widget.medicine.name), backgroundColor: Colors.teal.shade800, foregroundColor: Colors.white),
      body: Column(children: [
        Container(padding: const EdgeInsets.all(20), decoration: const BoxDecoration(color: Colors.white), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_sumBox("TOTAL IN", totalIn.toStringAsFixed(1), Colors.green), _sumBox("TOTAL OUT", totalOut.toStringAsFixed(1), Colors.red), _sumBox("BALANCE", widget.medicine.stock.toStringAsFixed(1), Colors.blue.shade800)])),
        if (uniqueBatches.length > 1) Container(height: 50, color: Colors.teal.shade50, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), children: uniqueBatches.map((b) => Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(b), selected: selectedBatch == b, onSelected: (v) => setState(() => selectedBatch = b)))).toList())),
        Expanded(child: ListView.builder(padding: const EdgeInsets.all(10), itemCount: displayEntries.length, itemBuilder: (c, i) {
          final e = displayEntries[i]; bool isIn = e.type == "IN";
          return Card(child: ListTile(
            leading: Icon(isIn ? Icons.arrow_downward : Icons.arrow_upward, color: isIn ? Colors.green : Colors.red),
            title: Text(e.party, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Date: ${DateFormat('dd/MM/yy').format(e.date)} | Batch: ${e.batch}"),
            trailing: Text("${isIn ? '+' : '-'} ${e.qty}${e.free > 0 ? ' + ${e.free}' : ''}", style: TextStyle(fontWeight: FontWeight.bold, color: isIn ? Colors.green : Colors.red)),
          ));
        }))
      ]),
    );
  }
  Widget _sumBox(String t, String v, Color c) => Column(children: [Text(t, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), Text(v, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: c))]);
}
