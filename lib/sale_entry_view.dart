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
  DateTime fD = DateTime(2025, 4, 1); DateTime lD = DateTime(2026, 3, 31);
  final bNoC = TextEditingController();

  @override void initState() {
    super.initState();
    _loadFY();
    if (widget.existingSale != null) { bN = widget.existingSale!.billNo; bD = widget.existingSale!.date; pM = widget.existingSale!.paymentMode; bNoC.text = bN; } 
    else { _loadNum(); }
  }

  _loadFY() async {
    final p = await SharedPreferences.getInstance();
    String fy = p.getString('fy') ?? "2025-26";
    int sY = int.parse(fy.split('-')[0]); if (sY < 2000) sY += 2000;
    setState(() { fD = DateTime(sY, 4, 1); lD = DateTime(sY + 1, 3, 31); if (bD.isBefore(fD) || bD.isAfter(lD)) bD = fD; });
  }

  _loadNum() async { bN = await SaleBillNumber.getNextNumber(); setState(() { bNoC.text = bN; }); }

  void _validate(PharoahManager ph) {
    if (widget.isReadOnly) { _go(); return; }
    bool isNew = widget.existingSale == null;
    if (isNew || bNoC.text != widget.existingSale!.billNo) {
      if (ph.sales.any((s) => s.billNo == bNoC.text)) {
        final party = ph.sales.firstWhere((s) => s.billNo == bNoC.text).partyName;
        showDialog(context: context, builder: (c)=>AlertDialog(title: const Text("Duplicate Bill!"), content: Text("Bill ${bNoC.text} already issued to $party."), actions: [TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("OK"))]));
        return;
      }
    }
    if (isNew && bNoC.text != bN) {
      showDialog(context: context, builder: (c)=>AlertDialog(title: const Text("Change Series?"), content: Text("Start future bills from ${bNoC.text}?"), actions: [
        TextButton(onPressed: (){ _go(); Navigator.pop(c); }, child: const Text("Only this bill")),
        TextButton(onPressed: () async { await SaleBillNumber.updateSeriesFromFull(bNoC.text); _go(); Navigator.pop(c); }, child: const Text("Yes, Change Series"))
      ]));
    } else { _go(); }
  }

  void _go() => Navigator.push(context, MaterialPageRoute(builder: (c) => BillingView(party: sP!, billNo: bNoC.text, billDate: bD, mode: pM, existingItems: widget.existingSale?.items, modifySaleId: widget.existingSale?.id, isReadOnly: widget.isReadOnly)));

  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    if (widget.existingSale != null && sP == null) { sP = ph.parties.firstWhere((p) => p.name == widget.existingSale!.partyName, orElse: () => ph.parties[0]); }
    return Scaffold(
      appBar: AppBar(title: Text(widget.isReadOnly ? "View Bill" : (widget.existingSale == null ? "New Sale" : "Modify Sale"))),
      body: Column(children: [
        Container(padding: const EdgeInsets.all(15), color: widget.isReadOnly ? Colors.grey[200] : Colors.blue[50], child: Column(children: [
          Row(children: [
            Expanded(child: TextField(controller: bNoC, enabled: !widget.isReadOnly, decoration: const InputDecoration(labelText: "BILL NO"))),
            Expanded(child: InkWell(onTap: widget.isReadOnly ? null : () async { DateTime? p = await showDatePicker(context: context, initialDate: bD, firstDate: fD, lastDate: lD); if (p != null) setState(() => bD = p); }, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [const Text("DATE", style: TextStyle(fontSize: 10)), Text(DateFormat('dd/MM/yyyy').format(bD), style: const TextStyle(fontWeight: FontWeight.bold)) ])))
          ]),
          const SizedBox(height: 15),
          AbsorbPointer(absorbing: widget.isReadOnly, child: SegmentedButton<String>(segments: const [ButtonSegment(value: 'CASH', label: Text('CASH')), ButtonSegment(value: 'CREDIT', label: Text('CREDIT'))], selected: {pM}, onSelectionChanged: (v) => setState(() => pM = v.first)))
        ])),
        if (sP != null) ListTile(leading: const Icon(Icons.person), title: Text(sP!.name, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(sP!.phone), trailing: widget.isReadOnly || widget.existingSale != null ? const Icon(Icons.lock) : IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => sP = null)))
        else Expanded(child: Column(children: [
          Padding(padding: const EdgeInsets.all(15), child: TextField(decoration: const InputDecoration(hintText: "Search Party..."), onChanged: (v) => setState(() => sPT = v))),
          Expanded(child: ListView(children: ph.parties.where((p) => p.name.toLowerCase().contains(sPT.toLowerCase())).map((p) => ListTile(title: Text(p.name), onTap: () => setState(() => sP = p))).toList()))
        ])),
        if (sP != null) Padding(padding: const EdgeInsets.all(20), child: ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), backgroundColor: widget.isReadOnly ? Colors.purple : Colors.green), onPressed: () => _validate(ph), child: Text(widget.isReadOnly ? "VIEW ITEMS" : "PROCEED", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))
      ]),
    );
  }
}
