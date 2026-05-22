// FILE: lib/accounting_views.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'pharoah_date_controller.dart';
import 'app_date_logic.dart';
import 'logic/pharoah_numbering_engine.dart';

class VoucherEntryView extends StatefulWidget {
  final String type; // Receipt or Payment
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

  // State Variables
  DateTime selectedDate = DateTime.now();
  DateTime chequeDate = DateTime.now();
  Party? selectedParty;
  Bank? depositBank;
  String payMode = "Cash";
  String voucherNo = "Loading...";
  bool isReferenceMode = false;
  String partyQuery = "";

  // Bill Selection Logic
  List<Map<String, dynamic>> pendingBills = [];
  List<String> selectedBillNumbers = [];
  double selectedTotal = 0.0;

  @override
  void initState() {
    super.initState();
    _initVoucher();
  }

  void _initVoucher() async {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    selectedDate = PharoahDateController.getInitialBillDate(ph.currentFY);
    chequeDate = selectedDate;

    // 1. Get Auto Numbering from Architect Series
    var series = ph.getDefaultSeries("VOUCHER");
    String nextNo = await PharoahNumberingEngine.getNextNumber(
      type: "VOUCHER",
      companyID: ph.activeCompany!.id,
      prefix: series.prefix,
      startFrom: series.startNumber,
      currentList: ph.vouchers,
    );
    setState(() => voucherNo = nextNo);
  }

  // Logic: Party Selection par memory aur bills load karna
  void _onPartySelected(PharoahManager ph, Party p) {
    setState(() {
      selectedParty = p;
      partyQuery = "";
      partySearchC.clear();
      // Load Memory
      partyBankC.text = ph.getLastUsedBank(p.id);
      // Fetch Pending Bills
      pendingBills = ph.getPendingBills(p.id, widget.type == "Receipt");
      isReferenceMode = pendingBills.isNotEmpty;
      selectedBillNumbers.clear();
      selectedTotal = 0;
      amountC.text = "0";
    });
  }

  // Logic: Running Total (Outstanding Box) Calculation
  void _toggleBillSelection(String bNo, double amt) {
    setState(() {
      if (selectedBillNumbers.contains(bNo)) {
        selectedBillNumbers.remove(bNo);
        selectedTotal -= amt;
      } else {
        selectedBillNumbers.add(bNo);
        selectedTotal += amt;
      }
      amountC.text = selectedTotal.toStringAsFixed(2);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    bool isReceipt = widget.type == "Receipt";
    Color themeColor = isReceipt ? Colors.green.shade800 : Colors.red.shade800;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: Text("${widget.type.toUpperCase()} : $voucherNo"),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
      ),
      body: Row(
        children: [
          // LEFT PANEL: Main Entry Form (65% Width)
          Expanded(flex: 6, child: _buildMainForm(ph, themeColor)),
          
          // RIGHT PANEL: Outstanding & Running Total Box (35% Width)
          if (selectedParty != null && isReferenceMode)
            Container(width: 350, color: Colors.grey.shade100, child: _buildOutstandingSideBox(themeColor)),
        ],
      ),
    );
  }

  Widget _buildMainForm(PharoahManager ph, Color theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(25),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // --- STEP 1: PARTY SELECTION ---
        _sectionLabel("ACCOUNT / PARTY DETAILS"),
        const SizedBox(height: 10),
        if (selectedParty == null)
          TextField(
            controller: partySearchC,
            decoration: const InputDecoration(hintText: "Search Party Name...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
            onChanged: (v) => setState(() => partyQuery = v),
          )
        else
          ListTile(
            tileColor: theme.withOpacity(0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: theme)),
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(selectedParty!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(selectedParty!.city),
            trailing: IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => setState(() => selectedParty = null)),
          ),

        if (selectedParty == null && partyQuery.isNotEmpty)
          Container(
            height: 200, margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)]),
            child: ListView(children: ph.parties.where((p) => p.name.toLowerCase().contains(partyQuery.toLowerCase())).map((p) => ListTile(title: Text(p.name), onTap: () => _onPartySelected(ph, p))).toList()),
          ),

        const SizedBox(height: 30),

        // --- STEP 2: MODE & BANK ---
        if (selectedParty != null) ...[
          _sectionLabel("PAYMENT MODE & BANKING"),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Cash', label: Text('Cash'), icon: Icon(Icons.money)),
                ButtonSegment(value: 'Bank', label: Text('Bank/Cheque'), icon: Icon(Icons.account_balance)),
              ],
              selected: {payMode},
              onSelectionChanged: (v) => setState(() => payMode = v.first),
            )),
          ]),

          if (payMode == "Bank") ...[
            const SizedBox(height: 15),
            Row(children: [
              Expanded(child: _input(chequeNoC, "Cheque / Ref No.", Icons.numbers)),
              const SizedBox(width: 10),
              Expanded(child: _input(partyBankC, "Customer Bank Name", Icons.business)),
            ]),
            const SizedBox(height: 15),
            _sectionLabel("DEPOSIT IN (OUR BANK)"),
            DropdownButtonFormField<Bank>(
              value: depositBank,
              decoration: const InputDecoration(border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
              items: ph.banks.map((b) => DropdownMenuItem(value: b, child: Text("${b.name} (${b.branch})"))).toList(),
              onChanged: (v) => setState(() => depositBank = v),
            ),
          ],

          const SizedBox(height: 30),

          // --- STEP 3: FINAL TOTAL & SAVE ---
          _sectionLabel("TRANSACTION SUMMARY"),
          const SizedBox(height: 10),
          Row(children: [
             Expanded(child: TextField(controller: amountC, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900), decoration: const InputDecoration(labelText: "FINAL AMOUNT ₹", border: OutlineInputBorder()))),
             const SizedBox(width: 15),
             Expanded(child: _dateTile("ENTRY DATE", selectedDate, (d) => setState(() => selectedDate = d), ph.currentFY)),
          ]),
          const SizedBox(height: 15),
          TextField(controller: narrationC, decoration: const InputDecoration(labelText: "Remarks / Narration", border: OutlineInputBorder(), hintText: "Enter payment details...")),
          
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity, height: 60,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: theme, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              onPressed: () => _handleFinalSave(ph),
              child: const Text("FINALIZE & SAVE VOUCHER", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ]
      ]),
    );
  }

  Widget _buildOutstandingSideBox(Color theme) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(20), color: theme,
        child: const Row(children: [Icon(Icons.list_alt, color: Colors.white), SizedBox(width: 10), Text("BILL-WISE REFERENCE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
      ),
      Expanded(
        child: ListView.builder(
          itemCount: pendingBills.length,
          itemBuilder: (c, i) {
            final b = pendingBills[i];
            bool isSelected = selectedBillNumbers.contains(b['billNo']);
            return CheckboxListTile(
              activeColor: theme,
              value: isSelected,
              title: Text(b['billNo'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text("Date: ${DateFormat('dd/MM/yy').format(b['date'])} | Due: ${b['dueDays']} Days"),
              secondary: Text("₹${b['amount'].toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold)),
              onChanged: (v) => _toggleBillSelection(b['billNo'], b['amount']),
            );
          },
        ),
      ),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade300))),
        child: Column(children: [
           _row("Total Selected", "₹${selectedTotal.toStringAsFixed(2)}"),
           const SizedBox(height: 5),
           _row("Remaining Bal", "₹${(pendingBills.fold(0.0, (s, e) => s + e['amount']) - selectedTotal).toStringAsFixed(0)}"),
           const Divider(),
           const Text("CUMULATIVE SETTLEMENT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
           Text("₹${selectedTotal.toStringAsFixed(2)}", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: theme)),
        ]),
      )
    ]);
  }

  // --- UI ATOMS ---
  Widget _sectionLabel(String t) => Text(t, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1));
  
  Widget _input(TextEditingController ctrl, String label, IconData icon, {bool isNum = false}) => TextField(
    controller: ctrl, keyboardType: isNum ? TextInputType.number : TextInputType.text,
    decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 20), border: const OutlineInputBorder(), filled: true, fillColor: Colors.white),
  );

  Widget _dateTile(String l, DateTime d, Function(DateTime) onPick, String fy) => InkWell(
    onTap: () async {
      DateTime? p = await PharoahDateController.pickDate(context: context, currentFY: fy, initialDate: d);
      if (p != null) onPick(p);
    },
    child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(5), color: Colors.white), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(fontSize: 8, color: Colors.grey)), Text(DateFormat('dd/MM/yyyy').format(d), style: const TextStyle(fontWeight: FontWeight.bold))])),
  );

  Widget _row(String l, String v) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(fontSize: 12)), Text(v, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))]);

  void _handleFinalSave(PharoahManager ph) {
    double amt = double.tryParse(amountC.text) ?? 0;
    if (selectedParty == null || amt <= 0) return;

    if (payMode == "Cash" && ph.isCashLimitExceeded(selectedParty!.id, amt)) {
      _showCashWarning();
      return;
    }

    final v = Voucher(
      id: DateTime.now().toString(),
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
      depositedIn: depositBank?.name ?? "",
      chequeDate: payMode == "Bank" ? chequeDate : null,
      narration: narrationC.text,
    );

    ph.finalizeVoucher(v);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ ${widget.type} $voucherNo Saved!"), backgroundColor: Colors.green));
  }

  void _showCashWarning() {
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text("CASH LIMIT EXCEEDED", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      content: const Text("As per IT rules, you cannot receive more than ₹2,00,000 in cash from a single party in one day."),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("I UNDERSTAND"))],
    ));
  }
}
