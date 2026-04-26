import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../pharoah_manager.dart';
import '../../../models.dart';
import '../../../sale_entry_view.dart';

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
            leading: const CircleAvatar(backgroundColor: Colors.green, child: Text("S", style: TextStyle(color: Colors.white))),
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
    showModalBottomSheet(context: context, builder: (c) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(leading: const Icon(Icons.edit, color: Colors.blue), title: const Text("Edit Bill"), onTap: () {
          Navigator.pop(c);
          Navigator.push(context, MaterialPageRoute(builder: (c) => SaleEntryView(existingSale: s)));
        }),
        ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text("Delete Bill"), onTap: () {
          ph.deleteBill(s.id); Navigator.pop(c);
        }),
      ],
    ));
  }
}
