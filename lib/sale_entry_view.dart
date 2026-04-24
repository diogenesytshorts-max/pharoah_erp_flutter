// FILE: lib/sale_entry_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'pharoah_smart_logic.dart'; // NAYA: Logic Master Connection
import 'billing_view.dart';
import 'party_master.dart';
import 'pharoah_date_controller.dart'; 
import 'package:intl/intl.dart';

class SaleEntryView extends StatefulWidget {
  final Sale? existingSale;
  final bool isReadOnly; 

  const SaleEntryView({super.key, this.existingSale, this.isReadOnly = false});

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

  void _initSession() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ph = Provider.of<PharoahManager>(context, listen: false);
      
      if (widget.existingSale != null) {
        // CASE: Modifying existing bill
        setState(() {
          selectedDate = widget.existingSale!.date;
          paymentMode = widget.existingSale!.paymentMode;
          billNoC.text = widget.existingSale!.billNo;
          selectedParty = ph.parties.firstWhere(
            (p) => p.name == widget.existingSale!.partyName, 
            orElse: () => Party(id: '0', name: widget.existingSale!.partyName)
          );
        });
      } else {
        // CASE: New Bill Generation
        if (ph.activeCompany != null) {
          // NAYA: Smart Logic se Company-Specific number mangna
          String nextNo = await PharoahSmartLogic.getNextSaleNumber(ph.sales, ph.activeCompany!.id);
          setState(() { 
            billNoC.text = nextNo;
            selectedDate = PharoahDateController.getInitialBillDate(ph.currentFY);
          });
        }
      }
    });
  }

  Future<void> _handleQuickAddParty() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (c) => const PartyMasterView(isSelectionMode: true)),
    );
    if (result != null && result is Party) {
      setState(() { selectedParty = result; });
    }
  }

  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: Text(widget.isReadOnly ? "View Bill (Read Only)" : (widget.existingSale == null ? "New Sale" : "Modify Sale")), 
        backgroundColor: widget.isReadOnly ? Colors.purple.shade700 : Colors.blue.shade900, 
        foregroundColor: Colors.white
      ),
      body: IgnorePointer(
        ignoring: widget.isReadOnly,
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(20), 
            color: Colors.white, 
            child: Row(children: [
              // BILL NO - Auto-filled from Smart Logic
              Expanded(child: TextField(
                controller: billNoC, 
                decoration: const InputDecoration(labelText: "BILL NO", border: OutlineInputBorder(), filled: true, fillColor: Color(0xFFF5F5F5))
              )),
              const SizedBox(width: 15),
              Expanded(child: InkWell(
                onTap: () async { 
                  DateTime? p = await PharoahDateController.pickDate(
                    context: context, 
                    currentFY: ph.currentFY, 
                    initialDate: selectedDate
                  ); 
                  if(p != null) setState(() => selectedDate = p); 
                }, 
                child: Container(
                  padding: const EdgeInsets.all(12), 
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(5)), 
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(DateFormat('dd/MM/yyyy').format(selectedDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Icon(Icons.calendar_month, size: 18, color: Colors.indigo),
                  ])
                )
              )),
            ]),
          ),
          
          Padding(
            padding: const EdgeInsets.all(15), 
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'CASH', label: Text('CASH'), icon: Icon(Icons.money)), 
                ButtonSegment(value: 'CREDIT', label: Text('CREDIT'), icon: Icon(Icons.credit_card))
              ], 
              selected: {paymentMode}, 
              onSelectionChanged: (v) => setState(() => paymentMode = v.first)
            )
          ),

          Expanded(child: selectedParty != null ? _buildPartyCard() : _buildPartyList(ph)),
          
          if(selectedParty != null) Padding(
            padding: const EdgeInsets.all(20), 
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 60), 
                backgroundColor: widget.isReadOnly ? Colors.purple : Colors.blue.shade700,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
              ),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => BillingView(
                party: selectedParty!, 
                billNo: billNoC.text, 
                billDate: selectedDate, 
                mode: paymentMode, 
                existingItems: widget.existingSale?.items, 
                modifySaleId: widget.existingSale?.id,
                isReadOnly: widget.isReadOnly,
              ))),
              child: Text(widget.isReadOnly ? "VIEW ITEMS LIST" : "PROCEED TO BILLING", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            )
          )
        ]),
      ),
    );
  }

  Widget _buildPartyCard() => Card(
    elevation: 4, margin: const EdgeInsets.all(15), 
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.blue.shade100, width: 1)),
    child: ListTile(
      contentPadding: const EdgeInsets.all(15),
      leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.person, color: Colors.white)),
      title: Text(selectedParty!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), 
      subtitle: Text("${selectedParty!.city} | GST: ${selectedParty!.gst}"), 
      trailing: widget.isReadOnly ? null : IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => setState(() => selectedParty = null))
    )
  );
  
  Widget _buildPartyList(PharoahManager ph) => Column(children: [
    Padding(padding: const EdgeInsets.all(15), child: Row(children: [
      Expanded(child: TextField(decoration: InputDecoration(hintText: "Search Party...", prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))), onChanged: (v) => setState(() => searchQuery = v))),
      const SizedBox(width: 10),
      IconButton.filled(onPressed: _handleQuickAddParty, icon: const Icon(Icons.person_add_alt_1), style: IconButton.styleFrom(backgroundColor: Colors.blue.shade900, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
    ])),
    Expanded(child: ListView(children: ph.parties.where((p) => p.name.toLowerCase().contains(searchQuery.toLowerCase())).map((p) => ListTile(title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(p.city), onTap: () => setState(() => selectedParty = p))).toList()))
  ]);
}
