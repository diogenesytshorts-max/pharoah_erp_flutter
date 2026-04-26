// FILE: lib/modifications/sub_views/modify_challan_list.dart (Replacement Code - FIXED)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../pharoah_manager.dart';
import '../../../models.dart';
import '../../../challans/sale_challan_view.dart'; 

class ModifyChallanList extends StatelessWidget {
  final String searchQuery;
  const ModifyChallanList({super.key, required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    
    // Combine both Sale and Purchase Challans for the universal list
    List<dynamic> allChallans = [...ph.saleChallans, ...ph.purchaseChallans];
    
    final filtered = allChallans.where((c) {
      String name = (c is SaleChallan) ? c.partyName : (c as PurchaseChallan).distributorName;
      return c.billNo.toLowerCase().contains(searchQuery.toLowerCase()) || 
             name.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text("No challans found matching search.", style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final ch = filtered[i];
        bool isSale = ch is SaleChallan;
        
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isSale ? Colors.blueGrey : Colors.amber.shade700,
              child: Text(isSale ? "SC" : "PC", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            title: Text(ch.billNo, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(isSale ? (ch as SaleChallan).partyName : (ch as PurchaseChallan).distributorName),
            trailing: const Icon(Icons.more_vert),
            onTap: () => _showActionMenu(context, ph, ch),
          ),
        );
      },
    );
  }

  // --- ACTION MENU ---
  void _showActionMenu(BuildContext context, PharoahManager ph, dynamic challan) {
    bool isSale = challan is SaleChallan;
    // Check permissions from loggedInStaff
    bool canEdit = ph.loggedInStaff == null || ph.loggedInStaff!.canEditBill;
    bool canDelete = ph.loggedInStaff == null || ph.loggedInStaff!.canDeleteBill;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text("Challan: ${challan.billNo}", style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(isSale ? "Outward Sale Challan" : "Inward Purchase Challan"),
          ),
          const Divider(),
          
          if (canEdit && isSale)
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text("Edit / Modify Challan"),
              onTap: () {
                Navigator.pop(c);
                Navigator.push(context, MaterialPageRoute(
                  builder: (c) => SaleChallanView(existingRecord: challan as SaleChallan)
                ));
              },
            ),

          if (canDelete)
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text("Delete Challan Record"),
              onTap: () {
                _confirmDelete(context, ph, challan);
              },
            ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, PharoahManager ph, dynamic ch) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Delete Record?"),
        content: const Text("Are you sure? This will reverse the stock impact of this challan."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (ch is SaleChallan) ph.deleteSaleChallan(ch.id);
              else ph.deletePurchaseChallan(ch.id);
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
