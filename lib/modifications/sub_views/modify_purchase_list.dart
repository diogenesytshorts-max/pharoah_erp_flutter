// FILE: lib/modifications/sub_views/modify_purchase_list.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../pharoah_manager.dart';
import '../../../models.dart';
import '../../../purchase/purchase_entry_view.dart';

class ModifyPurchaseList extends StatelessWidget {
  final String searchQuery;
  const ModifyPurchaseList({super.key, required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    final list = ph.purchases.reversed.where((p) => 
      p.billNo.toLowerCase().contains(searchQuery.toLowerCase()) ||
      p.distributorName.toLowerCase().contains(searchQuery.toLowerCase())
    ).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: list.length,
      itemBuilder: (c, i) {
        final p = list[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.orange, child: Text("P", style: TextStyle(color: Colors.white, fontSize: 12))),
            title: Text(p.billNo, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("${p.distributorName}\nDate: ${DateFormat('dd/MM/yy').format(p.date)}"),
            trailing: IconButton(icon: const Icon(Icons.more_vert), onPressed: () => _showOptions(context, ph, p)),
          ),
        );
      },
    );
  }

  void _showOptions(BuildContext context, PharoahManager ph, Purchase p) {
    bool canDelete = ph.loggedInStaff == null || ph.loggedInStaff!.canDeleteBill;

    showModalBottomSheet(context: context, builder: (c) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const ListTile(title: Text("Purchase Actions", style: TextStyle(fontWeight: FontWeight.bold))),
        ListTile(leading: const Icon(Icons.edit, color: Colors.blue), title: const Text("Edit Purchase"), onTap: () {
          Navigator.pop(c);
          Navigator.push(context, MaterialPageRoute(builder: (c) => PurchaseEntryView(existingPurchase: p)));
        }),
        if (canDelete)
          ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text("Delete Purchase"), onTap: () {
            ph.deletePurchase(p.id); Navigator.pop(c);
          }),
        const SizedBox(height: 20),
      ],
    ));
  }
}
