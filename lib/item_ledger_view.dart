import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pharoah_erp/pharoah_manager.dart';
import 'package:pharoah_erp/models.dart';
import 'package:pharoah_erp/bill_view_only.dart'; 
import 'package:pharoah_erp/purchase/purchase_view_only.dart';

class ItemLedgerSearchView extends StatefulWidget {
  const ItemLedgerSearchView({super.key});
  @override State<ItemLedgerSearchView> createState() => _ItemLedgerSearchViewState();
}

class _ItemLedgerSearchViewState extends State<ItemLedgerSearchView> {
  String search = "";
  String filterType = "ALL"; 

  bool _isNearExpiry(String exp) {
    try {
      if (exp.isEmpty || !exp.contains('/')) return false;
      DateTime expiryDate = DateFormat('MM/yy').parse(exp);
      DateTime now = DateTime.now();
      int diffMonths = (expiryDate.year - now.year) * 12 + expiryDate.month - now.month;
      return diffMonths >= 0 && diffMonths <= 3;
    } catch (e) { return false; }
  }

  bool _isExpired(String exp) {
    try {
      if (exp.isEmpty || !exp.contains('/')) return false;
      DateTime expiryDate = DateFormat('MM/yy').parse(exp);
      DateTime lastDayOfMonth = DateTime(expiryDate.year, expiryDate.month + 1, 0);
      return lastDayOfMonth.isBefore(DateTime.now());
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
      appBar: AppBar(title: const Text("Stock Ledger & Batch Tracker"), backgroundColor: Colors.teal.shade800, foregroundColor: Colors.white),
      body: Column(children: [
        Container(padding: const EdgeInsets.symmetric(vertical: 10), color: Colors.white, child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_filterChip("ALL", Colors.blue), _filterChip("NEAR EXPIRY", Colors.orange), _filterChip("EXPIRED", Colors.red)])),
        Padding(padding: const EdgeInsets.all(15), child: TextField(decoration: InputDecoration(hintText: "Search Product Name...", prefixIcon: const Icon(Icons.search, color: Colors.teal), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none), contentPadding: EdgeInsets.zero), onChanged: (v) => setState(() => search = v))),
        Expanded(child: filteredMeds.isEmpty ? const Center(child: Text("No items found")) : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 10), itemCount: filteredMeds.length, itemBuilder: (c, i) {
              final med = filteredMeds[i];
              return Card(child: ListTile(leading: CircleAvatar(backgroundColor: Colors.teal.shade50, child: Icon(Icons.medication, color: Colors.teal.shade800)), title: Text(med.name, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text("Current Stock: ${med.stock.toStringAsFixed(1)} ${med.packing}"), trailing: const Icon(Icons.arrow_forward_ios, size: 14), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => ItemLedgerDetailView(medicine: med)))));
            }))
      ]),
    );
  }

  Widget _filterChip(String label, Color color) {
    bool isSel = filterType == label.split(" ")[0];
    return ActionChip(backgroundColor: isSel ? color : Colors.grey.shade100, label: Text(label, style: TextStyle(color: isSel ? Colors.white : Colors.black87, fontSize: 10, fontWeight: FontWeight.bold)), onPressed: () => setState(() => filterType = label.split(" ")[0]));
  }
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
    List<Map<String, dynamic>> history = [];
    Map<String, double> batchStockMap = {};

    for (var p in ph.purchases) {
      for (var it in p.items) {
        if (it.medicineID == widget.medicine.id) {
          history.add({'date': p.date, 'type': 'IN', 'qty': it.qty + it.freeQty, 'party': p.distributorName, 'bill': p, 'batch': it.batch});
          batchStockMap[it.batch] = (batchStockMap[it.batch] ?? 0) + (it.qty + it.freeQty);
        }
      }
    }
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
        Container(padding: const EdgeInsets.all(20), decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_sumCol("TOTAL IN", history.where((h)=>h['type']=='IN').fold(0.0, (s, e)=>s+e['qty']), Colors.green), _sumCol("TOTAL OUT", history.where((h)=>h['type']=='OUT').fold(0.0, (s, e)=>s+e['qty']), Colors.red), _sumCol("ON HAND", widget.medicine.stock, Colors.blue.shade900)])),
        SizedBox(height: 65, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), children: [ChoiceChip(label: const Text("ALL BATCHES"), selected: selectedBatch == "ALL", onSelected: (v)=>setState(()=>selectedBatch="ALL")), ...batchStockMap.entries.map((e) => Padding(padding: const EdgeInsets.only(left: 8), child: ChoiceChip(label: Text("${e.key} (${e.value.toInt()})"), selected: selectedBatch == e.key, onSelected: (v) => setState(() => selectedBatch = e.key)))).toList()])),
        Expanded(child: displayHistory.isEmpty ? const Center(child: Text("No transactions found")) : ListView.builder(padding: const EdgeInsets.all(10), itemCount: displayHistory.length, itemBuilder: (c, i) {
              final h = displayHistory[i];
              bool isIn = h['type'] == 'IN';
              return Card(child: ListTile(onTap: () {
                    if (isIn) { Navigator.push(context, MaterialPageRoute(builder: (c) => PurchaseViewOnly(purchase: h['bill'] as Purchase))); } 
                    else {
                      final partyObj = ph.parties.firstWhere((p) => p.name == h['party'], orElse: () => Party(id: "", name: h['party']));
                      Navigator.push(context, MaterialPageRoute(builder: (c) => BillViewOnly(sale: h['bill'] as Sale, party: partyObj)));
                    }
                  }, leading: Icon(isIn ? Icons.south_west : Icons.north_east, color: isIn ? Colors.green : Colors.red), title: Text(h['party']), subtitle: Text("${DateFormat('dd/MM/yy').format(h['date'])} | Batch: ${h['batch']}"), trailing: Text("${isIn ? '+' : '-'} ${h['qty'].toInt()}", style: TextStyle(fontWeight: FontWeight.bold, color: isIn ? Colors.green : Colors.red))));
            }))
      ]),
    );
  }
  Widget _sumCol(String t, double v, Color c) => Column(children: [Text(t, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)), Text(v.toInt().toString(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c))]);
}
