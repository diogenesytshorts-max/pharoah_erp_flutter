import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'sale_entry_view.dart';
import 'purchase/purchase_entry_view.dart';

class ItemLedgerSearchView extends StatefulWidget {
  const ItemLedgerSearchView({super.key});
  @override State<ItemLedgerSearchView> createState() => _ItemLedgerSearchViewState();
}

class _ItemLedgerSearchViewState extends State<ItemLedgerSearchView> {
  String search = "";
  String filterType = "ALL"; // ALL, NEAR, EXPIRED

  bool _isNearExpiry(String exp) {
    try {
      DateTime expiryDate = DateFormat('MM/yy').parse(exp);
      DateTime now = DateTime.now();
      int diffMonths = (expiryDate.year - now.year) * 12 + expiryDate.month - now.month;
      return diffMonths >= 0 && diffMonths <= 3; // Agle 3 mahine
    } catch (e) { return false; }
  }

  bool _isExpired(String exp) {
    try {
      DateTime expiryDate = DateFormat('MM/yy').parse(exp);
      return expiryDate.isBefore(DateTime.now());
    } catch (e) { return false; }
  }

  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    
    final filteredMeds = ph.medicines.where((m) {
      bool matchesSearch = m.name.toLowerCase().contains(search.toLowerCase());
      if (!matchesSearch) return false;

      var batches = ph.batchHistory[m.identityKey] ?? [];
      if (filterType == "NEAR") return batches.any((b) => _isNearExpiry(b.exp));
      if (filterType == "EXPIRED") return batches.any((b) => _isExpired(b.exp));
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(title: const Text("Stock Ledger & Tracker"), backgroundColor: Colors.teal.shade800, foregroundColor: Colors.white),
      body: Column(children: [
        // --- TOP FILTERS ---
        Container(
          padding: const EdgeInsets.all(10),
          color: Colors.white,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _filterChip("ALL", Colors.blue),
            _filterChip("NEAR EXPIRY", Colors.orange),
            _filterChip("EXPIRED", Colors.red),
          ]),
        ),
        Container(padding: const EdgeInsets.all(15), child: TextField(decoration: InputDecoration(hintText: "Search Product...", prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), onChanged: (v) => setState(() => search = v))),
        
        Expanded(child: ListView.builder(padding: const EdgeInsets.all(10), itemCount: filteredMeds.length, itemBuilder: (c, i) {
          final med = filteredMeds[i];
          return Card(child: ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.medication, color: Colors.white)),
            title: Text(med.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Total Stock: ${med.stock.toStringAsFixed(1)} ${med.packing}"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => ItemLedgerDetailView(medicine: med))),
          ));
        }))
      ]),
    );
  }

  Widget _filterChip(String label, Color color) {
    bool isSel = filterType == label.split(" ")[0];
    return ActionChip(
      backgroundColor: isSel ? color : Colors.grey.shade200,
      label: Text(label, style: TextStyle(color: isSel ? Colors.white : Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
      onPressed: () => setState(() => filterType = label.split(" ")[0]),
    );
  }
}

// --- DETAILED VIEW WITH BATCH TRACING ---
class ItemLedgerDetailView extends StatefulWidget {
  final Medicine medicine;
  const ItemLedgerDetailView({super.key, required this.medicine});
  @override State<ItemLedgerDetailView> createState() => _ItemLedgerDetailViewState();
}

class _ItemLedgerDetailViewState extends State<ItemLedgerDetailView> {
  String selectedBatch = "ALL";

  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    List<Map<String, dynamic>> history = [];
    Map<String, double> batchStockMap = {};

    // 1. Trace Purchases
    for (var p in ph.purchases) {
      for (var it in p.items) {
        if (it.medicineID == widget.medicine.id) {
          history.add({'date': p.date, 'type': 'IN', 'qty': it.qty + it.freeQty, 'party': p.distributorName, 'bill': p, 'batch': it.batch});
          batchStockMap[it.batch] = (batchStockMap[it.batch] ?? 0) + (it.qty + it.freeQty);
        }
      }
    }

    // 2. Trace Sales
    for (var s in ph.sales.where((s) => s.status == "Active")) {
      for (var it in s.items) {
        if (it.medicineID == widget.medicine.id) {
          history.add({'date': s.date, 'type': 'OUT', 'qty': it.qty + it.freeQty, 'party': s.partyName, 'bill': s, 'batch': it.batch});
          batchStockMap[it.batch] = (batchStockMap[it.batch] ?? 0) - (it.qty + it.freeQty);
        }
      }
    }

    history.sort((a, b) => b['date'].compareTo(a['date']));
    var displayHistory = selectedBatch == "ALL" ? history : history.where((h) => h['batch'] == selectedBatch).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(title: Text(widget.medicine.name), backgroundColor: Colors.teal.shade800, foregroundColor: Colors.white),
      body: Column(children: [
        // Summary Box
        Container(
          padding: const EdgeInsets.all(20), color: Colors.white,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _sum("TOTAL IN", history.where((h)=>h['type']=='IN').fold(0.0, (s, e)=>s+e['qty'])),
            _sum("TOTAL OUT", history.where((h)=>h['type']=='OUT').fold(0.0, (s, e)=>s+e['qty'])),
            _sum("BALANCE", widget.medicine.stock, color: Colors.blue),
          ]),
        ),

        // --- ACTIVE BATCHES SLIDER ---
        const Padding(padding: EdgeInsets.all(10), child: Align(alignment: Alignment.centerLeft, child: Text("ACTIVE BATCHES", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)))),
        SizedBox(
          height: 70,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            children: [
              ChoiceChip(label: const Text("ALL"), selected: selectedBatch == "ALL", onSelected: (v)=>setState(()=>selectedBatch="ALL")),
              ...batchStockMap.entries.map((e) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ChoiceChip(
                  label: Column(children: [Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold)), Text("Qty: ${e.value.toInt()}", style: const TextStyle(fontSize: 9))]), 
                  selected: selectedBatch == e.key,
                  onSelected: (v) => setState(() => selectedBatch = e.key),
                ),
              )).toList(),
            ],
          ),
        ),

        // --- TRACEABILITY LIST ---
        Expanded(
          child: ListView.builder(
            itemCount: displayHistory.length,
            itemBuilder: (c, i) {
              final h = displayHistory[i];
              bool isIn = h['type'] == 'IN';
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                child: ListTile(
                  onTap: () {
                    // CLICK TO OPEN BILL
                    if (isIn) {
                      Navigator.push(context, MaterialPageRoute(builder: (c) => PurchaseEntryView(existingPurchase: h['bill'], isReadOnly: true)));
                    } else {
                      Navigator.push(context, MaterialPageRoute(builder: (c) => SaleEntryView(existingSale: h['bill'], isReadOnly: true)));
                    }
                  },
                  leading: Icon(isIn ? Icons.download_rounded : Icons.upload_rounded, color: isIn ? Colors.green : Colors.red),
                  title: Text(h['party'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text("Date: ${DateFormat('dd/MM/yy').format(h['date'])} | Batch: ${h['batch']}"),
                  trailing: Text("${isIn ? '+' : '-'} ${h['qty'].toInt()}", style: TextStyle(fontWeight: FontWeight.bold, color: isIn ? Colors.green : Colors.red, fontSize: 16)),
                ),
              );
            },
          ),
        )
      ]),
    );
  }

  Widget _sum(String t, double v, {Color? color}) => Column(children: [Text(t, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)), Text(v.toInt().toString(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color ?? Colors.black))]);
}
