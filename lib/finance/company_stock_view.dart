// FILE: lib/finance/company_stock_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import 'stock_flow_engine.dart';
import '../pharoah_date_controller.dart';
import '../app_date_logic.dart';
import '../../pdf/statements/company_stock_pdf.dart';
import '../pdf/pdf_router_service.dart';

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
        backgroundColor: const Color(0xFF1E1B4B),
        foregroundColor: Colors.white,
        actions: [
          // --- 📬 SMART DISPATCH (MAIL) ---
          if (ph.config.isMailActive) 
            IconButton(
              icon: Icon(
                ph.config.isAuditMode ? Icons.forward_to_inbox_rounded : Icons.alternate_email,
                color: Colors.white,
              ),
              tooltip: ph.config.isAuditMode ? "Forward to CA (Auditor)" : "Send to My Mail",
              onPressed: () {
                PdfRouterService.emailDocument(
                  context: context,
                  doc: {'grouped': grouped, 'from': fromDate, 'to': toDate, 'basis': valuationBasis},
                  party: Party(id: 'internal', name: ph.config.isAuditMode ? 'Audit Analysis' : 'Party Stock Analysis'),
                  ph: ph, type: "STOCK",
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf), 
            onPressed: () async {
              await CompanyStockPdf.generate(
                shop: ph.activeCompany!, groupedData: grouped, from: fromDate, to: toDate,
                valuationBasis: valuationBasis, ph: ph
              );
            }
          )
        ],
      ),
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
    padding: const EdgeInsets.all(15), color: const Color(0xFF1E1B4B),
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
        ButtonSegment(value: 'PURCHASE', label: Text('PURCHASE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
        ButtonSegment(value: 'SALE', label: Text('SALE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
        ButtonSegment(value: 'MRP', label: Text('MRP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
      ],
      selected: {valuationBasis},
      onSelectionChanged: (v) => setState(() => valuationBasis = v.first),
    ),
  );

  Widget _buildCompanyCard(String name, List<Medicine> meds, PharoahManager ph) {
    // Totals accumulation for this company group
    double totalOpStock = 0; double totalOpVal = 0;
    double totalRecQty = 0; double totalRecVal = 0;
    double totalIssueQty = 0; double totalIssueVal = 0;
    double totalCloStock = 0; double totalCloVal = 0;

    // First, pre-calculate totals across all items
    for (var m in meds) {
      final flow = StockFlowEngine.getItemFlow(med: m, from: fromDate, to: toDate, ph: ph);
      double rate = (valuationBasis == "PURCHASE") ? m.purRate : (valuationBasis == "SALE" ? m.rateA : m.mrp);
      
      double opStock = (flow['opening'] ?? 0.0);
      double recQty = (flow['received'] ?? 0.0);
      double issueQty = (flow['sale'] ?? 0.0);
      double cloStock = (flow['closing'] ?? 0.0);

      totalOpStock += opStock; totalOpVal += (opStock * rate);
      totalRecQty += recQty; totalRecVal += (recQty * rate);
      totalIssueQty += issueQty; totalIssueVal += (issueQty * rate);
      totalCloStock += cloStock; totalCloVal += (cloStock * rate);
    }

    return Card(
      margin: const EdgeInsets.all(10),
      child: ExpansionTile(
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E1B4B))),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              width: 950, // Perfect precise layout
              padding: const EdgeInsets.all(10),
              child: Table(
                columnWidths: const {
                  0: FixedColumnWidth(180), // Description
                  1: FixedColumnWidth(60),  // Unit/Packing
                  2: FixedColumnWidth(80),  // Open Stock
                  3: FixedColumnWidth(100), // Open Value
                  4: FixedColumnWidth(80),  // Rec Qty
                  5: FixedColumnWidth(100), // Rec Value
                  6: FixedColumnWidth(80),  // Issue Qty
                  7: FixedColumnWidth(100), // Issue Value
                  8: FixedColumnWidth(80),  // Close Stock
                  9: FixedColumnWidth(100), // Close Value
                },
                border: TableBorder.all(color: const Color(0xFFE2E8F0), width: 1),
                children: [
                  // 1. Column Header
                  TableRow(
                    decoration: const BoxDecoration(color: Color(0xFF2E2B6B)),
                    children: [
                      _th("PRODUCT DESCRIPTION", isLeft: true),
                      _th("UNIT"),
                      _th("OPENING\nSTOCK"),
                      _th("OPENING\nVALUE (₹)"),
                      _th("RECEIVE\nQUANTITY"),
                      _th("RECEIVE\nVALUE (₹)"),
                      _th("ISSUE\nQUANTITY"),
                      _th("ISSUE\nVALUE (₹)"),
                      _th("CLOSING\nSTOCK"),
                      _th("CLOSING\nVALUE (₹)"),
                    ],
                  ),

                  // 2. Data Rows
                  ...meds.asMap().entries.map((entry) {
                    int index = entry.key;
                    var m = entry.value;
                    bool isShaded = index % 2 != 0;

                    final flow = StockFlowEngine.getItemFlow(med: m, from: fromDate, to: toDate, ph: ph);
                    double rate = (valuationBasis == "PURCHASE") ? m.purRate : (valuationBasis == "SALE" ? m.rateA : m.mrp);

                    double opStock = (flow['opening'] ?? 0.0);
                    double recQty = (flow['received'] ?? 0.0);
                    double issueQty = (flow['sale'] ?? 0.0);
                    double cloStock = (flow['closing'] ?? 0.0);

                    return TableRow(
                      decoration: BoxDecoration(
                        color: isShaded ? const Color(0xFFF8FAFC) : Colors.white,
                      ),
                      children: [
                        _td(m.name, isLeft: true, isBold: true),
                        _td(m.packing),
                        _td(opStock.toInt().toString()),
                        _td((opStock * rate).toStringAsFixed(2)),
                        _td(recQty.toInt().toString()),
                        _td((recQty * rate).toStringAsFixed(2)),
                        _td(issueQty.toInt().toString()),
                        _td((issueQty * rate).toStringAsFixed(2)),
                        _td(cloStock.toInt().toString(), textColor: const Color(0xFF059669)),
                        _td((cloStock * rate).toStringAsFixed(2), textColor: const Color(0xFF059669)),
                      ],
                    );
                  }).toList(),

                  // 3. Totals Row
                  TableRow(
                    decoration: const BoxDecoration(color: Color(0xFFECFDF5)),
                    children: [
                      _td("TOTAL", isLeft: true, isBold: true, textColor: const Color(0xFF047857)),
                      _td("-", isBold: true),
                      _td(totalOpStock.toInt().toString(), isBold: true, textColor: const Color(0xFF047857)),
                      _td("₹${totalOpVal.toStringAsFixed(2)}", isBold: true, textColor: const Color(0xFF047857)),
                      _td(totalRecQty.toInt().toString(), isBold: true, textColor: const Color(0xFF047857)),
                      _td("₹${totalRecVal.toStringAsFixed(2)}", isBold: true, textColor: const Color(0xFF047857)),
                      _td(totalIssueQty.toInt().toString(), isBold: true, textColor: const Color(0xFF047857)),
                      _td("₹${totalIssueVal.toStringAsFixed(2)}", isBold: true, textColor: const Color(0xFF047857)),
                      _td(totalCloStock.toInt().toString(), isBold: true, textColor: const Color(0xFF047857)),
                      _td("₹${totalCloVal.toStringAsFixed(2)}", isBold: true, textColor: const Color(0xFF047857)),
                    ],
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _th(String text, {bool isLeft = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      alignment: isLeft ? Alignment.centerLeft : Alignment.center,
      child: Text(
        text,
        textAlign: isLeft ? TextAlign.left : TextAlign.center,
        style: const TextStyle(fontSize: 8.0, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5),
      ),
    );
  }

  Widget _td(String text, {bool isLeft = false, bool isBold = false, Color? textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      alignment: isLeft ? Alignment.centerLeft : Alignment.center,
      child: Text(
        text,
        textAlign: isLeft ? TextAlign.left : TextAlign.center,
        style: TextStyle(fontSize: 9.0, fontWeight: isBold ? FontWeight.w900 : FontWeight.bold, color: textColor ?? const Color(0xFF1E293B)),
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
