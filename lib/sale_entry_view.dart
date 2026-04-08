import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'sale_bill_number.dart';
import 'billing_view.dart';

class SaleEntryView extends StatefulWidget {
  final Sale? existingSale;
  final bool isReadOnly;
  const SaleEntryView({super.key, this.existingSale, this.isReadOnly = false});

  @override
  State<SaleEntryView> createState() => _SaleEntryViewState();
}

class _SaleEntryViewState extends State<SaleEntryView> {
  String billNo = "";
  DateTime billDate = DateTime.now();
  String paymentMode = "CASH";
  Party? selectedParty;
  String searchParty = "";

  @override
  void initState() {
    super.initState();
    if (widget.existingSale != null) {
      billNo = widget.existingSale!.billNo;
      billDate = widget.existingSale!.date;
      paymentMode = widget.existingSale!.paymentMode;
    } else {
      _loadNextBillNo();
    }
  }

  void _loadNextBillNo() async {
    String next = await SaleBillNumber.getNextNumber();
    setState(() => billNo = next);
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    if (widget.existingSale != null && selectedParty == null) {
      selectedParty = ph.parties.firstWhere((p) => p.name == widget.existingSale!.partyName, orElse: () => ph.parties[0]);
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.isReadOnly ? "View Bill" : (widget.existingSale == null ? "New Sale" : "Modify Sale"))),
      body: Column(children: [
        Container(
          padding: const EdgeInsets.all(15),
          color: widget.isReadOnly ? Colors.grey[200] : Colors.blue[50],
          child: Column(children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("BILL NO", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                Text(billNo, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: widget.isReadOnly ? Colors.grey : Colors.blue)),
              ])),
              Expanded(child: InkWell(
                onTap: widget.isReadOnly ? null : () async {
                  DateTime? p = await showDatePicker(context: context, initialDate: billDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (p != null) setState(() => billDate = p);
                },
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text("DATE", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  Text(DateFormat('dd/MM/yyyy').format(billDate), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ]),
              ))
            ]),
            const SizedBox(height: 15),
            AbsorbPointer(
              absorbing: widget.isReadOnly,
              child: SegmentedButton<String>(
                segments: const [ButtonSegment(value: 'CASH', label: Text('CASH')), ButtonSegment(value: 'CREDIT', label: Text('CREDIT'))],
                selected: {paymentMode},
                onSelectionChanged: (v) => setState(() => paymentMode = v.first),
              ),
            )
          ]),
        ),
        const Padding(padding: EdgeInsets.all(15), child: Align(alignment: Alignment.centerLeft, child: Text("PARTY DETAILS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)))),
        if (selectedParty != null)
          ListTile(
            leading: const Icon(Icons.person, color: Colors.blue),
            title: Text(selectedParty!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(selectedParty!.phone),
            trailing: widget.isReadOnly || widget.existingSale != null ? const Icon(Icons.lock, size: 16) : IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => selectedParty = null)),
          )
        else
          Expanded(child: Column(children: [
            Padding(padding: const EdgeInsets.symmetric(horizontal: 15), child: TextField(decoration: const InputDecoration(hintText: "Search Party..."), onChanged: (v) => setState(() => searchParty = v))),
            Expanded(child: ListView(children: ph.parties.where((p) => p.name.toLowerCase().contains(searchParty.toLowerCase())).map((p) => ListTile(title: Text(p.name), onTap: () => setState(() => selectedParty = p))).toList()))
          ])),
        if (selectedParty != null)
          Padding(padding: const EdgeInsets.all(20), child: ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), backgroundColor: widget.isReadOnly ? Colors.purple : Colors.green),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => BillingView(
              party: selectedParty!, billNo: billNo, billDate: billDate, mode: paymentMode,
              existingItems: widget.existingSale?.items, 
              modifySaleId: widget.existingSale?.id,
              isReadOnly: widget.isReadOnly,
            ))),
            child: Text(widget.isReadOnly ? "VIEW ITEMS" : "PROCEED TO BILLING", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )),
      ]),
    );
  }
}
// (Update validate function with Alert for Invoice/Date change)
