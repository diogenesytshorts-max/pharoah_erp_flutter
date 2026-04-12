import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'sale_bill_number.dart';
import 'billing_view.dart';
import 'app_date_logic.dart'; // Naya Date Logic Import

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
    // Screen load hote hi fresh calculation shuru hogi
    _initializeEntrySession();
  }

  /// Har naye session (New Sale) ke liye date aur bill number set karna
  void _initializeEntrySession() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ph = Provider.of<PharoahManager>(context, listen: false);
      
      setState(() {
        if (widget.existingSale != null) { 
          // Agar bill modify kar rahe hain toh wahi purani details rahegi
          selectedBillDate = widget.existingSale!.date; 
          paymentMode = widget.existingSale!.paymentMode; 
          billNoController.text = widget.existingSale!.billNo; 
        } else {
          // --- SMART DYNAMIC DATE LOGIC ---
          // 1. Check karega ki Today FY ke andar hai ya nahi
          // 2. Agar late hai toh 31st March uthayega
          selectedBillDate = AppDateLogic.getSmartDate(ph.currentFY);
          
          // Naya Bill Number load karein
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a party first!"), backgroundColor: Colors.red),
      );
      return;
    }
    
    // Final Date Validation before moving to billing
    if (!AppDateLogic.isValidInFY(selectedBillDate, ph.currentFY)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selected date is not valid for this Financial Year!"), backgroundColor: Colors.red),
      );
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
    
    // Auto-select party for existing sales
    if (widget.existingSale != null && selectedParty == null) { 
      selectedParty = ph.parties.firstWhere((p) => p.name == widget.existingSale!.partyName, orElse: () => ph.parties[0]); 
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: Text(widget.isReadOnly ? "View Invoice" : "New Sale Entry"), 
        backgroundColor: Colors.blue.shade800, 
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // --- HEADER SECTION: BILL DETAILS ---
          Container(
            padding: const EdgeInsets.all(20), 
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)]
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Invoice No Field
                    Expanded(
                      child: TextField(
                        controller: billNoController, 
                        enabled: !widget.isReadOnly, 
                        decoration: const InputDecoration(labelText: "INVOICE NO", border: OutlineInputBorder(), prefixIcon: Icon(Icons.numbers))
                      )
                    ),
                    const SizedBox(width: 15),
                    // Dynamic Date Picker Field
                    Expanded(
                      child: InkWell(
                        onTap: widget.isReadOnly ? null : () async { 
                          DateTime? p = await showDatePicker(
                            context: context, 
                            initialDate: selectedBillDate, 
                            // Calendar sirf us Financial Year ki range dikhayega
                            firstDate: ph.fyStartDate, 
                            lastDate: ph.fyEndDate,
                            helpText: "SELECT BILL DATE (${ph.currentFY})",
                          ); 
                          if (p != null) setState(() => selectedBillDate = p); 
                        }, 
                        child: Container(
                          padding: const EdgeInsets.all(12), 
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(5)), 
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                            children: [
                              Text(AppDateLogic.format(selectedBillDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), 
                              const Icon(Icons.calendar_month, size: 18, color: Colors.blue)
                            ]
                          )
                        )
                      )
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                // Payment Mode Toggle
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'CASH', label: Text('CASH'), icon: Icon(Icons.money)), 
                    ButtonSegment(value: 'CREDIT', label: Text('CREDIT'), icon: Icon(Icons.credit_card))
                  ], 
                  selected: {paymentMode}, 
                  onSelectionChanged: (v) => setState(() => paymentMode = v.first),
                )
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.all(20), 
            child: Align(alignment: Alignment.centerLeft, child: Text("SELECT CUSTOMER / PARTY", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1)))
          ),

          // --- PARTY SELECTION SECTION ---
          if (selectedParty != null) 
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.person, color: Colors.white)),
                  title: Text(selectedParty!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${selectedParty!.city} | GST: ${selectedParty!.gst}"),
                  trailing: widget.isReadOnly ? null : IconButton(icon: const Icon(Icons.change_circle, color: Colors.red), onPressed: () => setState(() => selectedParty = null)),
                ),
              ),
            )
          else 
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: "Search Party Name...", 
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true, fillColor: Colors.white
                      ),
                      onChanged: (v) => setState(() => partySearchQuery = v),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView(
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
                  ),
                ],
              )
            ),

          // --- BOTTOM ACTION BUTTON ---
          if (selectedParty != null && !widget.isReadOnly) 
            Padding(
              padding: const EdgeInsets.all(20), 
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 60), 
                  backgroundColor: Colors.green.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ), 
                onPressed: () => _validateAndProceed(ph), 
                child: const Text("PROCEED TO BILLING", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))
              )
            )
        ],
      ),
    );
  }
}
