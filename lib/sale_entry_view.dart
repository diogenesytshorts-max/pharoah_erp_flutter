import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'sale_bill_number.dart';
import 'billing_view.dart';

class SaleEntryView extends StatefulWidget {
  final Sale? existingSale; final bool isReadOnly;
  const SaleEntryView({super.key, this.existingSale, this.isReadOnly = false});
  @override State<SaleEntryView> createState() => _SaleEntryViewState();
}

class _SaleEntryViewState extends State<SaleEntryView> {
  String bN = ""; DateTime bD = DateTime.now(); String pM = "CASH"; Party? sP; String sPT = "";
  DateTime firstDate = DateTime(2024, 4, 1);
  DateTime lastDate = DateTime(2025, 3, 31);

  @override void initState() {
    super.initState();
    _loadFYConstraints();
    if (widget.existingSale != null) { bN = widget.existingSale!.billNo; bD = widget.existingSale!.date; pM = widget.existingSale!.paymentMode; } 
    else { _load(); }
  }

  _loadFYConstraints() async {
    final p = await SharedPreferences.getInstance();
    String fy = p.getString('fy') ?? "2025-26";
    int startYear = int.parse(fy.split('-')[0]);
    if (startYear < 100) startYear += 2000;
    setState(() {
      firstDate = DateTime(startYear, 4, 1);
      lastDate = DateTime(startYear + 1, 3, 31);
      // Agar current date FY se bahar hai toh FY ki start date pe set kardo
      if (bD.isBefore(firstDate) || bD.isAfter(lastDate)) bD = firstDate;
    });
  }

  _load() async { String n = await SaleBillNumber.getNextNumber(); setState(() => bN = n); }

  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    if (widget.existingSale != null && sP == null) { sP = ph.parties.firstWhere((p) => p.name == widget.existingSale!.partyName, orElse: () => ph.parties[0]); }
    return Scaffold(
      appBar: AppBar(title: Text(widget.isReadOnly ? "View Bill" : (widget.existingSale == null ? "New Sale" : "Modify Sale"))),
      body: Column(children: [
        Container(padding: const EdgeInsets.all(15), color: widget.isReadOnly ? Colors.grey[200] : Colors.blue[50], child: Column(children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("BILL NO", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), Text(bN, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: widget.isReadOnly ? Colors.grey : Colors.blue))])),
            Expanded(child: InkWell(onTap: widget.isReadOnly ? null : () async { 
              DateTime? p = await showDatePicker(context: context, initialDate: bD, firstDate: firstDate, lastDate: lastDate); 
              if (p != null) setState(() => bD = p); 
            }, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [const Text("DATE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), Text(DateFormat('dd/MM/yyyy').format(bD), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)) ])))
          ]),
          const SizedBox(height: 15),
          AbsorbPointer(absorbing: widget.isReadOnly, child: SegmentedButton<String>(segments: const [ButtonSegment(value: 'CASH', label: Text('CASH')), ButtonSegment(value: 'CREDIT', label: Text('CREDIT'))], selected: {pM}, onSelectionChanged: (v) => setState(() => pM = v.first)))
        ])),
        if (sP != null) ListTile(leading: const Icon(Icons.person), title: Text(sP!.name, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(sP!.phone), trailing: widget.isReadOnly || widget.existingSale != null ? const Icon(Icons.lock) : IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => sP = null)))
        else Expanded(child: Column(children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 15), child: TextField(decoration: const InputDecoration(hintText: "Search Party..."), onChanged: (v) => setState(() => sPT = v))),
          Expanded(child: ListView(children: ph.parties.where((p) => p.name.toLowerCase().contains(sPT.toLowerCase())).map((p) => ListTile(title: Text(p.name), onTap: () => setState(() => sP = p))).toList()))
        ])),
        if (sP != null) Padding(padding: const EdgeInsets.all(20), child: ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), backgroundColor: widget.isReadOnly ? Colors.purple : Colors.green), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => BillingView(party: sP!, billNo: bN, billDate: bD, mode: pM, existingItems: widget.existingSale?.items, modifySaleId: widget.existingSale?.id, isReadOnly: widget.isReadOnly))), child: Text(widget.isReadOnly ? "VIEW ITEMS" : "PROCEED", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))
      ]),
    );
  }
}
