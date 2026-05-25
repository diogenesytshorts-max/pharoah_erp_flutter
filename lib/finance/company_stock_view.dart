import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // Naya import zaroori hai
import '../pharoah_manager.dart';
import '../models.dart';
import 'stock_flow_engine.dart';
import '../pharoah_date_controller.dart';
import '../app_date_logic.dart';
import '../../pdf/statements/company_stock_pdf.dart'; // 🔥 Connection

class CompanyStockView extends StatefulWidget {
  const CompanyStockView({super.key});
  @override State<CompanyStockView> createState() => _CompanyStockViewState();
}

class _CompanyStockViewState extends State<CompanyStockView> {
  DateTime fromDate = DateTime.now();
  DateTime toDate = DateTime.now();
  String valuationBasis = "PURCHASE"; 
  String companySearch = "";

  @override
  void initState() {
    super.initState();
    final ph = Provider.of<PharoahManager>(context, listen: false);
    toDate = AppDateLogic.getSmartDate(ph.currentFY);
    fromDate = DateTime(toDate.year, toDate.month, 1);
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    
    Map<String, List<Medicine>> grouped = {};
    for (var med in ph.medicines) {
      String cName = ph.companies.firstWhere((c) => c.id == med.companyId, orElse: () => Company(id: '', name: 'OTHERS')).name;
      if (cName.toLowerCase().contains(companySearch.toLowerCase())) {
        if (!grouped.containsKey(cName)) grouped[cName] = [];
        grouped[cName]!.add(med);
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        title: const Text("Company Stock Flow"),
        backgroundColor: Colors.purple.shade900,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf), 
            onPressed: () async {
              // 1. Wahi data nikalna jo screen par dikh raha hai
              Map<String, List<Medicine>> currentGrouped = {};
              for (var med in ph.medicines) {
                String cName = ph.companies.firstWhere((c) => c.id == med.companyId, orElse: () => Company(id: '', name: 'OTHERS')).name;
                if (cName.toLowerCase().contains(companySearch.toLowerCase())) {
                  if (!currentGrouped.containsKey(cName)) currentGrouped[cName] = [];
                  currentGrouped[cName]!.add(med);
                }
              }

              // 2. Landscape PDF Generator ko call karna
              await CompanyStockPdf.generate(
                shop: ph.activeCompany!,
                groupedData: currentGrouped,
                from: fromDate,
                to: toDate,
                valuationBasis: valuationBasis,
                ph: ph
              );
            }
          )
        ],
      ),
  // --- HELPERS (Build se bahar rakhein) ---

  Widget _buildTopFilterBar(PharoahManager ph) => Container(
    padding: const EdgeInsets.all(15), color: Colors.purple.shade900,
    child: Column(children: [
      Row(children: [
        Expanded(child: _dateTile("FROM", fromDate, (d) => setState(() => fromDate = d), ph.currentFY)),
        const SizedBox(width: 10),
        Expanded(child: _dateTile("TO", toDate, (d) => setState(() => toDate = d), ph.currentFY)),
      ]),
      const SizedBox(height: 10),
      TextField(
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(hintText: "Filter by Company Name...", hintStyle: const TextStyle(color: Colors.white54), prefixIcon: const Icon(Icons.search, color: Colors.white), filled: true, fillColor: Colors.white.withOpacity(0.1), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
        onChanged: (v) => setState(() => companySearch = v),
      )
    ]),
  );

  Widget _buildValuationDrag() => Container(
    padding: const EdgeInsets.all(10), color: Colors.white,
    child: SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'PURCHASE', label: Text('PURCHASE'), icon: Icon(Icons.shopping_bag)),
        ButtonSegment(value: 'SALE', label: Text('SALE RATE'), icon: Icon(Icons.sell)),
        ButtonSegment(value: 'MRP', label: Text('MRP'), icon: Icon(Icons.tag)),
      ],
      selected: {valuationBasis},
      onSelectionChanged: (v) => setState(() => valuationBasis = v.first),
    ),
  );

  Widget _buildCompanyCard(String name, List<Medicine> meds, PharoahManager ph) {
    double totalVal = 0;
    for (var m in meds) {
      double rate = (valuationBasis == "PURCHASE") ? m.purRate : (valuationBasis == "SALE" ? m.rateA : m.mrp);
      totalVal += (m.stock * rate);
    }
    return Card(
      margin: const EdgeInsets.all(10),
      child: ExpansionTile(
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("Items: ${meds.length} | Net Value: ₹${totalVal.toStringAsFixed(0)}", style: const TextStyle(fontSize: 11, color: Colors.purple)),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 20,
              columns: const [
                DataColumn(label: Text("MEDICINE NAME", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                DataColumn(label: Text("OPENING", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                DataColumn(label: Text("RECEIVED", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                DataColumn(label: Text("SALE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                DataColumn(label: Text("CLOSING", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
              ],
              rows: meds.map((m) {
                final flow = StockFlowEngine.getItemFlow(med: m, from: fromDate, to: toDate, ph: ph);
                return DataRow(cells: [
                  DataCell(Text(m.name, style: const TextStyle(fontSize: 10))),
                  DataCell(Text(flow['opening']!.toStringAsFixed(2))),
                  DataCell(Text(flow['received']!.toStringAsFixed(2), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                  DataCell(Text(flow['sale']!.toStringAsFixed(2), style: const TextStyle(color: Colors.red))),
                  DataCell(Text(flow['closing']!.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold))),
                ]);
              }).toList(),
            ),
          )
        ],
      ),
    );
  }

  Widget _dateTile(String l, DateTime d, Function(DateTime) onPick, String fy) => InkWell(
    onTap: () async {
      DateTime? p = await PharoahDateController.pickDate(context: context, currentFY: fy, initialDate: d);
      if (p != null) onPick(p);
    },
    child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(8)), child: Text("$l: ${DateFormat('dd/MM').format(d)}", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
  );
}
