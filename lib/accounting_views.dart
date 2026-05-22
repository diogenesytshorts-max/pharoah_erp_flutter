// FILE: lib/accounting_views.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'pharoah_date_controller.dart';
import 'app_date_logic.dart';
import 'logic/pharoah_numbering_engine.dart';
import 'pdf/pdf_router_service.dart'; // Ensure this is correct for your router

class VoucherEntryView extends StatefulWidget {
  final String type; 
  const VoucherEntryView({super.key, required this.type});

  @override State<VoucherEntryView> createState() => _VoucherEntryViewState();
}

class _VoucherEntryViewState extends State<VoucherEntryView> {
  // Controllers
  final amountC = TextEditingController();
  final narrationC = TextEditingController();
  final chequeNoC = TextEditingController();
  final partyBankC = TextEditingController();
  final partySearchC = TextEditingController();

  // State
  DateTime selectedDate = DateTime.now();
  DateTime chequeDate = DateTime.now();
  Party? selectedParty;
  Party? selectedInternalAccount; // 🔥 Bank ya Cash Ledger (From Master)
  String payMode = "Cash";
  String voucherNo = "Loading...";
  String partyQuery = "";

  // Selection Data
  List<Map<String, dynamic>> pendingBills = [];
  List<String> selectedBillNumbers = [];
  double runningTotal = 0.0;

  @override
  void initState() {
    super.initState();
    _initVoucher();
  }

  void _initVoucher() async {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    selectedDate = PharoahDateController.getInitialBillDate(ph.currentFY);
    chequeDate = selectedDate;

    var series = ph.getDefaultSeries("VOUCHER");
    String nextNo = await PharoahNumberingEngine.getNextNumber(
      type: "VOUCHER", companyID: ph.activeCompany!.id,
      prefix: series.prefix, startFrom: series.startNumber, currentList: ph.vouchers,
    );
    setState(() => voucherNo = nextNo);
  }

  // ===========================================================================
  // 🛡️ THE BILL SELECTION OVERLAY (NO GLITCH LAYER)
  // ===========================================================================
  void _openReferenceWizard(PharoahManager ph) {
    if (selectedParty == null) return;
    
    // Fetch fresh bills
    pendingBills = ph.getPendingBills(selectedParty!.id, widget.type == "Receipt");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (c) => StatefulBuilder(builder: (context, setWizardState) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            // Header
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text("BILL-WISE ADJUSTMENT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(c)),
            ]),
            const Divider(),

            // List of Bills
            Expanded(
              child: pendingBills.isEmpty 
                ? const Center(child: Text("No pending credit bills found."))
                : ListView.builder(
                    itemCount: pendingBills.length,
                    itemBuilder: (context, i) {
                      final b = pendingBills[i];
                      bool isSel = selectedBillNumbers.contains(b['billNo']);
                      return CheckboxListTile(
                        activeColor: Colors.indigo,
                        value: isSel,
                        title: Text(b['billNo'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Date: ${DateFormat('dd/MM/yy').format(b['date'])} | Due: ${b['dueDays']} Days"),
                        secondary: Text("₹${b['amount']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                        onChanged: (v) {
                          setWizardState(() {
                            if(v!) {
                              selectedBillNumbers.add(b['billNo']);
                              runningTotal += b['amount'];
                            } else {
                              selectedBillNumbers.remove(b['billNo']);
                              runningTotal -= b['amount'];
                            }
                          });
                        },
                      );
                    },
                  ),
            ),

            // 🔥 STICKY RUNNING TOTAL BOX
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(15)),
              child: Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("TOTAL SELECTED", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  Text("₹${runningTotal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.indigo)),
                ]),
                const Spacer(),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
                  onPressed: () {
                    // 🔥 AUTOFILL BRIDGE
                    setState(() { amountC.text = runningTotal.toStringAsFixed(2); });
                    Navigator.pop(c);
                  },
                  child: const Text("APPLY & AUTOFILL"),
                )
              ]),
            )
          ]),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    bool isReceipt = widget.type == "Receipt";
    Color themeColor = isReceipt ? Colors.green.shade800 : Colors.red.shade800;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(title: Text("${widget.type.toUpperCase()} : $voucherNo"), backgroundColor: themeColor),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // --- STEP 1: PARTY ---
          _sectionLabel("1. ACCOUNT / PARTY DETAILS"),
          if (selectedParty == null)
            TextField(
              controller: partySearchC,
              decoration: const InputDecoration(hintText: "Search Party Name...", prefixIcon: Icon(Icons.person_search), border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
              onChanged: (v) => setState(() => partyQuery = v),
            )
          else
            _selectedItemCard(selectedParty!.name, "City: ${selectedParty!.city}", themeColor, () => setState(() => selectedParty = null)),

          if (selectedParty == null && partyQuery.isNotEmpty)
            _buildSearchDropdown(ph),

          const SizedBox(height: 25),

          // --- STEP 2: MODE & DESTINATION ---
          if (selectedParty != null) ...[
            _sectionLabel("2. TRANSACTION MODE"),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Cash', label: Text('Cash'), icon: Icon(Icons.payments_outlined)),
                ButtonSegment(value: 'Bank', label: Text('Bank/Cheque'), icon: Icon(Icons.account_balance_outlined)),
              ],
              selected: {payMode},
              onSelectionChanged: (v) => setState(() => payMode = v.first),
            ),

            const SizedBox(height: 15),
            _sectionLabel(payMode == "Cash" ? "DEPOSIT IN (CASH BOOK)" : "DEPOSIT IN (BANK BOOK)"),
            
            // 🔥 FILTERED DROP-DOWN (Point 4 Fix)
            DropdownButtonFormField<Party>(
              value: selectedInternalAccount,
              decoration: const InputDecoration(border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
              hint: const Text("Select Internal Ledger Account"),
              items: ph.getInternalAccounts()
                .where((p) => payMode == "Cash" ? p.group == "Cash in Hand" : p.group == "Bank Accounts")
                .map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
              onChanged: (v) => setState(() => selectedInternalAccount = v),
            ),

            if (payMode == "Bank") ...[
              const SizedBox(height: 15),
              Row(children: [
                Expanded(child: _input(chequeNoC, "Cheque No.", Icons.numbers)),
                const SizedBox(width: 10),
                Expanded(child: _input(partyBankC, "Party's Bank Name", Icons.account_balance_rounded)),
              ]),
            ],

            const SizedBox(height: 25),

            // --- STEP 3: BILL REFERENCE ---
            _sectionLabel("3. ADJUST AGAINST BILLS"),
            InkWell(
              onTap: () => _openReferenceWizard(ph),
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: themeColor.withOpacity(0.3))),
                child: Row(children: [
                  Icon(Icons.auto_fix_high_rounded, color: themeColor),
                  const SizedBox(width: 15),
                  Text(selectedBillNumbers.isEmpty ? "Tap to select pending bills (Ref Mode)" : "${selectedBillNumbers.length} Bills Selected", style: TextStyle(fontWeight: FontWeight.bold, color: themeColor)),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios, size: 14),
                ]),
              ),
            ),

            const SizedBox(height: 25),

            // --- STEP 4: FINAL SUBMISSION ---
            _sectionLabel("4. FINAL AMOUNT & DATE"),
            Row(children: [
               Expanded(child: TextField(controller: amountC, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), decoration: const InputDecoration(labelText: "AMOUNT ₹", border: OutlineInputBorder()))),
               const SizedBox(width: 10),
               Expanded(child: _dateTile("ENTRY DATE", selectedDate, (d) => setState(() => selectedDate = d), ph.currentFY)),
            ]),
            const SizedBox(height: 15),
            TextField(controller: narrationC, decoration: const InputDecoration(labelText: "Narration (Optional)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.notes))),
            
            const SizedBox(height: 35),
            SizedBox(
              width: double.infinity, height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: themeColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                onPressed: () => _handleFinalSave(ph),
                child: const Text("FINALIZE & SAVE VOUCHER", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ]
        ]),
      ),
    );
  }

  // ===========================================================================
  // 🛡️ ACTION HUB (POST-SAVE)
  // ===========================================================================
  void _showSuccessHub(PharoahManager ph, String vId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 10), Text("Entry Saved!")]),
        content: Text("Voucher $voucherNo has been recorded successfully."),
        actions: [
          TextButton(onPressed: () => Navigator.popUntil(context, (route) => route.isFirst), child: const Text("CLOSE")),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () {
              final vObj = ph.vouchers.firstWhere((v) => v.id == vId);
              final pObj = ph.parties.firstWhere((p) => p.id == vObj.partyId);
              // Router call to print
              PdfRouterService.printCreditNote(returnObj: null as dynamic, party: pObj, ph: ph); // Replace with actual Receipt PDF call
            }, 
            icon: const Icon(Icons.print), label: const Text("PRINT")
          )
        ],
      ),
    );
  }

  void _handleFinalSave(PharoahManager ph) async {
    double amt = double.tryParse(amountC.text) ?? 0;
    if (selectedParty == null || amt <= 0 || selectedInternalAccount == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Party, Internal Account & Amount are mandatory!")));
       return;
    }

    final v = Voucher(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: widget.type,
      voucherNo: voucherNo,
      date: selectedDate,
      partyId: selectedParty!.id,
      partyName: selectedParty!.name,
      amount: amt,
      paymentMode: payMode,
      linkedBillNumbers: selectedBillNumbers,
      chequeNo: chequeNoC.text,
      bankName: partyBankC.text.toUpperCase(),
      depositedIn: selectedInternalAccount!.name,
      chequeDate: payMode == "Bank" ? chequeDate : null,
      narration: narrationC.text,
    );

    String newId = await ph.finalizeVoucher(v);
    _showSuccessHub(ph, newId); // 🔥 Show Hub instead of popping
  }

  // --- UI HELPER ATOMS ---
  Widget _sectionLabel(String t) => Padding(padding: const EdgeInsets.only(bottom: 8, left: 4), child: Text(t, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1)));
  Widget _input(TextEditingController c, String l, IconData i) => TextField(controller: c, decoration: InputDecoration(labelText: l, prefixIcon: Icon(i, size: 20), border: const OutlineInputBorder(), filled: true, fillColor: Colors.white));
  Widget _selectedItemCard(String t, String s, Color c, VoidCallback onClear) => ListTile(tileColor: c.withOpacity(0.05), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: c)), title: Text(t, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(s), trailing: IconButton(icon: const Icon(Icons.cancel), onPressed: onClear));
  Widget _buildSearchDropdown(PharoahManager ph) => Container(height: 200, decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]), child: ListView(children: ph.parties.where((p) => p.name.toLowerCase().contains(partyQuery.toLowerCase())).map((p) => ListTile(title: Text(p.name), onTap: () { setState(() { selectedParty = p; partyQuery = ""; partyBankC.text = ph.getLastUsedBank(p.id); }); })).toList()));
  Widget _dateTile(String l, DateTime d, Function(DateTime) onPick, String fy) => InkWell(onTap: () async { DateTime? p = await PharoahDateController.pickDate(context: context, currentFY: fy, initialDate: d); if (p != null) onPick(p); }, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(5), color: Colors.white), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(fontSize: 8, color: Colors.grey)), Text(DateFormat('dd/MM/yy').format(d), style: const TextStyle(fontWeight: FontWeight.bold))])));
}
