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

  @override State<SaleEntryView> createState() => _SaleEntryViewState();
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
    final ph = Provider.of<PharoahManager>(context, listen: false);
    
    // Default Date Adjustment: If today is outside the selected FY range
    if (selectedBillDate.isBefore(ph.fyStartDate) || selectedBillDate.isAfter(ph.fyEndDate)) {
      selectedBillDate = ph.fyStartDate;
    }

    if (widget.existingSale != null) { 
      selectedBillDate = widget.existingSale!.date; 
      paymentMode = widget.existingSale!.paymentMode; 
      billNoController.text = widget.existingSale!.billNo; 
    } else {
      _loadAutoBillNumber();
    }
  }

  Future<void> _loadAutoBillNumber() async {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    String nextNo = await SaleBillNumber.getNextNumber(ph.sales); 
    setState(() { billNoController.text = nextNo; }); 
  }

  void _validateAndProceed(PharoahManager ph) {
    if (selectedParty == null) return;
    
    // Strict Verification: Ensure date is within FY boundaries
    if (selectedBillDate.isBefore(ph.fyStartDate) || selectedBillDate.isAfter(ph.fyEndDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Selected date must be between ${DateFormat('dd/MM/yy').format(ph.fyStartDate)} and ${DateFormat('dd/MM/yy').format(ph.fyEndDate)}"))
      );
      return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (c) => BillingView(
      party: selectedParty!, billNo: billNoController.text.trim(), billDate: selectedBillDate, 
      mode: paymentMode, existingItems: widget.existingSale?.items, modifySaleId: widget.existingSale?.id, isReadOnly: widget.isReadOnly
    )));
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
            padding: const EdgeInsets.all(20), color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: TextField(controller: billNoController, enabled: !widget.isReadOnly, decoration: const InputDecoration(labelText: "INVOICE NO", border: OutlineInputBorder()))),
                    const SizedBox(width: 15),
                    Expanded(child: InkWell(
                      onTap: widget.isReadOnly ? null : () async { 
                        DateTime? p = await showDatePicker(
                          context: context, 
                          initialDate: selectedBillDate, 
                          firstDate: ph.fyStartDate, // 1st April
                          lastDate: ph.fyEndDate     // 31st March
                        ); 
                        if (p != null) setState(() => selectedBillDate = p); 
                      }, 
                      child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: Colors.grey)), child: Text(DateFormat('dd/MM/yyyy').format(selectedBillDate)))
                    )),
                  ],
                ),
                const SizedBox(height: 15),
                SegmentedButton<String>(
                  segments: const [ButtonSegment(value: 'CASH', label: Text('CASH')), ButtonSegment(value: 'CREDIT', label: Text('CREDIT'))], 
                  selected: {paymentMode}, 
                  onSelectionChanged: widget.isReadOnly ? null : (v) => setState(() => paymentMode = v.first)
                )
              ],
            ),
          ),
          if (selectedParty != null) 
            Padding(padding: const EdgeInsets.all(15), child: Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Colors.blue, width: 1)), child: ListTile(leading: const Icon(Icons.person, color: Colors.blue), title: Text(selectedParty!.name, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(selectedParty!.city), trailing: (widget.isReadOnly || widget.existingSale != null) ? const Icon(Icons.lock) : IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => setState(() => selectedParty = null)))))
          else 
            Expanded(child: Column(children: [Padding(padding: const EdgeInsets.all(15), child: TextField(decoration: const InputDecoration(hintText: "Search Party Name...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()), onChanged: (v) => setState(() => partySearchQuery = v))), Expanded(child: ListView(children: ph.parties.where((p) => p.name.toLowerCase().contains(partySearchQuery.toLowerCase())).map((p) => ListTile(title: Text(p.name), subtitle: Text(p.city), onTap: () => setState(() => selectedParty = p))).toList()))])),
          if (selectedParty != null) Padding(padding: const EdgeInsets.all(20), child: ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60), backgroundColor: Colors.green.shade700), onPressed: () => _validateAndProceed(ph), child: const Text("PROCEED TO BILLING", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
        ],
      ),
    );
  }
}
