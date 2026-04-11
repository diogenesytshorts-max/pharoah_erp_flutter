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
  // --- STATE VARIABLES ---
  DateTime selectedBillDate = DateTime.now();
  String paymentMode = "CASH"; 
  Party? selectedParty; 
  String partySearchQuery = "";
  final billNoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    
    // Logic inside addPostFrameCallback to ensure Provider is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ph = Provider.of<PharoahManager>(context, listen: false);
      
      setState(() {
        // 1. AUTO DATE PICKUP LOGIC
        DateTime today = DateTime.now();
        // Check if today falls within current Financial Year boundaries
        if (today.isAfter(ph.fyStartDate.subtract(const Duration(days: 1))) && 
            today.isBefore(ph.fyEndDate.add(const Duration(days: 1)))) {
          selectedBillDate = today;
        } else {
          // If today is outside FY, default to first day of FY (April 1st)
          selectedBillDate = ph.fyStartDate;
        }

        // 2. LOAD EXISTING SALE DATA (IF EDIT MODE)
        if (widget.existingSale != null) { 
          selectedBillDate = widget.existingSale!.date; 
          paymentMode = widget.existingSale!.paymentMode; 
          billNoController.text = widget.existingSale!.billNo; 
        } else {
          // 3. AUTO GENERATE NEXT BILL NUMBER
          _loadAutoBillNumber();
        }
      });
    });
  }

  // Fetch next bill number from logic class
  Future<void> _loadAutoBillNumber() async {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    String nextNo = await SaleBillNumber.getNextNumber(ph.sales); 
    setState(() { billNoController.text = nextNo; }); 
  }

  // Final check before opening the item entry screen
  void _validateAndProceed(PharoahManager ph) {
    if (selectedParty == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a party first!")));
      return;
    }
    
    // STRICT BOUNDARY CHECK: Ensure date hasn't been manually manipulated outside FY
    if (selectedBillDate.isBefore(ph.fyStartDate) || selectedBillDate.isAfter(ph.fyEndDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Selected date must be between ${DateFormat('dd/MM/yy').format(ph.fyStartDate)} and ${DateFormat('dd/MM/yy').format(ph.fyEndDate)}"))
      );
      return;
    }

    // Move to Billing Screen
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
    
    // Auto-match party if we are viewing/editing an existing sale
    if (widget.existingSale != null && selectedParty == null) { 
      selectedParty = ph.parties.firstWhere(
        (p) => p.name == widget.existingSale!.partyName, 
        orElse: () => ph.parties.firstWhere((p) => p.name == "CASH")
      ); 
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: Text(widget.isReadOnly ? "View Invoice Details" : "New Sale Entry"), 
        backgroundColor: Colors.blue.shade800, 
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // --- TOP SECTION: BILL HEADER ---
          Container(
            padding: const EdgeInsets.all(20), 
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Invoice Number Field
                    Expanded(
                      child: TextField(
                        controller: billNoController, 
                        enabled: !widget.isReadOnly, 
                        decoration: const InputDecoration(labelText: "INVOICE NO", border: OutlineInputBorder(), filled: true, fillColor: Color(0xFFF9F9F9))
                      )
                    ),
                    const SizedBox(width: 15),
                    // Date Picker Trigger
                    Expanded(
                      child: InkWell(
                        onTap: widget.isReadOnly ? null : () async { 
                          DateTime? p = await showDatePicker(
                            context: context, 
                            initialDate: selectedBillDate, 
                            firstDate: ph.fyStartDate, // Fixed April 1 boundary
                            lastDate: ph.fyEndDate     // Fixed March 31 boundary
                          ); 
                          if (p != null) setState(() => selectedBillDate = p); 
                        }, 
                        child: Container(
                          padding: const EdgeInsets.all(12), 
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(5)), 
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(DateFormat('dd/MM/yyyy').format(selectedBillDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                              const Icon(Icons.calendar_month, size: 18, color: Colors.blue),
                            ],
                          )
                        )
                      )
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                // Payment Mode Switcher
                AbsorbPointer(
                  absorbing: widget.isReadOnly,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'CASH', label: Text('CASH'), icon: Icon(Icons.money)), 
                      ButtonSegment(value: 'CREDIT', label: Text('CREDIT'), icon: Icon(Icons.credit_score))
                    ], 
                    selected: {paymentMode}, 
                    onSelectionChanged: (v) => setState(() => paymentMode = v.first),
                  ),
                )
              ],
            ),
          ),

          // --- MIDDLE SECTION: PARTY SELECTION ---
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Align(alignment: Alignment.centerLeft, child: Text("SELECT CUSTOMER / PARTY", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1))),
          ),

          if (selectedParty != null) 
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Colors.blue, width: 1)), 
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.person, color: Colors.white)),
                  title: Text(selectedParty!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), 
                  subtitle: Text("${selectedParty!.city} | GST: ${selectedParty!.gst}"), 
                  trailing: (widget.isReadOnly || widget.existingSale != null) 
                    ? const Icon(Icons.lock_outline, color: Colors.grey) 
                    : IconButton(icon: const Icon(Icons.change_circle, color: Colors.red), onPressed: () => setState(() => selectedParty = null))
                ),
              ),
            )
          else 
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), 
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: "Search Party by Name...", 
                        prefixIcon: const Icon(Icons.search, color: Colors.blue), 
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.white
                      ), 
                      onChanged: (v) => setState(() => partySearchQuery = v)
                    )
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      children: ph.parties
                          .where((p) => p.name.toLowerCase().contains(partySearchQuery.toLowerCase()))
                          .map((p) => ListTile(
                            leading: const Icon(Icons.person_outline),
                            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)), 
                            subtitle: Text(p.city), 
                            onTap: () => setState(() => selectedParty = p)
                          ))
                          .toList()
                    ),
                  )
                ],
              )
            ),

          // --- BOTTOM ACTION BUTTON ---
          if (selectedParty != null) 
            Padding(
              padding: const EdgeInsets.all(20), 
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 60), 
                  backgroundColor: Colors.green.shade700,
                  elevation: 5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ), 
                onPressed: () => _validateAndProceed(ph), 
                child: const Text("PROCEED TO ITEM ENTRY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))
              )
            ),
        ],
      ),
    );
  }
}
