import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  String currentBillNo = ""; 
  DateTime selectedBillDate = DateTime.now(); // Default to Current Date
  String paymentMode = "CASH"; 
  Party? selectedParty; 
  String partySearchQuery = "";
  
  // Date Limits for Financial Year
  DateTime firstDateOfFY = DateTime(2024, 1, 1); 
  DateTime lastDateOfFY = DateTime(2030, 12, 31);
  
  final billNoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFYConstraints();
    
    if (widget.existingSale != null) { 
      // Loading existing sale for View or Modify
      currentBillNo = widget.existingSale!.billNo; 
      selectedBillDate = widget.existingSale!.date; 
      paymentMode = widget.existingSale!.paymentMode; 
      billNoController.text = currentBillNo; 
    } else {
      // New Sale - Trigger smart numbering after first frame
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadAutoBillNumber());
    }
  }

  // --- SMART BILL NUMBER LOGIC ---
  Future<void> _loadAutoBillNumber() async {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    // This calls the gap-filling logic we wrote in SaleBillNumber
    currentBillNo = await SaleBillNumber.getNextNumber(ph.sales); 
    setState(() { 
      billNoController.text = currentBillNo; 
    }); 
  }

  // --- FINANCIAL YEAR LOGIC ---
  Future<void> _loadFYConstraints() async {
    final prefs = await SharedPreferences.getInstance();
    String fy = prefs.getString('fy') ?? "2025-26";
    try {
      int startYear = int.parse(fy.split('-')[0]); 
      if (startYear < 2000) startYear += 2000;
      
      setState(() { 
        firstDateOfFY = DateTime(startYear, 4, 1);
        lastDateOfFY = DateTime(startYear + 1, 3, 31);
        
        // Ensure default date is today, but if today is outside FY, 
        // fallback to start of FY for new bills.
        if (widget.existingSale == null) {
          DateTime today = DateTime.now();
          if (today.isBefore(firstDateOfFY) || today.isAfter(lastDateOfFY)) {
            selectedBillDate = firstDateOfFY;
          } else {
            selectedBillDate = today;
          }
        }
      });
    } catch (e) {
      debugPrint("FY Constraints Error: $e");
    }
  }

  // --- VALIDATION & NAVIGATION ---
  void _validateAndProceed(PharoahManager ph) {
    if (selectedParty == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a Customer/Party to proceed."))
      );
      return;
    }

    if (widget.isReadOnly) { 
      _navigateToBilling(); 
      return; 
    }

    bool isNewSale = widget.existingSale == null;
    String enteredBillNo = billNoController.text.trim();

    if (enteredBillNo.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bill Number cannot be empty.")));
       return;
    }

    // 1. Check for Duplicates (Excluding the sale we are currently modifying)
    bool isDuplicate = ph.sales.any((s) => 
      s.billNo.toUpperCase() == enteredBillNo.toUpperCase() && 
      s.id != widget.existingSale?.id
    );

    if (isDuplicate) {
      showDialog(
        context: context, 
        builder: (c) => AlertDialog(
          title: const Text("Duplicate Bill!"), 
          content: Text("An invoice with number '$enteredBillNo' already exists in your records."), 
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("OK"))]
        )
      );
      return;
    }

    // 2. Handle Manual Series Change
    if (isNewSale && enteredBillNo != currentBillNo) {
      showDialog(
        context: context, 
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          title: const Text("Change Bill Series?"), 
          content: Text("You have entered a different number ($enteredBillNo) than suggested ($currentBillNo).\n\nDo you want to update the series for future bills?"), 
          actions: [
            TextButton(
              onPressed: () { 
                Navigator.pop(c); 
                _navigateToBilling(); 
              }, 
              child: const Text("ONLY THIS BILL")
            ),
            TextButton(
              onPressed: () async { 
                Navigator.pop(c); 
                await SaleBillNumber.updateSeriesFromFull(enteredBillNo); 
                _navigateToBilling(); 
              }, 
              child: const Text("UPDATE SERIES")
            )
          ]
        )
      );
    } else { 
      _navigateToBilling(); 
    }
  }

  void _navigateToBilling() {
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
    
    // Auto-resolve party for existing sales
    if (widget.existingSale != null && selectedParty == null) { 
      selectedParty = ph.parties.firstWhere(
        (p) => p.name == widget.existingSale!.partyName, 
        orElse: () => ph.parties[0]
      ); 
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: Text(widget.isReadOnly ? "View Invoice" : (widget.existingSale == null ? "New Sale Entry" : "Modify Sale Invoice")),
        backgroundColor: widget.isReadOnly ? Colors.purple : Colors.blue.shade800,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // --- HEADER SECTION: BILL DETAILS ---
          Container(
            padding: const EdgeInsets.all(20), 
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(25), bottomRight: Radius.circular(25)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: billNoController, 
                        enabled: !widget.isReadOnly, 
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          labelText: "INVOICE NO", 
                          border: OutlineInputBorder(), 
                          filled: true, 
                          fillColor: Color(0xFFFAFAFA)
                        )
                      )
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: InkWell(
                        onTap: widget.isReadOnly ? null : () async { 
                          DateTime? picked = await showDatePicker(
                            context: context, 
                            initialDate: selectedBillDate, 
                            firstDate: firstDateOfFY, 
                            lastDate: lastDateOfFY
                          ); 
                          if (picked != null) setState(() => selectedBillDate = picked); 
                        }, 
                        child: Container(
                          padding: const EdgeInsets.all(12), 
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400), 
                            borderRadius: BorderRadius.circular(5), 
                            color: Colors.white
                          ), 
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end, 
                            children: [
                              const Text("BILL DATE", style: TextStyle(fontSize: 10, color: Colors.grey)), 
                              Text(
                                DateFormat('dd/MM/yyyy').format(selectedBillDate), 
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)
                              )
                            ]
                          )
                        )
                      )
                    )
                  ],
                ),
                const SizedBox(height: 20),
                // Payment Mode Switch
                AbsorbPointer(
                  absorbing: widget.isReadOnly, 
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'CASH', label: Text('CASH SALE'), icon: Icon(Icons.money)), 
                      ButtonSegment(value: 'CREDIT', label: Text('CREDIT SALE'), icon: Icon(Icons.credit_card))
                    ], 
                    selected: {paymentMode}, 
                    onSelectionChanged: (v) => setState(() => paymentMode = v.first)
                  )
                )
              ],
            ),
          ),

          const SizedBox(height: 10),

          // --- PARTY SELECTION SECTION ---
          if (selectedParty != null) 
            Padding(
              padding: const EdgeInsets.all(15),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.blue.shade100)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(15),
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: const Icon(Icons.person, color: Colors.blue),
                  ),
                  title: Text(selectedParty!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), 
                  subtitle: Text("${selectedParty!.city} | GST: ${selectedParty!.gst}"), 
                  trailing: widget.isReadOnly || widget.existingSale != null 
                    ? const Icon(Icons.lock_outline, color: Colors.grey) 
                    : IconButton(
                        icon: const Icon(Icons.change_circle_outlined, color: Colors.orange, size: 30), 
                        onPressed: () => setState(() => selectedParty = null)
                      )
                ),
              ),
            )
          else 
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Text("SELECT CUSTOMER / PARTY", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15), 
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: "Search Party Name...", 
                        prefixIcon: const Icon(Icons.search), 
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.white
                      ), 
                      onChanged: (v) => setState(() => partySearchQuery = v)
                    )
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
                  backgroundColor: widget.isReadOnly ? Colors.purple : Colors.green.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 5
                ), 
                onPressed: () => _validateAndProceed(ph), 
                child: Text(
                  widget.isReadOnly ? "VIEW ITEMS" : "PROCEED TO BILLING", 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)
                )
              ),
            )
        ],
      ),
    );
  }
}
