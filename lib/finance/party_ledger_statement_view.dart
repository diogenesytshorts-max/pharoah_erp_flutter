import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import '../pharoah_date_controller.dart';
import '../app_date_logic.dart';
import '../sale_entry_view.dart';
import '../accounting_views.dart';
import '../pdf/pdf_router_service.dart';
import '../pdf/statements/party_ledger_pdf.dart';

class PartyLedgerStatementView extends StatefulWidget {
  const PartyLedgerStatementView({super.key});

  @override
  State<PartyLedgerStatementView> createState() => _PartyLedgerStatementViewState();
}

class _PartyLedgerStatementViewState extends State<PartyLedgerStatementView> {
  DateTime fromDate = DateTime.now();
  DateTime toDate = DateTime.now();
  Party? selectedParty;
  String partyQuery = "";
  bool isSearching = true;

  @override
  void initState() {
    super.initState();
    final ph = Provider.of<PharoahManager>(context, listen: false);
    toDate = AppDateLogic.getSmartDate(ph.currentFY);
    fromDate = AppDateLogic.getFYStart(ph.currentFY);
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    List<Map<String, dynamic>> ledgerData = [];
    
    if (selectedParty != null) {
      ledgerData = ph.getPartyStatementData(
        partyId: selectedParty!.id, 
        fromDate: fromDate, 
        toDate: toDate
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text(selectedParty == null ? "Party Ledger Audit" : selectedParty!.name),
        backgroundColor: const Color(0xFF1A237E),
        actions: [
          if (selectedParty != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded),
              onPressed: () => _generateStatementPdf(ph), // Future PDF Call
            ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterPanel(ph),
          if (selectedParty != null) _buildSummaryRibbon(ledgerData),
          Expanded(
            child: selectedParty == null 
              ? _buildPartySelector(ph) 
              : _buildLedgerTable(ledgerData, ph),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 🛠️ UI COMPONENTS
  // ===========================================================================

  Widget _buildFilterPanel(PharoahManager ph) {
    return Container(
      padding: const EdgeInsets.all(15),
      color: const Color(0xFF1A237E),
      child: Row(children: [
        Expanded(child: _dateBox("FROM", fromDate, (d) => setState(() => fromDate = d), ph.currentFY)),
        const SizedBox(width: 10),
        Expanded(child: _dateBox("TO", toDate, (d) => setState(() => toDate = d), ph.currentFY)),
        if (selectedParty != null)
          IconButton(
            icon: const Icon(Icons.person_search, color: Colors.white),
            onPressed: () => setState(() => selectedParty = null),
          )
      ]),
    );
  }

  Widget _buildPartySelector(PharoahManager ph) {
    final list = ph.parties.where((p) => p.name.toLowerCase().contains(partyQuery.toLowerCase())).toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(15),
        child: TextField(
          decoration: const InputDecoration(hintText: "Search Party/Bank/Cash...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
          onChanged: (v) => setState(() => partyQuery = v),
        ),
      ),
      Expanded(child: ListView.builder(
        itemCount: list.length,
        itemBuilder: (c, i) => ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(list[i].name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text("${list[i].group} | ${list[i].city}"),
          onTap: () => setState(() => selectedParty = list[i]),
        ),
      ))
    ]);
  }

  Widget _buildSummaryRibbon(List<Map<String, dynamic>> data) {
    double dr = data.where((e) => e['type'] != 'OPENING').fold(0, (s, e) => s + (e['dr'] ?? 0));
    double cr = data.where((e) => e['type'] != 'OPENING').fold(0, (s, e) => s + (e['cr'] ?? 0));
    double closing = data.isEmpty ? 0 : data.last['bal'];

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _stat("TOTAL DR", dr, Colors.green),
        _stat("TOTAL CR", cr, Colors.orange),
        _stat("CLOSING", closing, Colors.indigo, isBold: true),
      ]),
    );
  }

  Widget _buildLedgerTable(List<Map<String, dynamic>> data, PharoahManager ph) {
    return ListView.builder(
      itemCount: data.length,
      itemBuilder: (c, i) {
        final row = data[i];
        bool isOpening = row['type'] == 'OPENING';
        return InkWell(
          onTap: isOpening ? null : () => _showActionMenu(row, ph),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isOpening ? Colors.blueGrey.shade50 : Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200))
            ),
            child: Row(children: [
              Expanded(flex: 2, child: Text(DateFormat('dd/MM').format(row['date']), style: const TextStyle(fontSize: 11))),
              Expanded(flex: 4, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(row['type'] == 'OPENING' ? row['particulars'] : row['ref'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Text(row['type'], style: const TextStyle(fontSize: 9, color: Colors.grey)),
              ])),
              Expanded(flex: 2, child: Text(row['dr'] > 0 ? row['dr'].toStringAsFixed(0) : (row['cr'] > 0 ? "-${row['cr'].toInt()}" : ""), textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: row['dr'] > 0 ? Colors.green : Colors.red))),
              Expanded(flex: 3, child: Text(row['bal'].toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.indigo, fontSize: 13))),
            ]),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // 🚀 THE 6-OPTION ACTION HUB
  // ===========================================================================
  void _showActionMenu(Map<String, dynamic> row, PharoahManager ph) {
    final dynamic obj = row['obj'];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (c) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text("${row['type']} - ${row['ref']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Divider(),
          _menuItem(Icons.visibility, "View (Read Only)", Colors.blue, () => _handleView(row)),
          _menuItem(Icons.edit, "Modify / Edit", Colors.orange, () => _handleModify(row)),
          _menuItem(Icons.block, "Cancel Transaction", Colors.deepOrange, () => _handleCancel(row, ph)),
          _menuItem(Icons.delete_forever, "Delete Permanently", Colors.red, () => _handleDelete(row, ph)),
          _menuItem(Icons.print, "Print PDF", Colors.teal, () => _handlePrint(row, ph)),
          _menuItem(Icons.email, "E-mail to Party", Colors.indigo, () => _handleEmail(row, ph)),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  // ===========================================================================
  // ⚙️ LOGIC HANDLERS
  // ===========================================================================

  void _handleView(Map<String, dynamic> row) {
    Navigator.pop(context);
    if (row['type'] == 'SALE') {
      Navigator.push(context, MaterialPageRoute(builder: (c) => SaleEntryView(existingSale: row['obj'], isReadOnly: true)));
    } else if (row['type'] == 'RECEIPT' || row['type'] == 'PAYMENT') {
      Navigator.push(context, MaterialPageRoute(builder: (c) => VoucherEntryView(type: row['type'], existingVoucher: row['obj'], isReadOnly: true)));
    }
  }

  void _handleModify(Map<String, dynamic> row) {
    Navigator.pop(context);
    if (row['type'] == 'SALE') {
      Navigator.push(context, MaterialPageRoute(builder: (c) => SaleEntryView(existingSale: row['obj'])));
    } else if (row['type'] == 'RECEIPT' || row['type'] == 'PAYMENT') {
      Navigator.push(context, MaterialPageRoute(builder: (c) => VoucherEntryView(type: row['type'], existingVoucher: row['obj'])));
    }
  }

  void _handleCancel(Map<String, dynamic> row, PharoahManager ph) {
    Navigator.pop(context);
    // Add PharoahManager implementation for cancel
    ph.addLog("AUDIT", "Cancelled ${row['type']} ${row['ref']}");
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Transaction Cancelled & Reverted")));
  }

  void _handleDelete(Map<String, dynamic> row, PharoahManager ph) {
    Navigator.pop(context);
    // Use existing manager delete functions
    if (row['type'] == 'SALE') ph.deleteBill(row['obj'].id);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Record Deleted Permanently")));
  }

  void _handlePrint(Map<String, dynamic> row, PharoahManager ph) {
    Navigator.pop(context);
    if (row['type'] == 'SALE') {
      PdfRouterService.printSale(sale: row['obj'], party: selectedParty!, ph: ph);
    }
  }

  void _handleEmail(Map<String, dynamic> row, PharoahManager ph) {
    Navigator.pop(context);
    if (selectedParty?.email == null || selectedParty!.email.isEmpty) {
      showDialog(context: context, builder: (c) => const AlertDialog(title: Text("Email Missing"), content: Text("Please add an Email ID in Party Master first.")));
    } else {
      // Future: Generate PDF and Share via Email
      Share.share("Statement for ${row['ref']}", subject: "Invoice from ${ph.activeCompany?.name}");
    }
  }

  // --- HELPERS ---
  Widget _dateBox(String l, DateTime d, Function(DateTime) onPick, String fy) => InkWell(
    onTap: () async {
      DateTime? p = await PharoahDateController.pickDate(context: context, currentFY: fy, initialDate: d);
      if (p != null) onPick(p);
    },
    child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white24)), 
    child: Text("$l: ${DateFormat('dd/MM/yy').format(d)}", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
  );

  Widget _stat(String l, double v, Color c, {bool isBold = false}) => Column(children: [
    Text(l, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey)),
    Text("₹${v.toStringAsFixed(0)}", style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.w900 : FontWeight.bold, color: c)),
  ]);

  Widget _menuItem(IconData i, String t, Color c, VoidCallback onTap) => ListTile(leading: Icon(i, color: c), title: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), onTap: onTap);

  void _generateStatementPdf(PharoahManager ph) async {
    if (selectedParty == null) return;
    
    // Get fresh data
    final data = ph.getPartyStatementData(
      partyId: selectedParty!.id, 
      fromDate: fromDate, 
      toDate: toDate
    );

    // Call PDF Service
    await PartyLedgerPdf.generate(
      shop: ph.activeCompany!,
      party: selectedParty!,
      data: data,
      from: fromDate,
      to: toDate,
    );
  }
