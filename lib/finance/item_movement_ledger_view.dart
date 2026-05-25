import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import '../../pdf/statements/item_ledger_pdf.dart';

class ItemMovementLedgerView extends StatefulWidget {
  const ItemMovementLedgerView({super.key});
  @override State<ItemMovementLedgerView> createState() => _ItemMovementLedgerViewState();
}

class _ItemMovementLedgerViewState extends State<ItemMovementLedgerView> {
  Medicine? selectedMed;
  String medSearch = "";

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    List<Map<String, dynamic>> movement = [];

    if (selectedMed != null) {
      movement = _calculateMovement(ph);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(selectedMed == null ? "Item Ledger Audit" : selectedMed!.name),
        backgroundColor: Colors.blue.shade900,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf), 
            onPressed: () async {
              if (selectedMed == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select an item first!")));
                return;
              }
              
              // 1. Get same data shown on screen (Reverse for chronological order in PDF)
              final rawData = _calculateMovement(ph).reversed.toList();

              // 2. Trigger PDF
              await ItemLedgerPdf.generate(
                shop: ph.activeCompany!,
                med: selectedMed!,
                movementData: rawData,
              );
            }
          )
        ],
      ),
  // ===========================================================================
  // 🧠 CORE LOGIC: ITEM TIMELINE ENGINE
  // ===========================================================================
  List<Map<String, dynamic>> _calculateMovement(PharoahManager ph) {
    List<Map<String, dynamic>> history = [];

    // 1. Trace Purchases (Stock IN)
    for (var p in ph.purchases) {
      for (var it in p.items.where((it) => it.medicineID == selectedMed!.id)) {
        history.add({'date': p.date, 'type': 'PURCHASE', 'party': p.distributorName, 'in': it.qty + it.freeQty, 'out': 0.0, 'batch': it.batch, 'ref': p.billNo});
      }
    }

    // 2. Trace Sales (Stock OUT)
    for (var s in ph.sales.where((s) => s.status == "Active")) {
      for (var it in s.items.where((it) => it.medicineID == selectedMed!.id)) {
        history.add({'date': s.date, 'type': 'SALE', 'party': s.partyName, 'in': 0.0, 'out': it.qty + it.freeQty, 'batch': it.batch, 'ref': s.billNo});
      }
    }

    // 3. Trace Sale Returns (Stock IN - Only Sellable)
    for (var r in ph.saleReturns.where((r) => r.status == "Active")) {
      for (var it in r.items.where((it) => it.medicineID == selectedMed!.id && it.isBreakage == false)) {
        history.add({'date': r.date, 'type': 'SALE-RET', 'party': r.partyName, 'in': it.qty + it.freeQty, 'out': 0.0, 'batch': it.batch, 'ref': r.billNo});
      }
    }

    // 4. Trace Purchase Returns (Stock OUT)
    for (var r in ph.purchaseReturns.where((r) => r.status == "Active")) {
      for (var it in r.items.where((it) => it.medicineID == selectedMed!.id)) {
        history.add({'date': r.date, 'type': 'PUR-RET', 'party': r.distributorName, 'in': 0.0, 'out': it.qty + it.freeQty, 'batch': it.batch, 'ref': r.billNo});
      }
    }

    // Date Sorting
    history.sort((a, b) => a['date'].compareTo(b['date']));

    // Calculate Running Balance
    double runningStock = 0;
    for (var entry in history) {
      runningStock += (entry['in'] - entry['out']);
      entry['bal'] = runningStock;
    }

    return history.reversed.toList(); // Latest on top
  }

  // ===========================================================================
  // 🛠️ UI COMPONENTS
  // ===========================================================================

  Widget _buildMedicineSelector(PharoahManager ph) {
    return Container(
      padding: const EdgeInsets.all(15), color: Colors.white,
      child: selectedMed == null 
        ? TextField(
            decoration: const InputDecoration(hintText: "Search Product for history...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
            onChanged: (v) => setState(() => medSearch = v),
          )
        : ListTile(
            tileColor: Colors.blue.shade50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            leading: const Icon(Icons.medication, color: Colors.blue),
            title: Text(selectedMed!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Pack: ${selectedMed!.packing} | HSN: ${selectedMed!.hsnCode}"),
            trailing: IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: () => setState(() => selectedMed = null)),
          ),
    );
  }

  Widget _buildProductQuickStats() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
    color: Colors.blue.shade900,
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
      _quickStat("MRP", "₹${selectedMed!.mrp}"),
      _quickStat("PUR RATE", "₹${selectedMed!.purRate}"),
      _quickStat("CURRENT STOCK", "${selectedMed!.stock.toInt()}", isBold: true),
    ]),
  );

  Widget _buildMovementTimeline(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return const Center(child: Text("No movement recorded for this item."));

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: data.length,
      itemBuilder: (c, i) {
        final row = data[i];
        bool isIn = row['in'] > 0;
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: isIn ? Colors.green.shade50 : Colors.red.shade50, child: Icon(isIn ? Icons.add : Icons.remove, color: isIn ? Colors.green : Colors.red, size: 16)),
            title: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(row['party'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text("Bal: ${row['bal'].toInt()}", style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.blueGrey, fontSize: 12)),
            ]),
            subtitle: Text("${DateFormat('dd/MM/yy').format(row['date'])} | Batch: ${row['batch']} | ${row['type']}"),
            trailing: Text("${isIn ? '+' : '-'}${isIn ? row['in'].toInt() : row['out'].toInt()}", style: TextStyle(fontWeight: FontWeight.bold, color: isIn ? Colors.green : Colors.red)),
          ),
        );
      },
    );
  }

  Widget _buildInitialState() {
    final ph = Provider.of<PharoahManager>(context);
    final list = ph.medicines.where((m) => m.name.toLowerCase().contains(medSearch.toLowerCase())).toList();
    if (medSearch.isEmpty) return const Center(child: Text("Please select a medicine to view its lifecycle."));
    return ListView.builder(itemCount: list.length, itemBuilder: (c, i) => ListTile(title: Text(list[i].name), subtitle: Text("Stock: ${list[i].stock}"), onTap: () => setState(() => selectedMed = list[i])));
  }

  Widget _quickStat(String l, String v, {bool isBold = false}) => Column(children: [Text(l, style: const TextStyle(color: Colors.white70, fontSize: 8)), Text(v, style: TextStyle(color: Colors.white, fontWeight: isBold ? FontWeight.w900 : FontWeight.bold, fontSize: 13))]);
}
