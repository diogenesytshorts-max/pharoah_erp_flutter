// FILE: lib/returns/purchase_return_view.dart (Standard Smart Screen)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import '../logic/pharoah_numbering_engine.dart';
import '../pharoah_date_controller.dart';
import '../purchase/purchase_billing_view.dart';

class PurchaseReturnView extends StatefulWidget {
  const PurchaseReturnView({super.key});
  @override State<PurchaseReturnView> createState() => _PurchaseReturnViewState();
}

class _PurchaseReturnViewState extends State<PurchaseReturnView> {
  final returnNoC = TextEditingController();
  DateTime selectedDate = DateTime.now();
  Party? selectedSupplier;
  List<PurchaseItem> items = [];
  String returnNature = "Sellable"; // DEFAULT: Sellable Maal

  @override
  void initState() {
    super.initState();
    _initDN();
  }

  void _initDN() async {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    String nextNo = await PharoahNumberingEngine.getNextNumber(type: "PUR_RETURN", companyID: ph.activeCompany!.id, currentList: ph.purchaseReturns);
    setState(() { returnNoC.text = nextNo; selectedDate = PharoahDateController.getInitialBillDate(ph.currentFY); });
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    Color themeColor = returnNature == "Sellable" ? Colors.blue.shade900 : Colors.brown.shade800;

    return Scaffold(
      appBar: AppBar(title: const Text("Purchase Return (Debit Note)"), backgroundColor: themeColor),
      body: Column(
        children: [
          // NATURE SWITCHER (Standard ERP Method)
          Container(
            padding: const EdgeInsets.all(15), color: themeColor.withOpacity(0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Return Nature:", style: TextStyle(fontWeight: FontWeight.bold)),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Sellable', label: Text('Sellable'), icon: Icon(Icons.check_circle_outline)),
                    ButtonSegment(value: 'Breakage', label: Text('Breakage'), icon: Icon(Icons.delete_outline)),
                  ],
                  selected: {returnNature},
                  onSelectionChanged: (v) => setState(() => returnNature = v.first),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.business),
            title: Text(selectedSupplier?.name ?? "Pick Distributor"),
            onTap: () => _pickDistributor(ph),
          ),
          Expanded(child: ListView.builder(itemCount: items.length, itemBuilder: (c, i) => ListTile(title: Text(items[i].name), subtitle: Text("Qty: ${items[i].qty}")))),
          if (items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: themeColor, minimumSize: const Size(double.infinity, 50)),
                onPressed: () {
                  ph.finalizePurchaseReturn(billNo: returnNoC.text, date: selectedDate, party: selectedSupplier!, items: items, total: items.fold(0, (s, it) => s + it.total), type: returnNature);
                  Navigator.pop(context);
                },
                child: Text("FINALIZE $returnNature RETURN", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
        ],
      ),
      floatingActionButton: selectedSupplier != null ? FloatingActionButton(backgroundColor: themeColor, onPressed: () => _addItem(ph), child: const Icon(Icons.add, color: Colors.white)) : null,
    );
  }

  void _pickDistributor(PharoahManager ph) {
    showModalBottomSheet(context: context, builder: (c) => ListView(children: ph.parties.where((p) => p.group == "Sundry Creditors").map((p) => ListTile(title: Text(p.name), onTap: () { setState(() => selectedSupplier = p); Navigator.pop(c); })).toList()));
  }

  void _addItem(PharoahManager ph) {
    showModalBottomSheet(context: context, builder: (c) => ListView.builder(itemCount: ph.medicines.length, itemBuilder: (c, i) => ListTile(title: Text(ph.medicines[i].name), onTap: () {
      setState(() => items.add(PurchaseItem(id: DateTime.now().toString(), srNo: items.length+1, medicineID: ph.medicines[i].id, name: ph.medicines[i].name, packing: ph.medicines[i].packing, batch: "RET", exp: "00/00", hsn: "0000", mrp: 0, qty: 1, purchaseRate: 0, gstRate: 0, total: 0)));
      Navigator.pop(c);
    })));
  }
}
