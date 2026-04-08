import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'sale_entry_view.dart';
import 'pdf_service.dart';
import 'package:intl/intl.dart';

class SaleBillModifyView extends StatefulWidget {
  const SaleBillModifyView({super.key});
  @override State<SaleBillModifyView> createState() => _SaleBillModifyViewState();
}

class _SaleBillModifyViewState extends State<SaleBillModifyView> {
  String duration = "Today"; String partyFilter = "All"; Party? selectedParty;
  
  List<Sale> getFiltered(List<Sale> all) {
    DateTime now = DateTime.now();
    return all.where((s) {
      bool dateMatch = false;
      if (duration == "Today") dateMatch = s.date.day == now.day && s.date.month == now.month && s.date.year == now.year;
      else if (duration == "Yesterday") { DateTime y = now.subtract(const Duration(days: 1)); dateMatch = s.date.day == y.day && s.date.month == y.month && s.date.year == y.year; }
      else if (duration == "Week") dateMatch = s.date.isAfter(now.subtract(const Duration(days: 7)));
      else if (duration == "Month") dateMatch = s.date.month == now.month && s.date.year == now.year;
      else dateMatch = true;

      bool partyMatch = (partyFilter == "All") || (s.partyName == selectedParty?.name);
      return dateMatch && partyMatch;
    }).toList().reversed.toList();
  }

  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    final filtered = getFiltered(ph.sales);
    return Scaffold(
      appBar: AppBar(title: const Text("Modify Sale Bill")),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(10), child: Row(children: [
          Expanded(child: DropdownButton(value: duration, items: ["Today", "Yesterday", "Week", "Month", "All"].map((e)=>DropdownMenuItem(value:e, child:Text(e))).toList(), onChanged: (v)=>setState(()=>duration=v!))),
          const SizedBox(width: 10),
          Expanded(child: DropdownButton(value: partyFilter, items: ["All", "Single"].map((e)=>DropdownMenuItem(value:e, child:Text(e))).toList(), onChanged: (v)=>setState(()=>partyFilter=v!))),
        ])),
        if (partyFilter == "Single") ListTile(title: Text(selectedParty?.name ?? "Select Party"), onTap: () {
          showDialog(context: context, builder: (c)=>SimpleDialog(children: ph.parties.map((p)=>SimpleDialogOption(child: Text(p.name), onPressed: (){ setState(()=>selectedParty=p); Navigator.pop(c); })).toList()));
        }),
        Expanded(child: ListView.builder(itemCount: filtered.length, itemBuilder: (c, i) {
          final s = filtered[i];
          return Card(color: s.status == "Cancelled" ? Colors.red[50] : Colors.white, child: ListTile(
            title: Text("${s.billNo} | ${s.partyName}"),
            subtitle: Text("${DateFormat('dd/MM/yyyy').format(s.date)} | ₹${s.totalAmount} (${s.status})"),
            trailing: PopupMenuButton(onSelected: (v) async {
              if (v == 'view') Navigator.push(context, MaterialPageRoute(builder: (c)=>SaleEntryView(existingSale: s, isReadOnly: true)));
              if (v == 'modify') Navigator.push(context, MaterialPageRoute(builder: (c)=>SaleEntryView(existingSale: s)));
              if (v == 'print') PdfService.generateInvoice(s, ph.parties.firstWhere((p)=>p.name==s.partyName));
              if (v == 'cancel') ph.cancelBill(s.id);
              if (v == 'delete') ph.deleteBill(s.id);
            }, itemBuilder: (c)=>[
              const PopupMenuItem(value: 'view', child: Text("View")),
              const PopupMenuItem(value: 'modify', child: Text("Modify")),
              const PopupMenuItem(value: 'print', child: Text("Print")),
              const PopupMenuItem(value: 'cancel', child: Text("Cancel Bill")),
              const PopupMenuItem(value: 'delete', child: Text("Delete Bill")),
            ]),
          ));
        }))
      ]),
    );
  }
}
