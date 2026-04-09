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
  String dur = "Today"; 
  String pF = "All"; 
  Party? sP;

  List<Sale> getFilteredSales(List<Sale> all) {
    DateTime n = DateTime.now();
    return all.where((s) {
      bool dateMatch = true;
      if (dur == "Today") dateMatch = s.date.day == n.day && s.date.month == n.month && s.date.year == n.year;
      else if (dur == "Month") dateMatch = s.date.month == n.month && s.date.year == n.year;
      
      bool partyMatch = (pF == "All" || sP == null) ? true : (s.partyName == sP!.name);
      return dateMatch && partyMatch;
    }).toList().reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    final list = getFilteredSales(ph.sales);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(title: const Text("Modify Bills"), backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12), color: Colors.white,
            child: Row(children: [
              Expanded(child: DropdownButton<String>(isExpanded: true, value: dur, items: ["Today", "Month", "All"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => dur = v!))),
              const SizedBox(width: 15),
              Expanded(child: DropdownButton<String>(isExpanded: true, value: pF, items: ["All", "Single"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() { pF = v!; if(pF=="All") sP = null; }))),
            ]),
          ),
          if (pF == "Single")
            Padding(
              padding: const EdgeInsets.all(10),
              child: ListTile(
                tileColor: Colors.white,
                // FIX: border parameter removed, side used instead
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10), 
                  side: BorderSide(color: Colors.orange.shade100, width: 1)
                ),
                leading: const Icon(Icons.person, color: Colors.orange),
                title: Text(sP?.name ?? "Select Party"),
                onTap: () {
                   showDialog(context: context, builder: (c) => SimpleDialog(title: const Text("Select Party"), children: ph.parties.map((p) => SimpleDialogOption(onPressed: () { setState(() => sP = p); Navigator.pop(c); }, child: Text(p.name))).toList()));
                },
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (c, i) => Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  title: Text("${list[i].billNo} | ${list[i].partyName}"),
                  subtitle: Text("₹${list[i].totalAmount.toStringAsFixed(2)}"),
                  trailing: IconButton(icon: const Icon(Icons.edit), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => SaleEntryView(existingSale: list[i])))),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
