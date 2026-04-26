// FILE: lib/modifications/sub_views/modify_returns_list.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../pharoah_manager.dart';
import '../../../models.dart';

class ModifyReturnsList extends StatelessWidget {
  final String searchQuery;
  const ModifyReturnsList({super.key, required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    List<dynamic> allReturns = [...ph.saleReturns, ...ph.purchaseReturns];

    final filtered = allReturns.where((r) {
      String name = (r is SaleReturn) ? r.partyName : (r as PurchaseReturn).distributorName;
      return r.billNo.toLowerCase().contains(searchQuery.toLowerCase()) || 
             name.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final ret = filtered[i];
        bool isSaleRet = ret is SaleReturn;
        bool canDelete = ph.loggedInStaff == null || ph.loggedInStaff!.canDeleteBill;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isSaleRet ? Colors.red : Colors.brown,
              child: Text(isSaleRet ? "SR" : "PR", style: const TextStyle(color: Colors.white, fontSize: 10)),
            ),
            title: Text(ret.billNo, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("${isSaleRet ? ret.partyName : ret.distributorName}\nType: ${ret.returnType}"),
            trailing: canDelete
              ? IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () {
                  if (isSaleRet) ph.deleteSaleReturn(ret.id); else ph.deletePurchaseReturn(ret.id);
                })
              : const Icon(Icons.lock_outline, size: 18, color: Colors.grey),
          ),
        );
      },
    );
  }
}
