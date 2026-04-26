// FILE: lib/modifications/sub_views/modify_returns_list.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../pharoah_manager.dart';
import '../../../models.dart';
import '../../../returns/sale_return_view.dart'; // NAYA IMPORT

class ModifyReturnsList extends StatelessWidget {
  final String searchQuery;
  const ModifyReturnsList({super.key, required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    
    // Combine both Sale and Purchase Returns for the list
    List<dynamic> allReturns = [...ph.saleReturns, ...ph.purchaseReturns];

    final filtered = allReturns.where((r) {
      String name = (r is SaleReturn) ? r.partyName : (r as PurchaseReturn).distributorName;
      return r.billNo.toLowerCase().contains(searchQuery.toLowerCase()) || 
             name.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text("No returns found matching search.", style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final ret = filtered[i];
        bool isSaleRet = ret is SaleReturn;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isSaleRet ? Colors.red.shade700 : Colors.brown,
              child: Text(isSaleRet ? "SR" : "PR", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            title: Text(ret.billNo, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isSaleRet ? ret.partyName : (ret as PurchaseReturn).distributorName),
                Text("Amt: ₹${ret.totalAmount.toStringAsFixed(2)} | Date: ${DateFormat('dd/MM').format(ret.date)}", style: const TextStyle(fontSize: 10)),
              ],
            ),
            trailing: const Icon(Icons.more_vert),
            onTap: () => _showActionMenu(context, ph, ret),
          ),
        );
      },
    );
  }

  // --- ACTION MENU: VIEW / EDIT / DELETE ---
  void _showActionMenu(BuildContext context, PharoahManager ph, dynamic returnObj) {
    bool isSaleRet = returnObj is SaleReturn;
    bool canEdit = ph.loggedInStaff == null || ph.loggedInStaff!.canEditBill;
    bool canDelete = ph.loggedInStaff == null || ph.loggedInStaff!.canDeleteBill;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text("Return: ${returnObj.billNo}", style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(isSaleRet ? "Sale Credit Note" : "Purchase Debit Note"),
          ),
          const Divider(),
          
          // 1. EDIT ACTION (Connected only to SaleReturnView for now)
          if (canEdit && isSaleRet)
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text("Edit / Modify Return"),
              onTap: () {
                Navigator.pop(c);
                Navigator.push(context, MaterialPageRoute(
                  builder: (c) => SaleReturnView(existingRecord: returnObj as SaleReturn)
                ));
              },
            )
          else if (canEdit && !isSaleRet)
            const ListTile(
              leading: Icon(Icons.lock_clock, color: Colors.grey),
              title: Text("Purchase Return Edit (Coming Soon)"),
            ),

          // 2. DELETE ACTION
          if (canDelete)
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text("Delete Return Record"),
              onTap: () {
                _confirmDelete(context, ph, returnObj);
              },
            ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, PharoahManager ph, dynamic ret) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Delete Return?"),
        content: const Text("This will reverse the balance and stock adjustment for this return."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (ret is SaleReturn) ph.deleteSaleReturn(ret.id);
              else ph.deletePurchaseReturn(ret.id);
              Navigator.pop(c); // Close Alert
              Navigator.pop(context); // Close BottomSheet
            }, 
            child: const Text("YES, DELETE", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }
}
