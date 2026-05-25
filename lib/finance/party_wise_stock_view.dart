import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import '../pharoah_date_controller.dart';
import '../app_date_logic.dart';
import '../../pdf/statements/party_stock_pdf.dart'; // Connection with PDF

class PartyWiseStockView extends StatefulWidget {
  const PartyWiseStockView({super.key});
  @override State<PartyWiseStockView> createState() => _PartyWiseStockViewState();
}

class _PartyWiseStockViewState extends State<PartyWiseStockView> {
  DateTime fromDate = DateTime.now();
  DateTime toDate = DateTime.now();
  String mode = "SALE_ONLY"; 
  String partySearch = "";

  @override
  void initState() {
    super.initState();
    final ph = Provider.of<PharoahManager>(context, listen: false);
    toDate = AppDateLogic.getSmartDate(ph.currentFY);
    fromDate = AppDateLogic.getFYStart(ph.currentFY);
  }

  // Helper logic for date range
  bool _isInRange(DateTime d) => 
      d.isAfter(fromDate.subtract(const Duration(seconds: 1))) && 
      d.isBefore(toDate.add(const Duration(days: 1)));

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    
    // 1. Data Aggregation Logic
    Map<String, List<Map<String, dynamic>>> groupedData = {};

    // Process Sales
    for (var s in ph.sales.where((s) => s.status == "Active" && _isInRange(s.date))) {
      if (!groupedData.containsKey(s.partyName)) groupedData[s.partyName] = [];
      for (var it in s.items) {
        groupedData[s.partyName]!.add({
          'name': it.name, 'qty': it.qty, 'free': it.freeQty, 'rate': it.rate, 'total': it.total, 'type': 'SALE'
        });
      }
    }

    // Process Purchases (If Mixed Mode)
    if (mode == "MIXED") {
      for (var p in ph.purchases.where((p) => _isInRange(p.date))) {
        if (!groupedData.containsKey(p.distributorName)) groupedData[p.distributorName] = [];
        for (var it in p.items) {
          groupedData[p.distributorName]!.add({
            'name': it.name, 'qty': it.qty, 'free': it.freeQty, 'rate': it.purchaseRate, 'total': it.total, 'type': 'PUR'
          });
        }
      }
    }

    var filteredParties = groupedData.keys.where((k) => k.toLowerCase().contains(partySearch.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      actions: [
          // 📧 NAYA: EMAIL ICON FOR PARTY WISE STOCK
          if (ph.config.isEmailActive)
            IconButton(
              icon: const Icon(Icons.alternate_email),
              tooltip: "Email Party Stock Report",
              onPressed: () {
                PdfRouterService.emailDocument(
                  context: context,
                  doc: {
                    'grouped': groupedData,
                    'from': fromDate,
                    'to': toDate,
                    'mode': mode
                  },
                  party: Party(id: 'internal', name: 'Party Stock Analysis'), // Dummy for Quick Add
                  ph: ph,
                  type: "STOCK",
                );
              },
            ),

          IconButton(
            icon: const Icon(Icons.picture_as_pdf), 
            onPressed: () async {
              await PartyStockPdf.generate(
                shop: ph.activeCompany!,
                groupedData: groupedData,
                from: fromDate,
                to: toDate,
                mode: mode,
              );
            }
          )
        ],
      body: Column(children: [
        _buildFilterHeader(ph),
        Expanded(
          child: filteredParties.isEmpty 
            ? const Center(child: Text("No records found."))
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: filteredParties.length,
                itemBuilder: (c, i) {
                  String pName = filteredParties[i];
                  return _buildPartyCard(pName, groupedData[pName]!);
                },
              ),
        ),
        _buildGrandTotalBar(groupedData, filteredParties),
      ]),
    );
  }

  // ===========================================================================
  // UI HELPER METHODS (OUTSIDE BUILD)
  // ===========================================================================

  Widget _buildFilterHeader(PharoahManager ph) => Container(
    padding: const EdgeInsets.all(15), color: Colors.teal.shade800,
    child: Column(children: [
      Row(children: [
        Expanded(child: _dateTile("FROM", fromDate, (d) => setState(() => fromDate = d), ph.currentFY)),
        const SizedBox(width: 10),
        Expanded(child: _dateTile("TO", toDate, (d) => setState(() => toDate = d), ph.currentFY)),
      ]),
      const SizedBox(height: 12),
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'SALE_ONLY', label: Text('SALE ONLY'), icon: Icon(Icons.outbound)),
          ButtonSegment(value: 'MIXED', label: Text('PUR & SALE'), icon: Icon(Icons.swap_vert)),
        ],
        selected: {mode},
        onSelectionChanged: (v) => setState(() => mode = v.first),
      ),
      const SizedBox(height: 10),
      TextField(
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "Search Party...", 
          hintStyle: const TextStyle(color: Colors.white54), 
          prefixIcon: const Icon(Icons.search, color: Colors.white), 
          filled: true, fillColor: Colors.white.withOpacity(0.1), 
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), 
          isDense: true
        ),
        onChanged: (v) => setState(() => partySearch = v),
      )
    ]),
  );

  Widget _buildPartyCard(String name, List<Map<String, dynamic>> items) {
    double q = items.fold(0, (s, e) => s + e['qty']);
    double f = items.fold(0, (s, e) => s + e['free']);
    double t = items.fold(0, (s, e) => s + e['total']);

    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      child: Column(children: [
        ListTile(
          tileColor: Colors.teal.withOpacity(0.05),
          leading: const Icon(Icons.person, color: Colors.teal),
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ),
        _itemTable(items),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(color: Color(0xFFFAFAFA), border: Border(top: BorderSide(color: Color(0xFFEEEEEE)))),
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            const Text("PARTY TOTAL:", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const SizedBox(width: 15),
            _miniStat("QTY", q), 
            _miniStat("FREE", f),
            Text("₹${t.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.teal)),
          ]),
        )
      ]),
    );
  }

  Widget _itemTable(List<Map<String, dynamic>> items) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 15, headingRowHeight: 35, dataRowHeight: 35,
        columns: const [
          DataColumn(label: Text("PRODUCT", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
          DataColumn(label: Text("QTY", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
          DataColumn(label: Text("FREE", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
          DataColumn(label: Text("TOTAL", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
        ],
        rows: items.map((it) => DataRow(cells: [
          DataCell(Text(it['name'], style: const TextStyle(fontSize: 10))),
          DataCell(Text(it['qty'].toStringAsFixed(2))),
          DataCell(Text(it['free'].toStringAsFixed(2))),
          DataCell(Text(it['total'].toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold))),
        ])).toList(),
      ),
    );
  }

  Widget _buildGrandTotalBar(Map<String, List<Map<String, dynamic>>> data, List<String> filteredKeys) {
    double grandTotal = 0;
    for (var key in filteredKeys) { 
      grandTotal += data[key]!.fold(0, (s, e) => s + e['total']); 
    }
    return Container(
      padding: const EdgeInsets.all(20), color: Colors.teal.shade900,
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text("GRAND TOTAL", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
        Text("₹${grandTotal.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
      ]),
    );
  }

  Widget _miniStat(String l, double v) => Padding(
    padding: const EdgeInsets.only(right: 15), 
    child: Column(children: [
      Text(l, style: const TextStyle(fontSize: 7, color: Colors.grey)), 
      Text(v.toStringAsFixed(2), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))
    ])
  );

  Widget _dateTile(String l, DateTime d, Function(DateTime) onPick, String fy) => InkWell(
    onTap: () async { 
      DateTime? p = await PharoahDateController.pickDate(context: context, currentFY: fy, initialDate: d); 
      if (p != null) onPick(p); 
    }, 
    child: Container(
      padding: const EdgeInsets.all(10), 
      decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(8)), 
      child: Text("$l: ${DateFormat('dd/MM').format(d)}", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))
    )
  );
}
