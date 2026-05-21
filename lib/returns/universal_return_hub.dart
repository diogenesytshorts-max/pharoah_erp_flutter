import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import '../pdf/pdf_router_service.dart';
import 'sale_return_view.dart';
import 'purchase_return_view.dart';

class UniversalReturnHub extends StatefulWidget {
  const UniversalReturnHub({super.key});
  @override State<UniversalReturnHub> createState() => _UniversalReturnHubState();
}

class _UniversalReturnHubState extends State<UniversalReturnHub> {
  String query = "";

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    
    // 1. DATA AGGREGATION: Dono returns ko ek hi list mein lana
    List<dynamic> allReturns = [...ph.saleReturns, ...ph.purchaseReturns];
    
    // 2. ARCHITECT SEARCH LOGIC: Universal filtering (Name, No, City, Amt)
    final filtered = allReturns.where((r) {
      bool isSR = r is SaleReturn;
      String partyName = isSR ? r.partyName : (r as PurchaseReturn).distributorName;
      
      // Architect Rule: Sab kuch check karo
      return partyName.toLowerCase().contains(query.toLowerCase()) || 
             r.billNo.toLowerCase().contains(query.toLowerCase()) ||
             r.totalAmount.toString().contains(query);
    }).toList();

    // Latest entries sabse upar
    filtered.sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      backgroundColor: const Color(0xFFF1F4F8),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Returns & Reversals Hub", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text("FY: ${ph.currentFY} | Total: ${filtered.length}", style: const TextStyle(fontSize: 10, color: Colors.white70)),
          ],
        ),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ARCHITECT SEARCH BAR
          Container(
            padding: const EdgeInsets.all(15),
            color: const Color(0xFF1A237E),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              onChanged: (v) => setState(() => query = v),
              decoration: InputDecoration(
                hintText: "Search Party, Bill No or Amount...",
                hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),

          Expanded(
            child: filtered.isEmpty 
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (c, i) => _buildReturnCard(filtered[i], ph),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnCard(dynamic ret, PharoahManager ph) {
    bool isSR = ret is SaleReturn;
    String name = isSR ? ret.partyName : (ret as PurchaseReturn).distributorName;
    bool isCancelled = ret.status == "Cancelled";

    return Card(
      color: isCancelled ? Colors.red.shade50 : Colors.white,
      elevation: isCancelled ? 0 : 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: isCancelled ? Colors.red.shade100 : Colors.transparent),
      ),
      child: ListTile(
        onTap: () => _showActionMenu(context, ph, ret),
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSR ? Colors.red.shade100 : Colors.amber.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(isSR ? "CN" : "DN", style: TextStyle(fontWeight: FontWeight.bold, color: isSR ? Colors.red.shade900 : Colors.amber.shade900, fontSize: 12)),
        ),
        title: Text(name, style: TextStyle(fontWeight: FontWeight.bold, decoration: isCancelled ? TextDecoration.lineThrough : null)),
        subtitle: Text("${ret.billNo} | ${DateFormat('dd/MM/yyyy').format(ret.date)}", style: const TextStyle(fontSize: 11)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text("₹${ret.totalAmount.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.w900, color: isCancelled ? Colors.red.shade300 : Colors.black87)),
            if (isCancelled) const Text("CANCELLED", style: TextStyle(fontSize: 8, color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 🛠️ THE 5-ACTION WORKFLOW ENGINE
  // ===========================================================================
  void _showActionMenu(BuildContext context, PharoahManager ph, dynamic ret) {
    bool isSR = ret is SaleReturn;
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (c) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isSR ? "SALE CREDIT NOTE ACTIONS" : "PURCHASE DEBIT NOTE ACTIONS", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 11)),
            const Divider(),
            
            // 1. VIEW (ReadOnly)
            _menuTile(Icons.visibility_outlined, "View Items (Audit)", Colors.blue, () {
              Navigator.pop(c);
              Navigator.push(context, MaterialPageRoute(builder: (context) => isSR 
                ? SaleReturnView(existingRecord: ret, isReadOnly: true) 
                : PurchaseReturnView(existingRecord: ret, isReadOnly: true)));
            }),

            // 2. MODIFY (Edit)
            _menuTile(Icons.edit_note_rounded, "Modify / Edit Bill", Colors.orange, () {
              Navigator.pop(c);
              Navigator.push(context, MaterialPageRoute(builder: (context) => isSR 
                ? SaleReturnView(existingRecord: ret) 
                : PurchaseReturnView(existingRecord: ret)));
            }),

            // 3. CANCEL (Reverse Stock, Keep Number)
            _menuTile(Icons.block_flipped, "Cancel Return (Safe Reversal)", Colors.deepOrange, () {
              Navigator.pop(c);
              _confirmStatusChange(ph, ret, isSR);
            }),

            // 4. PRINT (Smart Router)
            _menuTile(Icons.print_rounded, "Print / Share PDF", Colors.teal, () {
              Navigator.pop(c);
              if (isSR) {
                PdfRouterService.printCreditNote(returnObj: ret, party: ph.parties.firstWhere((p) => p.name == ret.partyName), ph: ph);
              } else {
                PdfRouterService.printDebitNote(returnObj: ret, supplier: ph.parties.firstWhere((p) => p.name == ret.distributorName), ph: ph);
              }
            }),

            const Divider(),

            // 5. DELETE (Hard Wipe)
            _menuTile(Icons.delete_forever_rounded, "Delete Permanently", Colors.red, () {
              Navigator.pop(c);
              _confirmDelete(ph, ret, isSR);
            }),
          ],
        ),
      ),
    );
  }

  Widget _menuTile(IconData i, String t, Color c, VoidCallback onTap) => ListTile(leading: Icon(i, color: c), title: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), onTap: onTap);

  void _confirmStatusChange(PharoahManager ph, dynamic ret, bool isSR) {
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text("Cancel Return?"),
      content: const Text("Isse stock wapas pichli position par aa jayega aur amount reverse ho jayega. Bill Number series mein hi rahega. Continue?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text("NO")),
        ElevatedButton(onPressed: () { ph.cancelReturn(ret.id, isSR); Navigator.pop(c); }, child: const Text("YES, CANCEL")),
      ],
    ));
  }

  void _confirmDelete(PharoahManager ph, dynamic ret, bool isSR) {
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text("Delete Record Permanently?"),
      content: const Text("DANGER: Ye record system se mita diya jayega. Kya aap sure hain?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () { 
          if(isSR) ph.deleteSaleReturn(ret.id); else ph.deletePurchaseReturn(ret.id);
          Navigator.pop(c); 
        }, child: const Text("YES, DELETE EVERYTHING", style: TextStyle(color: Colors.white))),
      ],
    ));
  }

  Widget _buildEmptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.history_rounded, size: 60, color: Colors.grey.shade300), const Text("No Return records found.", style: TextStyle(color: Colors.grey))]));
}
