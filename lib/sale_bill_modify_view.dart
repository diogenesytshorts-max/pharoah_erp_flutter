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
      appBar: AppBar(title: const Text("Sale Bill Modify & Reports")),
      body: Column(children: [
        // --- FILTERS ---
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          DropdownButton<String>(value: dur, items: ["Today", "Yesterday", "Month", "All"].map((e)=>DropdownMenuItem(value:e, child:Text(e))).toList(), onChanged: (v)=>setState(()=>dur=v!)),
          DropdownButton<String>(value: pF, items: ["All", "Single"].map((e)=>DropdownMenuItem(value:e, child:Text(e))).toList(), onChanged: (v)=>setState(()=>pF=v!)),
        ]),
        if (pF == "Single") ListTile(title: Text(sP?.name ?? "Select Party"), onTap: () {
          showDialog(context: context, builder: (c)=>SimpleDialog(title: const Text("Select Party"), children: ph.parties.map((p)=>SimpleDialogOption(child: Text(p.name), onPressed: (){ setState(()=>sP=p); Navigator.pop(c); })).toList()));
        }),
        const Divider(),
        // --- SUMMARY LIST ---
        Expanded(child: ListView.builder(itemCount: list.length, itemBuilder: (c, i) {
          final s = list[i];
          return Card(
            elevation: 2, margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            color: s.status == "Cancelled" ? Colors.red[50] : Colors.white,
            child: ListTile(
              title: Text("${s.billNo} | ${s.partyName}", style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Date: ${DateFormat('dd/MM/yyyy').format(s.date)} | Total: ₹${s.totalAmount.toStringAsFixed(2)}"),
                Text(s.items.map((it) => "${it.name}(Qty:${it.qty.toInt()}, B:${it.batch})").join(", "), style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
              ]),
              isThreeLine: true,
              trailing: PopupMenuButton<String>(onSelected: (v) async {
                if(v=='v') Navigator.push(context, MaterialPageRoute(builder: (c)=>SaleEntryView(existingSale: s, isReadOnly: true)));
                if(v=='m') Navigator.push(context, MaterialPageRoute(builder: (c)=>SaleEntryView(existingSale: s)));
                if(v=='p') PdfService.generateInvoice(s, ph.parties.firstWhere((p)=>p.name==s.partyName, orElse: ()=>ph.parties[0]));
                if(v=='c') _confirmAction("Cancel", () => ph.cancelBill(s.id));
                if(v=='d') _confirmAction("Delete", () => ph.deleteBill(s.id));
              }, itemBuilder: (c)=>[
                const PopupMenuItem(value: 'v', child: Text("👁️ View Bill")),
                const PopupMenuItem(value: 'm', child: Text("✏️ Modify Bill")),
                const PopupMenuItem(value: 'p', child: Text("🖨️ Print Bill")),
                const PopupMenuItem(value: 'c', child: Text("🚫 Cancel Bill")),
                const PopupMenuItem(value: 'd', child: Text("🗑️ Delete Bill")),
              ]),
            ),
          );
        }))
      ]),
    );
  }

  void _confirmAction(String action, VoidCallback onConfirm) {
    showDialog(context: context, builder: (c)=>AlertDialog(title: Text("$action Bill?"), content: Text("This will reverse stock. Are you sure?"), actions: [
      TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("NO")),
      TextButton(onPressed: (){ onConfirm(); Navigator.pop(c); }, child: const Text("YES"))
    ]));
  }
}
