import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import '../pdf/purchase_pdf.dart'; // Naya PDF class import
import 'purchase_entry_view.dart';

class PurchaseModifyView extends StatefulWidget {
  const PurchaseModifyView({super.key});

  @override
  State<PurchaseModifyView> createState() => _PurchaseModifyViewState();
}

class _PurchaseModifyViewState extends State<PurchaseModifyView> {
  String searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    
    // Purchases ko ulta (reversed) dikha rahe hain taaki naye bill upar rahein
    final list = ph.purchases.reversed.where((p) => 
      p.distributorName.toLowerCase().contains(searchQuery.toLowerCase()) || 
      p.billNo.toLowerCase().contains(searchQuery.toLowerCase())
    ).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("Purchase Register / Modify"), 
        backgroundColor: Colors.orange.shade800, 
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // --- SEARCH BAR ---
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search Supplier or Bill No...", 
                prefixIcon: const Icon(Icons.search, color: Colors.orange), 
                filled: true, 
                fillColor: Colors.white, 
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10), 
                  borderSide: BorderSide.none
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0)
              ), 
              onChanged: (v) => setState(() => searchQuery = v)
            ),
          ),

          // --- PURCHASE LIST ---
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
                      subtitle: Text("Bill: ${p.billNo} | Date: ${DateFormat('dd/MM/yy').format(p.date)}\nTotal Amt: ₹${p.totalAmount.toStringAsFixed(2)}"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 1. PRINT BUTTON (Naya Logic)
                          IconButton(
                            icon: const Icon(Icons.print, color: Colors.blueGrey, size: 22), 
                            onPressed: () {
                              final supplier = ph.parties.firstWhere(
                                (pt) => pt.name == p.distributorName, 
                                orElse: () => ph.parties[0]
                              );
                              PurchasePdf.generate(p, supplier); // Nayi PDF call
                            }
                          ),
                          // 2. EDIT BUTTON
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue, size: 22), 
                            onPressed: () => Navigator.push(
                              context, 
                              MaterialPageRoute(builder: (c) => PurchaseEntryView(existingPurchase: p))
                            )
                          ),
                          // 3. DELETE BUTTON
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22), 
                            onPressed: () => _confirmDelete(context, ph, p)
                          ),
                        ],
                      ),
                      onTap: () => _showPurchaseDetails(context, p),
                    )
                  );
                }
              )
          )
        ],
      ),
    );
  }

  // --- DELETE CONFIRMATION ---
  void _confirmDelete(BuildContext context, PharoahManager ph, Purchase p) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Delete Purchase?"),
        content: const Text("Isse aapka stock automatic kam ho jayega. Kya aap ise delete karna chahte hain?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("NO")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ph.deletePurchase(p.id);
              Navigator.pop(c);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Purchase Deleted!")));
            }, 
            child: const Text("YES, DELETE", style: TextStyle(color: Colors.white))
          )
        ],
      ),
    );
  }

  // --- QUICK VIEW MODAL ---
  void _showPurchaseDetails(BuildContext context, Purchase p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const Padding(padding: EdgeInsets.all(15), child: Text("Purchase Item Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: p.items.length,
                itemBuilder: (c, i) => ListTile(
                  title: Text(p.items[i].name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Batch: ${p.items[i].batch} | Qty: ${p.items[i].qty.toInt()} + ${p.items[i].freeQty.toInt()} Free"),
                  trailing: Text("₹${p.items[i].total.toStringAsFixed(2)}"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
