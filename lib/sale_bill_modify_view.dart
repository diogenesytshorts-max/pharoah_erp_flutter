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
  String dur = "Today"; String pF = "All"; Party? sP;

  List<Sale> getF(List<Sale> all) {
    DateTime n = DateTime.now();
    return all.where((s) {
      bool dM = false;
      if (dur == "Today") dM = s.date.day == n.day && s.date.month == n.month && s.date.year == n.year;
      else if (dur == "Yesterday") { DateTime y = n.subtract(const Duration(days: 1)); dM = s.date.day == y.day && s.date.month == y.month && s.date.year == n.year; }
      else if (dur == "Month") dM = s.date.month == n.month && s.date.year == n.year;
      else dM = true;
      return dM && (pF == "All" || s.partyName == sP?.name);
    }).toList().reversed.toList();
  }

  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    final list = getF(ph.sales);
    return Scaffold(
      appBar: AppBar(title: const Text("Modify Sale Bill")),
      body: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          DropdownButton<String>(value: dur, items: ["Today", "Yesterday", "Month", "All"].map((e)=>DropdownMenuItem(value:e, child:Text(e))).toList(), onChanged: (v)=>setState(()=>dur=v!)),
          DropdownButton<String>(value: pF, items: ["All", "Single"].map((e)=>DropdownMenuItem(value:e, child:Text(e))).toList(), onChanged: (v)=>setState(()=>pF=v!)),
        ]),
        if (pF == "Single") ListTile(title: Text(sP?.name ?? "Select Party"), onTap: () {
          showDialog(context: context, builder: (c)=>SimpleDialog(title: const Text("Select Party"), children: ph.parties.map((p)=>SimpleDialogOption(child: Text(p.name), onPressed: (){ setState(()=>sP=p); Navigator.pop(c); })).toList()));
        }),
        const Divider(),
        Expanded(child: ListView.builder(itemCount: list.length, itemBuilder: (c, i) => Card(
          elevation: 2, margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          color: list[i].status == "Cancelled" ? Colors.red[50] : Colors.white,
          child: ListTile(
            title: Text("${list[i].billNo} | ${list[i].partyName}", style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Date: ${DateFormat('dd/MM/yyyy').format(list[i].date)} | ₹${list[i].totalAmount.toStringAsFixed(2)}"),
            trailing: PopupMenuButton<String>(onSelected: (v){
              final s = list[i];
              if(v=='v') Navigator.push(context, MaterialPageRoute(builder: (c)=>SaleEntryView(existingSale: s, isReadOnly: true)));
              if(v=='m') Navigator.push(context, MaterialPageRoute(builder: (c)=>SaleEntryView(existingSale: s)));
              if(v=='p') PdfService.generateInvoice(s, ph.parties.firstWhere((p)=>p.name==s.partyName, orElse: ()=>ph.parties[0]));
              if(v=='c') _cD(s, ph);
              if(v=='d') _dD(s, ph);
            }, itemBuilder: (c)=>[
              const PopupMenuItem(value: 'v', child: Text("View")),
              const PopupMenuItem(value: 'm', child: Text("Modify")),
              const PopupMenuItem(value: 'p', child: Text("Print")),
              const PopupMenuItem(value: 'c', child: Text("Cancel Bill")),
              const PopupMenuItem(value: 'd', child: Text("Delete Bill")),
            ]),
          ),
        )))
      ]),
    );
  }
  void _cD(Sale s, PharoahManager ph) => showDialog(context: context, builder: (c)=>AlertDialog(title: const Text("Cancel Bill?"), content: const Text("Stock will reverse but entry will stay."), actions: [TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("No")), TextButton(onPressed: (){ ph.cancelBill(s.id); Navigator.pop(c); }, child: const Text("Yes"))]));
  void _dD(Sale s, PharoahManager ph) => showDialog(context: context, builder: (c)=>AlertDialog(title: const Text("Delete Bill?"), content: const Text("Permanently delete and reverse stock."), actions: [TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("No")), TextButton(onPressed: (){ ph.deleteBill(s.id); Navigator.pop(c); }, child: const Text("Yes"))]));
}
