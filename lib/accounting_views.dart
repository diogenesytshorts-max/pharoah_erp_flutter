// FILE: lib/accounting_views.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'pharoah_date_controller.dart';
import 'app_date_logic.dart';
import 'logic/pharoah_numbering_engine.dart';
import 'pdf/pdf_router_service.dart';

class VoucherEntryView extends StatefulWidget {
  final String type; // Receipt or Payment
  final Voucher? existingVoucher; // NAYA: Modification ke liye

  const VoucherEntryView({super.key, required this.type, this.existingVoucher});

  @override State<VoucherEntryView> createState() => _VoucherEntryViewState();
}

class _VoucherEntryViewState extends State<VoucherEntryView> {
  // Controllers
  final amountC = TextEditingController();
  final narrationC = TextEditingController();
  final chequeNoC = TextEditingController();
  final partyBankC = TextEditingController();
  final partySearchC = TextEditingController();

  // State Variables
  DateTime selectedEntryDate = DateTime.now(); // Top Date (Voucher Date)
  DateTime selectedChequeDate = DateTime.now(); // Bottom Date (Instrument Date)
  Party? selectedParty;
  Party? selectedInternalAccount; 
  String payMode = "Cash";
  String voucherNo = "Loading...";
  bool isUpdateMode = false;

  // Bill Selection Logic
  List<Map<String, dynamic>> pendingBills = [];
  List<String> selectedBillNumbers = [];
  double runningTotal = 0.0;
  String partyQuery = "";

  @override
  void initState() {
    super.initState();
    _initVoucherSession();
  }

  // ===========================================================================
  // 🔄 SESSION INITIALIZATION (NEW & MODIFY)
  // ===========================================================================
  void _initVoucherSession() async {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    
    if (widget.existingVoucher != null) {
      // --- MODE: MODIFY ---
      isUpdateMode = true;
      final v = widget.existingVoucher!;
      voucherNo = v.voucherNo;
      amountC.text = v.amount.toString();
      narrationC.text = v.narration.replaceAll("[CANCELLED] ", "");
      payMode = v.paymentMode;
      selectedEntryDate = v.date;
      selectedChequeDate = v.chequeDate ?? v.date;
      chequeNoC.text = v.chequeNo;
      partyBankC.text = v.bankName;
      selectedBillNumbers = List.from(v.linkedBillNumbers);
      runningTotal = v.amount;

      // Find Objects from master
      try {
        selectedParty = ph.parties.firstWhere((p) => p.id == v.partyId);
        selectedInternalAccount = ph.parties.firstWhere((p) => p.name == v.depositedIn);
        pendingBills = ph.getPendingBills(selectedParty!.id, widget.type == "Receipt");
      } catch (e) { debugPrint("Object Match Error: $e"); }

    } else {
      // --- MODE: NEW ENTRY ---
      selectedEntryDate = PharoahDateController.getInitialBillDate(ph.currentFY);
      selectedChequeDate = selectedEntryDate;
      
      var series = ph.getDefaultSeries("VOUCHER");
      voucherNo = await PharoahNumberingEngine.getNextNumber(
        type: "VOUCHER", 
        companyID: ph.activeCompany!.id,
        prefix: series.prefix, 
        startFrom: series.startNumber, 
        currentList: ph.vouchers,
      );
    }
    setState(() {});
  }

  // ===========================================================================
  // 🛡️ BILL REFERENCE WIZARD (Fixed Logic)
  // ===========================================================================
  void _openReferenceWizard(PharoahManager ph) {
    if (selectedParty == null) return;
    pendingBills = ph.getPendingBills(selectedParty!.id, widget.type == "Receipt");

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (c) => StatefulBuilder(builder: (context, setWizardState) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text("ADJUST BILLS: ${selectedParty!.name}", style: const TextStyle(fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(c)),
            ]),
            const Divider(),
            Expanded(child: ListView.builder(
              itemCount: pendingBills.length,
              itemBuilder: (context, i) {
                final b = pendingBills[i];
                bool isSel = selectedBillNumbers.contains(b['billNo']);
                return CheckboxListTile(
                  title: Text(b['billNo'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Date: ${DateFormat('dd/MM/yy').format(b['date'])} | Due: ${b['dueDays']} Days"),
                  secondary: Text("₹${b['amount']}", style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
                  value: isSel,
                  onChanged: (v) {
                    setWizardState(() {
                      if(v!) { selectedBillNumbers.add(b['billNo']); runningTotal += b['amount']; }
                      else { selectedBillNumbers.remove(b['billNo']); runningTotal -= b['amount']; }
                    });
                  },
                );
              },
            )),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.indigo),
              onPressed: () { setState(() => amountC.text = runningTotal.toStringAsFixed(2)); Navigator.pop(c); },
              child: const Text("APPLY & AUTOFILL", style: TextStyle(color: Colors.white)),
            )
          ]),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    Color themeColor = widget.type == "Receipt" ? Colors.green.shade800 : Colors.red.shade800;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text("${isUpdateMode ? 'MODIFY' : 'NEW'} ${widget.type.toUpperCase()} : $voucherNo"),
        backgroundColor: themeColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // --- STEP 1: ENTRY DATE ---
          _sectionLabel("1. VOUCHER DATE (ENTRY DATE)"),
          const SizedBox(height: 10),
          _dateTile("TRANSACTION DATE", selectedEntryDate, (d) => setState(() => selectedEntryDate = d), ph.currentFY, themeColor),

          const SizedBox(height: 25),

          // --- STEP 2: PARTY SELECTION ---
          _sectionLabel("2. ACCOUNT / PARTY DETAILS"),
          const SizedBox(height: 10),
          if (selectedParty == null)
            TextField(
              controller: partySearchC,
              decoration: const InputDecoration(hintText: "Search Party Name...", prefixIcon: Icon(Icons.person_search), border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
              onChanged: (v) => setState(() => partyQuery = v),
            )
          else
            _selectedItemCard(selectedParty!.name, "City: ${selectedParty!.city}", themeColor, () => setState(() { selectedParty = null; selectedBillNumbers.clear(); })),

          if (selectedParty == null && partyQuery.isNotEmpty)
            _buildSearchDropdown(ph),

          const SizedBox(height: 25),

          // --- STEP 3: MODE & BANKING ---
          if (selectedParty != null) ...[
            _sectionLabel("3. PAYMENT MODE & INTERNAL LEDGER"),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Cash', label: Text('Cash'), icon: Icon(Icons.money)),
                ButtonSegment(value: 'Bank', label: Text('Bank / Cheque'), icon: Icon(Icons.account_balance)),
              ],
              selected: {payMode},
              onSelectionChanged: (v) => setState(() => payMode = v.first),
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<Party>(
              value: selectedInternalAccount,
              decoration: InputDecoration(labelText: "Select Our ${payMode == 'Cash' ? 'Cash Box' : 'Bank Account'}", border: const OutlineInputBorder(), filled: true, fillColor: Colors.white),
              items: ph.getInternalAccounts()
                .where((p) => payMode == "Cash" ? p.group == "Cash in Hand" : p.group == "Bank Accounts")
                .map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
              onChanged: (v) => setState(() => selectedInternalAccount = v),
            ),

            if (payMode == "Bank") ...[
              const SizedBox(height: 20),
              _sectionLabel("4. CHEQUE / INSTRUMENT DETAILS"),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _input(chequeNoC, "Cheque No.", Icons.numbers)),
                const SizedBox(width: 10),
                Expanded(child: _dateTile("CHEQUE DATE", selectedChequeDate, (d) => setState(() => selectedChequeDate = d), ph.currentFY, Colors.blueGrey)),
              ]),
              const SizedBox(height: 10),
              _input(partyBankC, "Party's Bank Name (Optional)", Icons.business_rounded),
            ],

            const SizedBox(height: 25),

            // --- STEP 4: ADJUSTMENT ---
            _sectionLabel("5. BILL ADJUSTMENT"),
            const SizedBox(height: 10),
            _buildAdjustmentTrigger(themeColor, ph),

            const SizedBox(height: 30),

            // --- STEP 5: FINAL SAVE ---
            _sectionLabel("6. FINAL AMOUNT"),
            const SizedBox(height: 10),
            TextField(
              controller: amountC, keyboardType: TextInputType.number, 
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              decoration: const InputDecoration(labelText: "PAYMENT AMOUNT ₹", border: OutlineInputBorder(), prefixIcon: Icon(Icons.currency_rupee)),
            ),
            const SizedBox(height: 15),
            TextField(controller: narrationC, decoration: const InputDecoration(labelText: "Narration / Note", border: OutlineInputBorder(), prefixIcon: Icon(Icons.notes))),
            
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity, height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: themeColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                onPressed: () => _handleFinalSave(ph),
                child: Text(isUpdateMode ? "UPDATE TRANSACTION" : "FINALIZE & SAVE VOUCHER", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ]
        ]),
      ),
    );
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  Widget _sectionLabel(String t) => Text(t, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1));
  
  Widget _input(TextEditingController c, String l, IconData i) => TextField(controller: c, decoration: InputDecoration(labelText: l, prefixIcon: Icon(i, size: 20), border: const OutlineInputBorder(), filled: true, fillColor: Colors.white));

  Widget _dateTile(String l, DateTime d, Function(DateTime) onPick, String fy, Color col) => InkWell(
    onTap: () async {
      DateTime? p = await PharoahDateController.pickDate(context: context, currentFY: fy, initialDate: d);
      if (p != null) onPick(p);
    },
    child: Container(
      padding: const EdgeInsets.all(12), 
      decoration: BoxDecoration(border: Border.all(color: col.withOpacity(0.4)), borderRadius: BorderRadius.circular(8), color: Colors.white), 
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l, style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
          Text(DateFormat('dd-MM-yyyy').format(d), style: TextStyle(fontWeight: FontWeight.bold, color: col)),
        ]),
        Icon(Icons.calendar_month, size: 20, color: col),
      ]),
    ),
  );

  Widget _buildAdjustmentTrigger(Color col, PharoahManager ph) => InkWell(
    onTap: () => _openReferenceWizard(ph),
    child: Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: col.withOpacity(0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: col.withOpacity(0.3))),
      child: Row(children: [
        Icon(Icons.auto_fix_high, color: col),
        const SizedBox(width: 15),
        Text(selectedBillNumbers.isEmpty ? "No bills selected (Reference Mode)" : "${selectedBillNumbers.length} Bills Settlemed", 
          style: TextStyle(fontWeight: FontWeight.bold, color: col)),
        const Spacer(),
        const Icon(Icons.chevron_right, size: 18),
      ]),
    ),
  );

  Widget _selectedItemCard(String t, String s, Color c, VoidCallback onClear) => ListTile(
    tileColor: c.withOpacity(0.05), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: c)),
    title: Text(t, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(s),
    trailing: IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: onClear),
  );

  Widget _buildSearchDropdown(PharoahManager ph) => Container(
    height: 200, decoration: BoxDecoration(color: Colors.white, boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 10)]),
    child: ListView(children: ph.parties.where((p) => p.name.toLowerCase().contains(partyQuery.toLowerCase())).map((p) => ListTile(title: Text(p.name), onTap: () { setState(() { selectedParty = p; partyQuery = ""; partyBankC.text = ph.getLastUsedBank(p.id); }); })).toList()),
  );

  void _handleFinalSave(PharoahManager ph) async {
    double amt = double.tryParse(amountC.text) ?? 0;
    if (selectedParty == null || amt <= 0 || selectedInternalAccount == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Account and Amount are mandatory!")));
       return;
    }

    final v = Voucher(
      id: isUpdateMode ? widget.existingVoucher!.id : DateTime.now().millisecondsSinceEpoch.toString(),
      type: widget.type,
      voucherNo: voucherNo,
      date: selectedEntryDate, // ENTRY DATE
      partyId: selectedParty!.id,
      partyName: selectedParty!.name,
      amount: amt,
      paymentMode: payMode,
      linkedBillNumbers: selectedBillNumbers,
      chequeNo: chequeNoC.text,
      bankName: partyBankC.text.toUpperCase(),
      depositedIn: selectedInternalAccount!.name,
      chequeDate: payMode == "Bank" ? selectedChequeDate : null, // CHEQUE DATE
      narration: narrationC.text,
      status: "Active",
    );

    if (isUpdateMode) ph.vouchers.removeWhere((old) => old.id == v.id);
    
    String res = await ph.finalizeVoucher(v);
    if (res == "ERROR_DUPLICATE") {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Duplicate Voucher Number!")));
      return;
    }

    Navigator.pop(context); // Close Entry View
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ Voucher $voucherNo Saved!"), backgroundColor: Colors.green));
  }
}
