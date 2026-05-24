// FILE: lib/payment_receipt_history.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'pharoah_date_controller.dart';
import 'app_date_logic.dart';
import 'pdf/pdf_router_service.dart';

class PaymentReceiptHistory extends StatefulWidget {
  const PaymentReceiptHistory({super.key});

  @override
  State<PaymentReceiptHistory> createState() => _PaymentReceiptHistoryState();
}

class _PaymentReceiptHistoryState extends State<PaymentReceiptHistory> {
  String searchQuery = "";
  DateTime fromDate = DateTime.now();
  DateTime toDate = DateTime.now();
  String viewMode = "All"; // All ya Party Wise
  Party? selectedParty;
  bool _isInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final ph = Provider.of<PharoahManager>(context, listen: false);
      // FY Locked Smart Dates
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

    // --- UNIVERSAL FILTER LOGIC ---
    final filteredList = ph.vouchers.reversed.where((v) {
      // 1. Date Filter
      bool matchesDate = v.date.isAfter(fromDate.subtract(const Duration(days: 1))) &&
          v.date.isBefore(toDate.add(const Duration(days: 1)));
      
      // 2. Search Query (Name or ID)
      bool matchesSearch = v.partyName.toLowerCase().contains(searchQuery.toLowerCase()) ||
          v.voucherNo.toLowerCase().contains(searchQuery.toLowerCase());
      
      // 3. View Mode (Party Specific)
      bool matchesParty = viewMode == "All" || (selectedParty != null && v.partyId == selectedParty!.id);

      return matchesDate && matchesSearch && matchesParty;
    }).toList();

    // Summary Calculations
    double totalReceived = filteredList.where((v) => v.type == "Receipt").fold(0.0, (s, v) => s + v.amount);
    double totalPaid = filteredList.where((v) => v.type == "Payment").fold(0.0, (s, v) => s + v.amount);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F8),
      appBar: AppBar(
        title: const Text("Payment or Receipt History", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.file_download_outlined), onPressed: () => _showExportAlert("Excel"), tooltip: "Export Excel"),
          IconButton(icon: const Icon(Icons.picture_as_pdf_outlined), onPressed: () => _showExportAlert("PDF"), tooltip: "Export PDF Statement"),
        ],
      ),
      body: Column(
        children: [
          _buildFilterHeader(ph),
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
          _buildSystemFooter(),
        ],
      ),
    );
  }

  // ===========================================================================
  // UI COMPONENTS
  // ===========================================================================

  Widget _buildFilterHeader(PharoahManager ph) {
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
                hintText: "Search Party or Txn ID...",
                hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true, fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _buildModeToggle(ph),
        ]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _dateTile("FROM", fromDate, (d) => setState(() => fromDate = d), ph.currentFY),
          const Icon(Icons.arrow_forward_rounded, color: Colors.white24, size: 16),
          _dateTile("TO", toDate, (d) => setState(() => toDate = d), ph.currentFY),
        ]),
      ]),
    );
  }

  Widget _buildSummaryRibbon(double inAmt, double outAmt) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _stat("TOTAL RECEIVED", inAmt, Colors.green.shade700),
        _stat("TOTAL PAID", outAmt, Colors.red.shade700),
        _stat("NET FLOW", inAmt - outAmt, Colors.indigo),
      ]),
    );
  }

  Widget _buildVoucherCard(Voucher v, PharoahManager ph) {
    bool isReceipt = v.type == "Receipt";
    // Using a temporary strikethrough check (since current model might not have status yet)
    bool isCancelled = v.narration.toUpperCase().contains("CANCELLED"); 
    Color themeColor = isReceipt ? Colors.green.shade700 : Colors.red.shade700;

    return Card(
      elevation: 1, margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: () => _showActionMenu(v, ph),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            _dateBox(v.date, themeColor),
            const SizedBox(width: 15),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(v.partyName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, decoration: isCancelled ? TextDecoration.lineThrough : null)),
              Text("ID: ${v.voucherNo} | ${v.paymentMode}", style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text("₹${v.amount.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: isCancelled ? Colors.grey : Colors.black87)),
              const SizedBox(height: 4),
              _typeTag(v.type, themeColor, isCancelled),
            ]),
          ]),
        ),
      ),
    );
  }

  // ===========================================================================
  // THE 5-WAY ACTION HUB (VIEW, MODIFY, PRINT, CANCEL, DELETE)
  // ===========================================================================
  void _showActionMenu(Voucher v, PharoahManager ph) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (c) => Padding(
        padding: const EdgeInsets.all(25),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(v.partyName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          const Divider(height: 30),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
             // 1. PRINT (Now Fully Functional)
             _actionBtn(Icons.print_rounded, "PRINT", Colors.teal, () { 
                Navigator.pop(c);
                final partyObj = ph.parties.firstWhere((p) => p.id == v.partyId, 
                    orElse: () => Party(id:'0', name: v.partyName, city: "N/A", gst: "N/A"));
                
                // Ye wahi function hai jo humne Step 2 mein banaya tha
                PdfRouterService.printVoucher(voucher: v, party: partyObj, ph: ph);
             }),
             // 2. CANCEL
             _actionBtn(Icons.block, "CANCEL", Colors.deepOrange, () {
                Navigator.pop(c);
                _confirmAction("Cancel this entry?", () => ph.cancelVoucher(v.id));
             }),
             // 3. DELETE
             _actionBtn(Icons.delete_forever, "DELETE", Colors.red, () {
                Navigator.pop(c);
                _confirmAction("Permanently delete record?", () => ph.deleteVoucher(v.id));
             }),
          ]),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  // Chota sa confirmation dialog taaki galti se delete na ho
  void _confirmAction(String msg, VoidCallback onConfirm) {
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text("Are you sure?"),
      content: Text(msg),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text("NO")),
        ElevatedButton(onPressed: () { onConfirm(); Navigator.pop(c); }, child: const Text("YES")),
      ],
    ));
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  Widget _buildModeToggle(PharoahManager ph) {
    return InkWell(
      onTap: () => _showPartySelectionSheet(ph),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Text(viewMode == "All" ? "VIEW ALL" : "PARTY WISE", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          const Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
        ]),
      ),
    );
  }

  void _showPartySelectionSheet(PharoahManager ph) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          const Text("SELECT PARTY", style: TextStyle(fontWeight: FontWeight.bold)),
          ListTile(title: const Text("SHOW ALL TRANSACTIONS"), leading: const Icon(Icons.all_inclusive), onTap: () { setState(() { viewMode = "All"; selectedParty = null; }); Navigator.pop(c); }),
          const Divider(),
          Expanded(child: ListView(children: ph.parties.map((p) => ListTile(title: Text(p.name), subtitle: Text(p.city), onTap: () { setState(() { viewMode = "Party Wise"; selectedParty = p; }); Navigator.pop(c); })).toList())),
        ]),
      ),
    );
  }

  Widget _dateTile(String l, DateTime d, Function(DateTime) onPick, String fy) => InkWell(
    onTap: () async {
      DateTime? p = await PharoahDateController.pickDate(context: context, currentFY: fy, initialDate: d);
      if (p != null) onPick(p);
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white24)),
      child: Text("$l: ${DateFormat('dd/MM/yy').format(d)}", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    ),
  );

  Widget _stat(String l, double v, Color c) => Column(children: [Text(l, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey)), Text("₹${v.toStringAsFixed(0)}", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: c))]);
  Widget _dateBox(DateTime d, Color c) => Container(width: 45, padding: const EdgeInsets.symmetric(vertical: 5), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Column(children: [Text(DateFormat('dd').format(d), style: TextStyle(fontWeight: FontWeight.bold, color: c, fontSize: 16)), Text(DateFormat('MMM').format(d).toUpperCase(), style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: c))]));
  Widget _typeTag(String t, Color c, bool can) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: can ? Colors.grey : c, borderRadius: BorderRadius.circular(5)), child: Text(can ? "CANCELLED" : t.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)));
  Widget _actionBtn(IconData i, String l, Color c, VoidCallback t) => InkWell(onTap: t, child: Column(children: [CircleAvatar(backgroundColor: c.withOpacity(0.1), child: Icon(i, color: c)), const SizedBox(height: 5), Text(l, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: c))]));
  Widget _buildEmptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.history_toggle_off_rounded, size: 60, color: Colors.grey.shade300), const Text("No transactions found in this range.", style: TextStyle(color: Colors.grey, fontSize: 12))]));
  Widget _buildSystemFooter() => Container(width: double.infinity, padding: const EdgeInsets.all(8), color: Colors.white, child: Text("Data Synced with ${viewMode.toUpperCase()} Filter | FY: ${Provider.of<PharoahManager>(context, listen: false).currentFY}", textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)));
  void _showExportAlert(String type) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Preparing $type Statement... Please wait."), backgroundColor: Colors.indigo));
}
