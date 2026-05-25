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
import '../../pdf/statements/party_ledger_pdf.dart'; // Connection with PDF service

class PartyLedgerStatementView extends StatefulWidget {
  const PartyLedgerStatementView({super.key});
  @override State<PartyLedgerStatementView> createState() => _PartyLedgerStatementViewState();
}

class _PartyLedgerStatementViewState extends State<PartyLedgerStatementView> {
  DateTime fromDate = DateTime.now();
  DateTime toDate = DateTime.now();
  Party? selectedParty;
  String partyQuery = "";

  @override
  void initState() {
    super.initState();
    final ph = Provider.of<PharoahManager>(context, listen: false);
    toDate = AppDateLogic.getSmartDate(ph.currentFY);
    fromDate = AppDateLogic.getFYStart(ph.currentFY);
  }

  // 🔥 NAYA: PDF Generation Logic
  void _generateStatementPdf(PharoahManager ph) async {
    if (selectedParty == null) return;

    // 1. Fresh data manager se mangna
    final data = ph.getPartyStatementData(
      partyId: selectedParty!.id, 
      fromDate: fromDate, 
      toDate: toDate
    );

    // 2. Asli PDF File ko trigger karna
    await PartyLedgerPdf.generate(
      shop: ph.activeCompany!,
      party: selectedParty!,
      data: data,
      from: fromDate,
      to: toDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    List<Map<String, dynamic>> ledgerData = [];
    if (selectedParty != null) {
      ledgerData = ph.getPartyStatementData(partyId: selectedParty!.id, fromDate: fromDate, toDate: toDate);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text(selectedParty == null ? "Ledger Audit" : selectedParty!.name),
        backgroundColor: const Color(0xFF1A237E),
        // 🔥 NAYA: PDF Button yahan add kiya gaya hai
        actions: [
          if (selectedParty != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded),
              onPressed: () => _generateStatementPdf(ph), // Connecting logic
            ),
        ],
      ),
      body: Column(children: [
        _buildFilterPanel(ph),
        if (selectedParty != null) _buildSummaryRibbon(ledgerData),
        Expanded(child: selectedParty == null ? _buildPartySelector(ph) : _buildLedgerTable(ledgerData, ph)),
      ]),
    );
  }

  Widget _buildFilterPanel(PharoahManager ph) => Container(
    padding: const EdgeInsets.all(15), color: const Color(0xFF1A237E),
    child: Row(children: [
      Expanded(child: _dateBox("FROM", fromDate, (d) => setState(() => fromDate = d), ph.currentFY)),
      const SizedBox(width: 10),
      Expanded(child: _dateBox("TO", toDate, (d) => setState(() => toDate = d), ph.currentFY)),
      if (selectedParty != null) IconButton(icon: const Icon(Icons.person_search, color: Colors.white), onPressed: () => setState(() => selectedParty = null))
    ]),
  );

  Widget _buildPartySelector(PharoahManager ph) {
    final list = ph.parties.where((p) => p.name.toLowerCase().contains(partyQuery.toLowerCase())).toList();
    return Column(children: [
      Padding(padding: const EdgeInsets.all(15), child: TextField(decoration: const InputDecoration(hintText: "Search Party...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()), onChanged: (v) => setState(() => partyQuery = v))),
      Expanded(child: ListView.builder(itemCount: list.length, itemBuilder: (c, i) => ListTile(title: Text(list[i].name, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(list[i].city), onTap: () => setState(() => selectedParty = list[i]))))
    ]);
  }

  Widget _buildSummaryRibbon(List<Map<String, dynamic>> data) {
    double closing = data.isEmpty ? 0 : data.last['bal'];
    return Container(padding: const EdgeInsets.all(15), decoration: const BoxDecoration(color: Colors.white), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [_stat("NET BALANCE", closing, Colors.indigo, isBold: true)]));
  }

  Widget _buildLedgerTable(List<Map<String, dynamic>> data, PharoahManager ph) {
    return ListView.builder(
      itemCount: data.length,
      itemBuilder: (c, i) {
        final row = data[i];
        bool isOp = row['type'] == 'OPENING';
        return ListTile(
          onTap: isOp ? null : () => _showActionMenu(row, ph),
          title: Text(isOp ? row['particulars'] : row['ref'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          subtitle: Text("${DateFormat('dd/MM').format(row['date'])} | ${row['type']}"),
          trailing: Text(row['bal'].toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
        );
      },
    );
  }

  void _showActionMenu(Map<String, dynamic> row, PharoahManager ph) {
    showModalBottomSheet(context: context, builder: (c) => Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.visibility), title: const Text("View"), onTap: () => Navigator.pop(c)),
      ListTile(leading: const Icon(Icons.print), title: const Text("Print"), onTap: () => Navigator.pop(c)),
    ]));
  }

  Widget _dateBox(String l, DateTime d, Function(DateTime) onPick, String fy) => InkWell(onTap: () async { DateTime? p = await PharoahDateController.pickDate(context: context, currentFY: fy, initialDate: d); if (p != null) onPick(p); }, child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text("$l: ${DateFormat('dd/MM/yy').format(d)}", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))));
  Widget _stat(String l, double v, Color c, {bool isBold = false}) => Column(children: [Text(l, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold)), Text("₹${v.toStringAsFixed(2)}", style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.w900 : FontWeight.bold, color: c))]);
}
