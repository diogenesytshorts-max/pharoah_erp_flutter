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
      else if (duration == "Month") dateMatch = s.date.month == now.month && s.date.year == now.year;
      else dateMatch = true;
      return dateMatch && (partyFilter == "All" || s.partyName == selectedParty?.name);
    }).toList().reversed.toList();
  }

  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    final list = getFiltered(ph.sales);
    return Scaffold(
      appBar: AppBar(title: const Text("Modify Sale Bill")),
      body: Column(children: [
        Row(children: [
          Expanded(child: DropdownButton(value: duration, items: ["Today", "Yesterday", "Month", "All"].map((e)=>DropdownMenuItem(value:e, child:Text(e))).toList(), onChanged: (v)=>setState(()=>duration=v!))),
          Expanded(child: DropdownButton(value: partyFilter, items: ["All", "Single"].map((e)=>DropdownMenuItem(value:e, child:Text(e))).toList(), onChanged: (v)=>setState(()=>partyFilter=v!))),
        ]),
        if (partyFilter == "Single") ListTile(title: Text(selectedParty?.name ?? "Select Party"), onTap: () {
          showDialog(context: context, builder: (c)=>SimpleDialog(children: ph.parties.map((p)=>SimpleDialogOption(child: Text(p.name), onPressed: (){ setState(()=>selectedParty=p); Navigator.pop(c); })).toList()));
        }),
        Expanded(child: ListView.builder(itemCount: list.length, itemBuilder: (c, i) => Card(
          color: list[i].status == "Cancelled" ? Colors.red[50] : Colors.white,
          child: ListTile(
            title: Text("${list[i].billNo} | ${list[i].partyName}"),
            subtitle: Text("₹${list[i].totalAmount} (${list[i].status})"),
            trailing: PopupMenuButton(onSelected: (v){
              if(v=='v') Navigator.push(context, MaterialPageRoute(builder: (c)=>SaleEntryView(existingSale: list[i], isReadOnly: true)));
              if(v=='m') Navigator.push(context, MaterialPageRoute(builder: (c)=>SaleEntryView(existingSale: list[i])));
              if(v=='p') PdfService.generateInvoice(list[i], ph.parties.firstWhere((p)=>p.name==list[i].partyName));
              if(v=='c') ph.cancelBill(list[i].id);
              if(v=='d') ph.deleteBill(list[i].id);
            }, itemBuilder: (c)=>[
              const PopupMenuItem(value: 'v', child: Text("View")),
              const PopupMenuItem(value: 'm', child: Text("Modify")),
              const PopupMenuItem(value: 'p', child: Text("Print")),
              const PopupMenuItem(value: 'c', child: Text("Cancel")),
              const PopupMenuItem(value: 'd', child: Text("Delete")),
            ]),
          ),
        )))
      ]),
    );
  }
}
