import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import 'purchase_entry_view.dart';

class PurchaseModifyView extends StatefulWidget {
  const PurchaseModifyView({super.key});
  @override State<PurchaseModifyView> createState() => _PurchaseModifyViewState();
}

class _PurchaseModifyViewState extends State<PurchaseModifyView> {
  String query = "";

  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    final list = ph.purchases.reversed.where((p) => 
      p.distributorName.toLowerCase().contains(query.toLowerCase()) || 
      p.billNo.toLowerCase().contains(query.toLowerCase())
    ).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(title: const Text("Purchase Register / Modify"), backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: TextField(decoration: const InputDecoration(hintText: "Search Supplier or Bill No...", prefixIcon: Icon(Icons.search), filled: true, fillColor: Colors.white, border: OutlineInputBorder()), onChanged: (v) => setState(() => query = v))),
        Expanded(child: list.isEmpty ? const Center(child: Text("No Purchase Record Found.")) : ListView.builder(itemCount: list.length, itemBuilder: (context, index) {
          final p = list[index];
          return Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), child: ListTile(
            title: Text(p.distributorName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Bill: ${p.billNo} | Date: ${DateFormat('dd/MM/yy').format(p.date)}\nAmt: ₹${p.totalAmount.toStringAsFixed(2)}"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (c) => PurchaseEntryView(existingPurchase: p)));
                }),
                IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _confirmDelete(context, ph, p)),
              ],
            ),
          ));
        }))
      ]),
    );
  }

  void _confirmDelete(BuildContext context, PharoahManager ph, Purchase p) {
    showDialog(context: context, builder: (c) => AlertDialog(title: const Text("Delete Purchase?"), content: const Text("Stock kam ho jayega. Sure?"), actions: [
      TextButton(onPressed: () => Navigator.pop(c), child: const Text("NO")),
      ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () { ph.deletePurchase(p.id); Navigator.pop(c); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Purchase Deleted!"))); }, child: const Text("YES, DELETE", style: TextStyle(color: Colors.white)))
    ]));
  }
}
