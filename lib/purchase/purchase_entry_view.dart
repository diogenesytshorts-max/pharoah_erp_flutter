import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import 'purchase_billing_view.dart';
import '../app_date_logic.dart'; // Naya Date Logic Import

class PurchaseEntryView extends StatefulWidget {
  final Purchase? existingPurchase;
  const PurchaseEntryView({super.key, this.existingPurchase});

  @override State<PurchaseEntryView> createState() => _PurchaseEntryViewState();
}

class _PurchaseEntryViewState extends State<PurchaseEntryView> {
  // --- CONTROLLERS ---
  final supplierBillNoC = TextEditingController(); 
  final internalEntryNoC = TextEditingController();
  
  // --- STATE ---
  DateTime selectedBillDate = DateTime.now(); 
  String paymentMode = "CREDIT"; 
  Party? selectedDistributor; 
  String distSearchQuery = "";

  @override
  void initState() {
    super.initState();
    // Screen khulte hi Session data initialize karein
    _initializePurchaseSession();
  }

  /// Session Initialization: Date aur Entry Number set karna
  void _initializePurchaseSession() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ph = Provider.of<PharoahManager>(context, listen: false);
      
      setState(() {
        if (widget.existingPurchase != null) {
          // Modify Mode: Purana data load karein
          supplierBillNoC.text = widget.existingPurchase!.billNo;
          internalEntryNoC.text = widget.existingPurchase!.internalNo;
          selectedBillDate = widget.existingPurchase!.date;
          paymentMode = widget.existingPurchase!.paymentMode;
          selectedDistributor = ph.parties.firstWhere(
            (p) => p.name == widget.existingPurchase!.distributorName, 
            orElse: () => ph.parties[0]
          );
        } else {
          // --- SMART DYNAMIC DATE (Purchase Version) ---
          // Agar aaj ki date FY mein hai toh 'Today', varna 'Late Date' (31st March)
          selectedBillDate = AppDateLogic.getSmartDate(ph.currentFY);
          
          // Next Internal Purchase ID load karein
          _loadInternalNo();
        }
      });
    });
  }

  /// Internal Tracking No (PUR-X) generate karna
  Future<void> _loadInternalNo() async {
    final prefs = await SharedPreferences.getInstance();
    int lastId = prefs.getInt('lastPurID') ?? 0;
    setState(() { 
      internalEntryNoC.text = "PUR-${lastId + 1}"; 
    });
  }

  /// Entry validation aur aage badhne ka logic
  void _validateAndProceed(PharoahManager ph) {
    if (selectedDistributor == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a Supplier!"), backgroundColor: Colors.red));
      return;
    }
    if (supplierBillNoC.text.trim().isEmpty) { 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Supplier Bill Number is mandatory!"), backgroundColor: Colors.red)); 
      return; 
    }
    
    // Date Range Validation (Security Check)
    if (!AppDateLogic.isValidInFY(selectedBillDate, ph.currentFY)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bill Date must be within the selected Financial Year!"), backgroundColor: Colors.red));
      return;
    }

    Navigator.push(
      context, 
      MaterialPageRoute(builder: (c) => PurchaseBillingView(
        distributor: selectedDistributor!, 
        internalNo: internalEntryNoC.text, 
        distBillNo: supplierBillNoC.text.trim(), 
        billDate: selectedBillDate, 
        mode: paymentMode, 
        existingItems: widget.existingPurchase?.items, 
        modifyPurchaseId: widget.existingPurchase?.id
      ))
    );
  }

  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: Text(widget.existingPurchase != null ? "Modify Purchase Record" : "New Purchase Entry"), 
        backgroundColor: Colors.orange.shade800, 
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // --- HEADER: ENTRY DETAILS ---
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
                    Expanded(child: TextField(controller: internalEntryNoC, enabled: false, decoration: const InputDecoration(labelText: "INTERNAL NO", border: OutlineInputBorder(), filled: true, fillColor: Color(0xFFF0F0F0)))),
                    const SizedBox(width: 15),
                    Expanded(child: TextField(controller: supplierBillNoC, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: "SUPPLIER BILL NO", border: OutlineInputBorder(), prefixIcon: Icon(Icons.receipt)))),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    // Dynamic Date Picker
                    Expanded(
                      child: InkWell(
                        onTap: () async { 
                          DateTime? p = await showDatePicker(
                            context: context, 
                            initialDate: selectedBillDate, 
                            firstDate: ph.fyStartDate, 
                            lastDate: ph.fyEndDate,
                            helpText: "PURCHASE DATE (${ph.currentFY})",
                          ); 
                          if (p != null) setState(() => selectedBillDate = p); 
                        }, 
                        child: Container(
                          padding: const EdgeInsets.all(12), 
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(5)), 
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                            children: [
                              Text(AppDateLogic.format(selectedBillDate), style: const TextStyle(fontWeight: FontWeight.bold)), 
                              const Icon(Icons.calendar_month, color: Colors.orange, size: 18)
                            ]
                          )
                        )
                      )
                    ),
                    const SizedBox(width: 15),
                    // Payment Mode Toggle
                    Expanded(
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'CASH', label: Text('CASH')), 
                          ButtonSegment(value: 'CREDIT', label: Text('CREDIT'))
                        ], 
                        selected: {paymentMode}, 
                        onSelectionChanged: (v) => setState(() => paymentMode = v.first),
                      )
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 10), 
            child: Align(alignment: Alignment.centerLeft, child: Text("SELECT SUPPLIER / DISTRIBUTOR", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1)))
          ),

          // --- SUPPLIER SELECTION ---
          if (selectedDistributor != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.business, color: Colors.white)),
                  title: Text(selectedDistributor!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${selectedDistributor!.city} | GST: ${selectedDistributor!.gst}"),
                  trailing: IconButton(icon: const Icon(Icons.change_circle, color: Colors.red), onPressed: () => setState(() => selectedDistributor = null)),
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
                        hintText: "Search Supplier...", 
                        prefixIcon: const Icon(Icons.search, color: Colors.orange),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true, fillColor: Colors.white
                      ),
                      onChanged: (v) => setState(() => distSearchQuery = v),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView(
                      children: ph.parties
                          .where((p) => p.name.toLowerCase().contains(distSearchQuery.toLowerCase()))
                          .map((p) => ListTile(
                                leading: const Icon(Icons.store_outlined),
                                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)), 
                                subtitle: Text(p.city), 
                                onTap: () => setState(() => selectedDistributor = p)
                              ))
                          .toList()
                    ),
                  ),
                ],
              )
            ),

          // --- FINAL PROCEED BUTTON ---
          if (selectedDistributor != null) 
            Padding(
              padding: const EdgeInsets.all(20), 
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 60), 
                  backgroundColor: Colors.orange.shade800,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 5
                ), 
                onPressed: () => _validateAndProceed(ph), 
                child: const Text("PROCEED TO ITEM ENTRY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))
              )
            ),
        ],
      ),
    );
  }
}
