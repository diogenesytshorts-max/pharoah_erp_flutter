// FILE: lib/modifications/sub_views/modify_sales_list.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../pharoah_manager.dart';
import '../../../models.dart';
import '../../../sale_entry_view.dart';
import '../../../pdf/pdf_router_service.dart'; // NAYA IMPORT

class ModifySalesList extends StatelessWidget {
  final String searchQuery;
  const ModifySalesList({super.key, required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    final list = ph.sales.reversed.where((s) => 
      s.billNo.toLowerCase().contains(searchQuery.toLowerCase()) ||
      s.partyName.toLowerCase().contains(searchQuery.toLowerCase())
    ).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: list.length,
      itemBuilder: (c, i) {
        final s = list[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.green, child: Text("S", style: TextStyle(color: Colors.white, fontSize: 12))),
            title: Text(s.billNo, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("${s.partyName}\nAmt: ₹${s.totalAmount.toStringAsFixed(2)}"),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showOptions(context, ph, s),
            ),
          ),
        );
      },
    );
  }

  void _showOptions(BuildContext context, PharoahManager ph, Sale s) {
    // --- SECURITY CHECK ---
    bool canDelete = ph.loggedInStaff == null || ph.loggedInStaff!.canDeleteBill;

    showModalBottomSheet(context: context, builder: (c) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const ListTile(title: Text("Bill Actions", style: TextStyle(fontWeight: FontWeight.bold))),
        
        // 1. EDIT OPTION
        ListTile(leading: const Icon(Icons.edit, color: Colors.blue), title: const Text("Edit / Modify Bill"), onTap: () {
          Navigator.pop(c);
          Navigator.push(context, MaterialPageRoute(builder: (c) => SaleEntryView(existingSale: s)));
        }),

        // 2. NAYA: PRINT OPTION (Router Integrated)
        ListTile(
          leading: const Icon(Icons.print, color: Colors.teal), 
          title: const Text("Print / Share PDF"), 
          onTap: () {
            Navigator.pop(c);
            // Party details fetch karna PDF ke liye
            final p = ph.parties.firstWhere(
              (x) => x.name == s.partyName, 
              orElse: () => Party(id: 'temp', name: s.partyName, gst: s.partyGstin, state: s.partyState)
            );
            
            // Universal Router call jo Settings automatic check karega
            PdfRouterService.printSale(
              sale: s, 
              party: p, 
              ph: ph
            );
          }
        ),
        
        const Divider(),

        // 3. DELETE OPTION
        if (canDelete)
          ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text("Delete Bill Permanent"), onTap: () {
            ph.deleteBill(s.id); Navigator.pop(c);
          })
        else
          const ListTile(
            leading: Icon(Icons.lock, color: Colors.grey), 
            title: Text("Delete Restricted", style: TextStyle(color: Colors.grey)),
            subtitle: Text("Staff does not have delete permission", style: TextStyle(fontSize: 10)),
          ),
        const SizedBox(height: 20),
      ],
    ));
  }
}
