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
    // Search logic + Latest bills on top
    final list = ph.purchases.reversed.where((p) => 
      p.distributorName.toLowerCase().contains(query.toLowerCase()) || 
      p.billNo.toLowerCase().contains(query.toLowerCase())
    ).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("Purchase Register / Modify"), 
        backgroundColor: Colors.orange.shade800, 
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(children: [
        // --- 1. SEARCH BAR ---
        Padding(
          padding: const EdgeInsets.all(12), 
          child: TextField(
            decoration: InputDecoration(
              hintText: "Search Supplier or Bill No...", 
              prefixIcon: const Icon(Icons.search, color: Colors.orange), 
              filled: true, fillColor: Colors.white, 
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)
            ), 
            onChanged: (v) => setState(() => query = v)
          )
        ),

        // --- 2. PURCHASE BILLS LIST ---
        Expanded(
          child: list.isEmpty 
          ? const Center(child: Text("No Purchase Record Found.")) 
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: list.length, 
              itemBuilder: (context, index) {
                final p = list[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 8), 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                    title: Text(p.distributorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    subtitle: Text("Bill: ${p.billNo} | Date: ${DateFormat('dd/MM/yy').format(p.date)}\nAmt: ₹${p.totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 12)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // PRINT BUTTON (Landscape PDF)
                        IconButton(
                          icon: const Icon(Icons.print, color: Colors.blueGrey, size: 22), 
                          onPressed: () {
                            final party = ph.parties.firstWhere((pt) => pt.name == p.distributorName, orElse: () => ph.parties[0]);
                            PdfService.generatePurchaseInvoice(p, party);
                          }
                        ),
                        // EDIT BUTTON
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue, size: 22), 
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => PurchaseEntryView(existingPurchase: p)))
                        ),
                        // DELETE BUTTON
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22), 
                          onPressed: () => _confirmDelete(context, ph, p)
                        ),
                      ],
                    ),
                    onTap: () => _showPurchaseDetails(context, p), // View items on tap
                  )
                );
              }
            )
        )
      ]),
    );
  }

  // --- POPUP TO VIEW ITEMS INSIDE PURCHASE ---
  void _showPurchaseDetails(BuildContext context, Purchase p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("PURCHASE DETAILS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))
              ],
            ),
            Text(p.distributorName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text("Bill No: ${p.billNo} | Date: ${DateFormat('dd MMM yyyy').format(p.date)}"),
            const Divider(height: 30),
            const Text("ITEMS LIST:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blueGrey)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                itemCount: p.items.length,
                separatorBuilder: (c, i) => const Divider(height: 1),
                itemBuilder: (c, i) {
                  final it = p.items[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(it.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text("Batch: ${it.batch} | Exp: ${it.exp}\nQty: ${it.qty.toInt()} + ${it.freeQty.toInt()} (Free) | Rate: ₹${it.purchaseRate}"),
                    trailing: Text("₹${it.total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  );
                },
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("TOTAL AMOUNT:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text("₹${p.totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.deepOrange)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- DELETE CONFIRMATION ---
  void _confirmDelete(BuildContext context, PharoahManager ph, Purchase p) {
    showDialog(
      context: context, 
      builder: (c) => AlertDialog(
        title: const Text("Delete Purchase Bill?"), 
        content: Text("Is bill ko delete karne se stock kam ho jayega. Kya aap sure hain?"), 
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red), 
            onPressed: () { 
              ph.deletePurchase(p.id); 
              Navigator.pop(c); 
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Purchase Deleted Successfully!"), backgroundColor: Colors.redAccent)); 
            }, 
            child: const Text("YES, DELETE", style: TextStyle(color: Colors.white))
          )
        ]
      )
    );
  }
}
