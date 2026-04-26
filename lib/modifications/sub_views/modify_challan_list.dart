import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../pharoah_manager.dart';
import '../../../models.dart';

class ModifyChallanList extends StatelessWidget {
  final String searchQuery;
  const ModifyChallanList({super.key, required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    
    // Combine Sale and Purchase Challans
    List<dynamic> allChallans = [...ph.saleChallans, ...ph.purchaseChallans];
    
    final filtered = allChallans.where((c) {
      String name = (c is SaleChallan) ? c.partyName : c.distributorName;
      return c.billNo.toLowerCase().contains(searchQuery.toLowerCase()) || 
             name.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final ch = filtered[i];
        bool isSale = ch is SaleChallan;
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isSale ? Colors.blueGrey : Colors.amber,
              child: Text(isSale ? "SC" : "PC", style: const TextStyle(color: Colors.white, fontSize: 10)),
            ),
            title: Text(ch.billNo, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(isSale ? ch.partyName : ch.distributorName),
            trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () {
              if (isSale) ph.deleteSaleChallan(ch.id); else ph.deletePurchaseChallan(ch.id);
            }),
          ),
        );
      },
    );
  }
}
