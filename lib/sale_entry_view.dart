import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'sale_bill_number.dart';
import 'billing_view.dart';
import 'app_date_logic.dart';

class SaleEntryView extends StatefulWidget {
  final Sale? existingSale; 
  final bool isReadOnly;
  const SaleEntryView({super.key, this.existingSale, this.isReadOnly = false});

  @override
  State<SaleEntryView> createState() => _SaleEntryViewState();
}

class _SaleEntryViewState extends State<SaleEntryView> {
  DateTime selectedBillDate = DateTime.now();
  String paymentMode = "CASH"; 
  Party? selectedParty; 
  String partySearchQuery = "";
  final billNoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Widgets ki loading ke baad date aur bill no set karein
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ph = Provider.of<PharoahManager>(context, listen: false);
      
      setState(() {
        if (widget.existingSale != null) { 
          selectedBillDate = widget.existingSale!.date; 
          paymentMode = widget.existingSale!.paymentMode; 
          billNoController.text = widget.existingSale!.billNo; 
        } else {
          // AUTOMATIC DATE SETTING HERE
          selectedBillDate = AppDateLogic.getSmartDate(ph.currentFY);
          _loadAutoBillNumber();
        }
      });
    });
  }

  Future<void> _loadAutoBillNumber() async {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    String nextNo = await SaleBillNumber.getNextNumber(ph.sales); 
    setState(() { billNoController.text = nextNo; }); 
  }

  void _validateAndProceed(PharoahManager ph) {
    if (selectedParty == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a party first!")));
      return;
    }
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (c) => BillingView(
          party: selectedParty!, 
          billNo: billNoController.text.trim(), 
          billDate: selectedBillDate, 
          mode: paymentMode, 
          existingItems: widget.existingSale?.items, 
          modifySaleId: widget.existingSale?.id, 
          isReadOnly: widget.isReadOnly
        )
      )
    );
  }

  @override 
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    if (widget.existingSale != null && selectedParty == null) { 
      selectedParty = ph.parties.firstWhere((p) => p.name == widget.existingSale!.partyName, orElse: () => ph.parties[0]); 
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(title: Text(widget.isReadOnly ? "View Invoice" : "New Sale Entry"), backgroundColor: Colors.blue.shade800, foregroundColor: Colors.white),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20), 
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: TextField(controller: billNoController, enabled: !widget.isReadOnly, decoration: const InputDecoration(labelText: "INVOICE NO", border: OutlineInputBorder()))),
                    const SizedBox(width: 15),
                    Expanded(
                      child: InkWell(
                        onTap: widget.isReadOnly ? null : () async { 
                          DateTime? p = await showDatePicker(context: context, initialDate: selectedBillDate, firstDate: ph.fyStartDate, lastDate: ph.fyEndDate); 
                          if (p != null) setState(() => selectedBillDate = p); 
                        }, 
                        child: Container(
                          padding: const EdgeInsets.all(12), 
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(5)), 
                          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(AppDateLogic.format(selectedBillDate), style: const TextStyle(fontWeight: FontWeight.bold)), const Icon(Icons.calendar_month, size: 18, color: Colors.blue)])
                        )
                      )
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                SegmentedButton<String>(
                  segments: const [ButtonSegment(value: 'CASH', label: Text('CASH')), ButtonSegment(value: 'CREDIT', label: Text('CREDIT'))], 
                  selected: {paymentMode}, 
                  onSelectionChanged: (v) => setState(() => paymentMode = v.first),
                )
              ],
            ),
          ),
          const Padding(padding: EdgeInsets.all(20), child: Align(alignment: Alignment.centerLeft, child: Text("SELECT CUSTOMER", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)))),
          if (selectedParty != null) 
            ListTile(tileColor: Colors.white, leading: const Icon(Icons.person, color: Colors.blue), title: Text(selectedParty!.name), subtitle: Text(selectedParty!.city), trailing: IconButton(icon: const Icon(Icons.cancel), onPressed: () => setState(() => selectedParty = null)))
          else 
            Expanded(child: ListView(children: ph.parties.where((p) => p.name.toLowerCase().contains(partySearchQuery.toLowerCase())).map((p) => ListTile(title: Text(p.name), subtitle: Text(p.city), onTap: () => setState(() => selectedParty = p))).toList())),
          if (selectedParty != null) 
            Padding(padding: const EdgeInsets.all(20), child: ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60), backgroundColor: Colors.green.shade700), onPressed: () => _validateAndProceed(ph), child: const Text("PROCEED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))
        ],
      ),
    );
  }
}
