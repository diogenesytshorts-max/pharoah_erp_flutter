import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import '../pdf_service.dart';
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
        Padding(padding: const EdgeInsets.all(12), child: TextField(decoration: InputDecoration(hintText: "Search Supplier or Bill No...", prefixIcon: const Icon(Icons.search, color: Colors.orange), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)), onChanged: (v) => setState(() => query = v))),
        Expanded(child: list.isEmpty ? const Center(child: Text("No Purchase Record Found.")) : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 10), itemCount: list.length, itemBuilder: (context, index) {
          final p = list[index];
          return Card(elevation: 2, margin: const EdgeInsets.only(bottom: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            title: Text(p.distributorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: Text("Bill: ${p.billNo} | Date: ${DateFormat('dd/MM/yy').format(p.date)}\nAmt: ₹${p.totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 12)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.print, color: Colors.blueGrey, size: 22), onPressed: () {
                  final party = ph.parties.firstWhere((pt) => pt.name == p.distributorName, orElse: () => ph.parties[0]);
                  PdfService.generatePurchaseInvoice(p, party);
                }),
                IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 22), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => PurchaseEntryView(existingPurchase: p)))),
                IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22), onPressed: () => _confirmDelete(context, ph, p)),
              ],
            ),
            onTap: () => _showPurchaseDetails(context, p),
          ));
        }))
      ]),
    );
  }

  void _showPurchaseDetails(BuildContext context, Purchase p) { /* ... same as before ... */ }
  void _confirmDelete(BuildContext context, PharoahManager ph, Purchase p) { /* ... same as before ... */ }
}
