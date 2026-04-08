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
      bool dM = false;
      if (duration == "Today") dM = s.date.day == now.day && s.date.month == now.month && s.date.year == now.year;
      else if (duration == "Yesterday") { DateTime y = now.subtract(const Duration(days: 1)); dM = s.date.day == y.day && s.date.month == y.month && s.date.year == y.year; }
      else if (duration == "Month") dM = s.date.month == now.month && s.date.year == now.year;
      else dM = true;
      return dM && (partyFilter == "All" || s.partyName == selectedParty?.name);
    }).toList().reversed.toList();
  }

  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    final list = getFiltered(ph.sales);
    return Scaffold(
      appBar: AppBar(title: const Text("Sale Bill Modify")),
      body: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          DropdownButton(value: duration, items: ["Today", "Yesterday", "Month", "All"].map((e)=>DropdownMenuItem(value:e, child:Text(e))).toList(), onChanged: (v)=>setState(()=>duration=v!)),
          DropdownButton(value: partyFilter, items: ["All", "Single"].map((e)=>DropdownMenuItem(value:e, child:Text(e))).toList(), onChanged: (v)=>setState(()=>partyFilter=v!)),
        ]),
        if (partyFilter == "Single") ListTile(title: Text(selectedParty?.name ?? "Select Party"), onTap: () {
          showDialog(context: context, builder: (c)=>SimpleDialog(title: const Text("Select Party"), children: ph.parties.map((p)=>SimpleDialogOption(child: Text(p.name), onPressed: (){ setState(()=>selectedParty=p); Navigator.pop(c); })).toList()));
        }),
        const Divider(),
        Expanded(child: ListView.builder(itemCount: list.length, itemBuilder: (c, i) {
          final s = list[i];
          return Card(elevation: 2, margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), child: ListTile(
            title: Text("${s.billNo} | ${s.partyName}", style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Date: ${DateFormat('dd/MM/yyyy').format(s.date)} | Amount: ₹${s.totalAmount.toStringAsFixed(2)}"),
            trailing: PopupMenuButton(onSelected: (v){
              if(v=='v') Navigator.push(context, MaterialPageRoute(builder: (c)=>SaleEntryView(existingSale: s, isReadOnly: true)));
              if(v=='m') Navigator.push(context, MaterialPageRoute(builder: (c)=>SaleEntryView(existingSale: s)));
              if(v=='p') PdfService.generateInvoice(s, ph.parties.firstWhere((p)=>p.name==s.partyName, orElse: ()=>ph.parties[0]));
              if(v=='c') _cancelDialog(s, ph);
              if(v=='d') _deleteDialog(s, ph);
            }, itemBuilder: (c)=>[
              const PopupMenuItem(value: 'v', child: Row(children: [Icon(Icons.visibility, color: Colors.purple), Text(" View")])),
              const PopupMenuItem(value: 'm', child: Row(children: [Icon(Icons.edit, color: Colors.orange), Text(" Modify")])),
              const PopupMenuItem(value: 'p', child: Row(children: [Icon(Icons.print, color: Colors.blue), Text(" Print")])),
              const PopupMenuItem(value: 'c', child: Row(children: [Icon(Icons.block, color: Colors.red), Text(" Cancel")])),
              const PopupMenuItem(value: 'd', child: Row(children: [Icon(Icons.delete, color: Colors.black), Text(" Delete")])),
            ]),
          ));
        }))
      ]),
    );
  }
  void _cancelDialog(Sale s, PharoahManager ph) => showDialog(context: context, builder: (c)=>AlertDialog(title: const Text("Cancel Bill?"), content: const Text("Stock will be reversed but bill entry will remain with 0 amount."), actions: [TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("No")), TextButton(onPressed: (){ ph.cancelBill(s.id); Navigator.pop(c); }, child: const Text("Yes"))]));
  void _deleteDialog(Sale s, PharoahManager ph) => showDialog(context: context, builder: (c)=>AlertDialog(title: const Text("Delete Bill?"), content: const Text("This will permanently remove the bill and reverse stock."), actions: [TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("No")), TextButton(onPressed: (){ ph.deleteBill(s.id); Navigator.pop(c); }, child: const Text("Yes"))]));
}
