// FILE: lib/payment_receipt_history.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'pharoah_date_controller.dart';
import 'app_date_logic.dart';
import 'pdf/pdf_router_service.dart';
import 'pdf/history_report_pdf.dart'; // Naya Report File
import 'logic/history_excel_service.dart'; // Naya Excel Service

class PaymentReceiptHistory extends StatefulWidget {
  const PaymentReceiptHistory({super.key});

  @override
  State<PaymentReceiptHistory> createState() => _PaymentReceiptHistoryState();
}

class _PaymentReceiptHistoryState extends State<PaymentReceiptHistory> {
  String searchQuery = "";
  DateTime fromDate = DateTime.now();
  DateTime toDate = DateTime.now();
  String viewMode = "All"; 
  Party? selectedParty;
  bool _isInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final ph = Provider.of<PharoahManager>(context, listen: false);
      // Smart FY Logic
      toDate = AppDateLogic.getSmartDate(ph.currentFY);
      fromDate = toDate.subtract(const Duration(days: 30));
      DateTime fyStart = AppDateLogic.getFYStart(ph.currentFY);
      if (fromDate.isBefore(fyStart)) fromDate = fyStart;
      _isInit = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    // --- ADVANCED FILTER ENGINE ---
    final filteredList = ph.vouchers.reversed.where((v) {
      // 1. Date Boundary Check
      bool matchesDate = v.date.isAfter(fromDate.subtract(const Duration(days: 1))) &&
          v.date.isBefore(toDate.add(const Duration(days: 1)));
      
      // 2. Intelligent Search (ID or Name)
      bool matchesSearch = v.partyName.toLowerCase().contains(searchQuery.toLowerCase()) ||
          v.voucherNo.toLowerCase().contains(searchQuery.toLowerCase());
      
      // 3. Context Check (All vs Single Party)
      bool matchesParty = viewMode == "All" || (selectedParty != null && v.partyId == selectedParty!.id);

      return matchesDate && matchesSearch && matchesParty;
    }).toList();

    // Live Metrics for Summary Ribbon
    double totalReceived = filteredList
        .where((v) => v.type == "Receipt" && !v.narration.contains("CANCELLED"))
        .fold(0.0, (s, v) => s + v.amount);
    double totalPaid = filteredList
        .where((v) => v.type == "Payment" && !v.narration.contains("CANCELLED"))
        .fold(0.0, (s, v) => s + v.amount);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: const Text("Payment or Receipt History", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          // 📊 EXCEL STATEMENT EXPORT
          IconButton(
            icon: const Icon(Icons.file_download_outlined), 
            onPressed: () => HistoryExcelService.export(filteredList, ph.activeCompany!.name), 
            tooltip: "Export Excel Statement"
          ),
          // 📄 PDF LEDGER STATEMENT EXPORT
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined), 
            onPressed: () {
              // ADVANCED LOGIC: Calculate Opening Balance for the Statement
              double opFlow = ph.vouchers
                  .where((v) => v.date.isBefore(fromDate) && !v.narration.contains("CANCELLED"))
                  .fold(0.0, (sum, v) => sum + (v.type == "Receipt" ? v.amount : -v.amount));

              HistoryReportPdf.generate(
                list: filteredList, 
                fDate: fromDate, 
                tDate: toDate, 
                shop: ph.activeCompany!,
                openingFlow: opFlow
              );
            }, 
            tooltip: "Export PDF Ledger"
          ),
        ],
      ),
      body: Column(
        children: [
          _buildAdvancedHeader(ph),
          _buildSummaryRibbon(totalReceived, totalPaid),
          Expanded(
            child: filteredList.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filteredList.length,
                    itemBuilder: (c, i) => _buildVoucherCard(filteredList[i], ph),
                  ),
          ),
          _buildSystemFooter(ph.currentFY),
        ],
      ),
    );
  }

  // ===========================================================================
  // UI COMPONENTS (PREMIUM DESIGN)
  // ===========================================================================

  Widget _buildAdvancedHeader(PharoahManager ph) {
    return Container(
      padding: const EdgeInsets.all(15),
      color: const Color(0xFF1A237E),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: TextField(
              style: const TextStyle(color: Colors.white),
              onChanged: (v) => setState(() => searchQuery = v),
              decoration: InputDecoration(
                hintText: "Search Party Name or ID...",
                hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true, fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _buildViewToggle(ph),
        ]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _dateTile("FROM", fromDate, (d) => setState(() => fromDate = d), ph.currentFY),
          const Icon(Icons.swap_horiz_rounded, color: Colors.white24, size: 20),
          _dateTile("TO", toDate, (d) => setState(() => toDate = d), ph.currentFY),
        ]),
      ]),
    );
  }

  Widget _buildSummaryRibbon(double rec, double paid) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _statBox("RECEIVED", rec, Colors.green.shade700),
        _statBox("PAID", paid, Colors.red.shade700),
        _statBox("NET SETTLED", rec - paid, Colors.indigo.shade900),
      ]),
    );
  }

  Widget _buildVoucherCard(Voucher v, PharoahManager ph) {
    bool isReceipt = v.type == "Receipt";
    bool isCancelled = v.narration.toUpperCase().contains("CANCELLED"); 
    Color themeColor = isReceipt ? Colors.green.shade700 : Colors.red.shade700;

    return Card(
      elevation: isCancelled ? 0 : 1, 
      margin: const EdgeInsets.only(bottom: 10),
      color: isCancelled ? Colors.grey.shade50 : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), 
      side: BorderSide(color: isCancelled ? Colors.grey.shade200 : Colors.transparent)),
      child: InkWell(
        onTap: () => _showActionHub(v, ph),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            _dateCircle(v.date, themeColor, isCancelled),
            const SizedBox(width: 15),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(v.partyName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, 
                decoration: isCancelled ? TextDecoration.lineThrough : null, 
                color: isCancelled ? Colors.grey : Colors.black87)),
              Text("${v.voucherNo} | ${v.paymentMode}", 
                style: TextStyle(fontSize: 10, color: isCancelled ? Colors.grey : Colors.blueGrey, fontWeight: FontWeight.bold)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text("₹${v.amount.toStringAsFixed(2)}", 
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isCancelled ? Colors.grey : Colors.black87)),
              const SizedBox(height: 4),
              _statusTag(v.type, themeColor, isCancelled),
            ]),
          ]),
        ),
      ),
    );
  }

  // ===========================================================================
  // THE 5-WAY ULTIMATE ACTION HUB
  // ===========================================================================
  void _showActionHub(Voucher v, PharoahManager ph) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (c) => Padding(
        padding: const EdgeInsets.all(25),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(height: 5, width: 40, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 20),
          Text(v.partyName, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const Divider(height: 40),
          
          // ROW 1: PRIMARY ACTIONS
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
             _hubBtn(Icons.visibility_outlined, "VIEW", Colors.blue, () { Navigator.pop(c); /* View Logic */ }),
             _hubBtn(Icons.edit_note_rounded, "MODIFY", Colors.orange, () { Navigator.pop(c); /* Modify Logic */ }),
             _hubBtn(Icons.print_rounded, "PRINT", Colors.teal, () { 
                Navigator.pop(c);
                final party = ph.parties.firstWhere((p) => p.id == v.partyId, orElse: () => Party(id:'0', name: v.partyName));
                PdfRouterService.printVoucher(voucher: v, party: party, ph: ph);
             }),
          ]),
          const SizedBox(height: 25),
          
          // ROW 2: AUDIT & SAFETY
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
             _hubBtn(Icons.block_flipped, "CANCEL", Colors.deepOrange, () {
                Navigator.pop(c);
                _confirm("Reverse this transaction?", () => ph.cancelVoucher(v.id));
             }),
             _hubBtn(Icons.delete_forever_rounded, "DELETE", Colors.red, () {
                Navigator.pop(c);
                _confirm("Delete record permanently?", () => ph.deleteVoucher(v.id));
             }),
          ]),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  // ===========================================================================
  // SUB-WIDGETS & HELPERS
  // ===========================================================================

  Widget _buildViewToggle(PharoahManager ph) {
    return InkWell(
      onTap: () => _openPartySelector(ph),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Colors.orange.shade800, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Text(viewMode == "All" ? "ALL ACCOUNTS" : "FILTERED", style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
          const Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
        ]),
      ),
    );
  }

  void _openPartySelector(PharoahManager ph) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          const Text("SELECT ACCOUNT TO FILTER", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.all_inclusive)),
            title: const Text("Show Full History (All Parties)"),
            onTap: () { setState(() { viewMode = "All"; selectedParty = null; }); Navigator.pop(c); },
          ),
          const Divider(),
          Expanded(child: ListView(children: ph.parties.map((p) => ListTile(
            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(p.city),
            onTap: () { setState(() { viewMode = "Party Wise"; selectedParty = p; }); Navigator.pop(c); },
          )).toList())),
        ]),
      ),
    );
  }

  Widget _dateTile(String label, DateTime date, Function(DateTime) onPick, String fy) => InkWell(
    onTap: () async {
      DateTime? p = await PharoahDateController.pickDate(context: context, currentFY: fy, initialDate: date);
      if (p != null) onPick(p);
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white24)),
      child: Text("$label: ${DateFormat('dd/MM/yy').format(date)}", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    ),
  );

  Widget _statBox(String l, double v, Color c) => Column(children: [
    Text(l, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey)),
    Text("₹${v.toStringAsFixed(0)}", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: c))
  ]);

  Widget _dateCircle(DateTime d, Color c, bool can) => Container(
    width: 45, padding: const EdgeInsets.symmetric(vertical: 6),
    decoration: BoxDecoration(color: can ? Colors.grey.shade200 : c.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
    child: Column(children: [
      Text(DateFormat('dd').format(d), style: TextStyle(fontWeight: FontWeight.bold, color: can ? Colors.grey : c, fontSize: 16)),
      Text(DateFormat('MMM').format(d).toUpperCase(), style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: can ? Colors.grey : c)),
    ]),
  );

  Widget _statusTag(String t, Color c, bool can) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: can ? Colors.grey : c, borderRadius: BorderRadius.circular(6)),
    child: Text(can ? "CANCELLED" : t.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
  );

  Widget _hubBtn(IconData i, String l, Color c, VoidCallback t) => InkWell(onTap: t, child: Column(children: [
    Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withOpacity(0.1), shape: BoxShape.circle), child: Icon(i, color: c, size: 24)),
    const SizedBox(height: 6),
    Text(l, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: c)),
  ]));

  void _confirm(String msg, VoidCallback onConfirm) {
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text("Confirm Action"),
      content: Text(msg),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text("NO")),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), 
        onPressed: () { onConfirm(); Navigator.pop(c); }, child: const Text("YES, PROCEED")),
      ],
    ));
  }

  Widget _buildEmptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.history_toggle_off_rounded, size: 70, color: Colors.grey.shade300),
    const Text("No vouchers found in this criteria.", style: TextStyle(color: Colors.grey, fontSize: 13)),
  ]));

  Widget _buildSystemFooter(String fy) => Container(
    width: double.infinity, padding: const EdgeInsets.all(10), color: Colors.white,
    child: Text("Live Ledger Feed | Financial Year: $fy", textAlign: TextAlign.center, 
    style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
  );
}
