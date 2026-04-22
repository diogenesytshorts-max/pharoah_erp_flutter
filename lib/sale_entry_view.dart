import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'sale_bill_number.dart';
import 'billing_view.dart';
import 'package:intl/intl.dart';

class SaleEntryView extends StatefulWidget {
  final Sale? existingSale;
  const SaleEntryView({super.key, this.existingSale});

  @override State<SaleEntryView> createState() => _SaleEntryViewState();
}

class _SaleEntryViewState extends State<SaleEntryView> {
  DateTime selectedDate = DateTime.now();
  String paymentMode = "CASH"; 
  Party? selectedParty; 
  String searchQuery = "";
  final billNoC = TextEditingController();

  @override void initState() {
    super.initState();
    _initSession();
  }

  // --- AUTO BILL NUMBER LOGIC ---
  void _initSession() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ph = Provider.of<PharoahManager>(context, listen: false);
      
      if (widget.existingSale != null) {
        setState(() {
          selectedDate = widget.existingSale!.date;
          paymentMode = widget.existingSale!.paymentMode;
          billNoC.text = widget.existingSale!.billNo;
          selectedParty = ph.parties.firstWhere((p) => p.name == widget.existingSale!.partyName, orElse: () => ph.parties[0]);
        });
      } else {
        // --- YAHIN HAI ASLI LOGIC ---
        String nextNo = await SaleBillNumber.getNextNumber(ph.sales);
        setState(() { billNoC.text = nextNo; });
      }
    });
  }

  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(title: Text(widget.existingSale == null ? "New Sale" : "Modify Sale"), backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white),
      body: Column(children: [
        // Header
        Container(padding: const EdgeInsets.all(20), color: Colors.white, child: Row(children: [
          Expanded(child: TextField(controller: billNoC, decoration: const InputDecoration(labelText: "BILL NO", border: OutlineInputBorder()))),
          const SizedBox(width: 15),
          Expanded(child: InkWell(onTap: () async { DateTime? p = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2100)); if(p!=null) setState(() => selectedDate = p); }, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(5)), child: Text(DateFormat('dd/MM/yy').format(selectedDate), style: const TextStyle(fontWeight: FontWeight.bold))))),
        ])),
        // Mode & Party
        Padding(padding: const EdgeInsets.all(15), child: SegmentedButton<String>(segments: const [ButtonSegment(value: 'CASH', label: Text('CASH')), ButtonSegment(value: 'CREDIT', label: Text('CREDIT'))], selected: {paymentMode}, onSelectionChanged: (v) => setState(() => paymentMode = v.first))),
        
        Expanded(child: selectedParty != null ? _buildPartyCard() : _buildPartyList(ph)),
        
        if(selectedParty != null) Padding(padding: const EdgeInsets.all(20), child: ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60), backgroundColor: Colors.blue.shade700),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => BillingView(party: selectedParty!, billNo: billNoC.text, billDate: selectedDate, mode: paymentMode, existingItems: widget.existingSale?.items, modifySaleId: widget.existingSale?.id))),
          child: const Text("PROCEED TO BILLING", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
        ))
      ]),
    );
  }

  Widget _buildPartyCard() => Card(margin: const EdgeInsets.all(15), child: ListTile(title: Text(selectedParty!.name, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(selectedParty!.city), trailing: IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => setState(() => selectedParty = null))));
  
  Widget _buildPartyList(PharoahManager ph) => Column(children: [
    Padding(padding: const EdgeInsets.all(15), child: TextField(decoration: const InputDecoration(hintText: "Search Party...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()), onChanged: (v) => setState(() => searchQuery = v))),
    Expanded(child: ListView(children: ph.parties.where((p) => p.name.toLowerCase().contains(searchQuery.toLowerCase())).map((p) => ListTile(title: Text(p.name), subtitle: Text(p.city), onTap: () => setState(() => selectedParty = p))).toList()))
  ]);
}
