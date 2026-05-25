import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import 'stock_flow_engine.dart';
import '../pharoah_date_controller.dart';
import '../app_date_logic.dart';
import '../../pdf/statements/company_stock_pdf.dart';

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
  backgroundColor: ...,
  appBar: AppBar(
    title: const Text("Company Stock Flow"),
    backgroundColor: Colors.purple.shade900,
    actions: [
          // 📧 NAYA: EMAIL ICON FOR COMPANY STOCK REPORT
          if (ph.config.isEmailActive)
            IconButton(
              icon: const Icon(Icons.alternate_email),
              tooltip: "Email Stock Flow Report",
              onPressed: () {
                PdfRouterService.emailDocument(
                  context: context,
                  doc: {
                    'grouped': grouped,
                    'from': fromDate,
                    'to': toDate,
                    'basis': valuationBasis
                  },
                  party: Party(id: 'internal', name: 'Internal Stock Audit'), // Dummy party for Quick Add
                  ph: ph,
                  type: "STOCK",
                );
              },
            ),

          IconButton(
            icon: const Icon(Icons.picture_as_pdf), 
            onPressed: () async {
              await CompanyStockPdf.generate(
                shop: ph.activeCompany!,
                groupedData: grouped,
                from: fromDate,
                to: toDate,
                valuationBasis: valuationBasis,
                ph: ph
              );
            }
          )
        ],
      body: Column(children: [
        _buildTopFilterBar(ph),
        _buildValuationDrag(),
        Expanded(
          child: ListView.builder(
            itemCount: grouped.length,
            itemBuilder: (c, i) {
              String companyName = grouped.keys.elementAt(i);
              return _buildCompanyCard(companyName, grouped[companyName]!, ph);
            },
          ),
        ),
      ]),
    );
  }

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
        decoration: InputDecoration(hintText: "Search Brand...", hintStyle: const TextStyle(color: Colors.white54), prefixIcon: const Icon(Icons.search, color: Colors.white), filled: true, fillColor: Colors.white.withOpacity(0.1), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), isDense: true),
        onChanged: (v) => setState(() => companySearch = v),
      )
    ]),
  );

  Widget _buildValuationDrag() => Container(
    padding: const EdgeInsets.all(10), color: Colors.white,
    child: SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'PURCHASE', label: Text('PURCHASE')),
        ButtonSegment(value: 'SALE', label: Text('SALE')),
        ButtonSegment(value: 'MRP', label: Text('MRP')),
      ],
      selected: {valuationBasis},
      onSelectionChanged: (v) => setState(() => valuationBasis = v.first),
    ),
  );

  Widget _buildCompanyCard(String name, List<Medicine> meds, PharoahManager ph) {
    return Card(
      margin: const EdgeInsets.all(10),
      child: ExpansionTile(
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text("NAME")),
                DataColumn(label: Text("OPEN")),
                DataColumn(label: Text("REC")),
                DataColumn(label: Text("SALE")),
                DataColumn(label: Text("CLO")),
              ],
              rows: meds.map((m) {
                final flow = StockFlowEngine.getItemFlow(med: m, from: fromDate, to: toDate, ph: ph);
                return DataRow(cells: [
                  DataCell(Text(m.name, style: const TextStyle(fontSize: 10))),
                  DataCell(Text(flow['opening']!.toStringAsFixed(1))),
                  DataCell(Text(flow['received']!.toStringAsFixed(1))),
                  DataCell(Text(flow['sale']!.toStringAsFixed(1))),
                  DataCell(Text(flow['closing']!.toStringAsFixed(1))),
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
