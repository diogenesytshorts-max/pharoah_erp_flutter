import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'gst_report_service.dart';

class GSTReportDetailView extends StatefulWidget {
  final String reportType;
  const GSTReportDetailView({super.key, required this.reportType});
  @override State<GSTReportDetailView> createState() => _GSTReportDetailViewState();
}

class _GSTReportDetailViewState extends State<GSTReportDetailView> {
  DateTime selectedDate = DateTime.now();

  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    
    // Monthly Sales filtering
    List<Sale> allSales = ph.sales.where((s) => 
      s.date.month == selectedDate.month && s.date.year == selectedDate.year
    ).toList();
    List<Sale> activeSales = allSales.where((s) => s.status == "Active").toList();

    // Monthly Purchases filtering
    List<Purchase> monthlyPurchases = ph.purchases.where((p) => 
      p.date.month == selectedDate.month && p.date.year == selectedDate.year
    ).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.reportType), 
        backgroundColor: Colors.indigo.shade900, 
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf), 
            onPressed: () {
              String period = DateFormat('MMM-yyyy').format(selectedDate);
              
              if (widget.reportType.contains("GSTR-1")) {
                GstReportService.generateGstr1Pdf(allSales, period);
              } 
              else if (widget.reportType.contains("GSTR-3B")) {
                GstReportService.generateGstr3bPdf(activeSales, monthlyPurchases, period);
              }
              // --- GSTR-2 PDF TRIGGER ---
              else if (widget.reportType.contains("GSTR-2")) {
                GstReportService.generateGstr2Pdf(monthlyPurchases, period);
              }
            }
          ),
        ],
      ),
      body: Column(children: [
        _buildMonthHeader(),
        if (widget.reportType.contains("GSTR-1")) _buildGstr1Tabs(activeSales, allSales)
        else if (widget.reportType.contains("GSTR-2")) _buildGstr2Preview(monthlyPurchases)
        else _build3bPreview(activeSales, monthlyPurchases)
      ]),
    );
  }

  Widget _buildMonthHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey.shade100, border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text("SELECT REPORTING PERIOD:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
        InkWell(
          onTap: () async { DateTime? p = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2100)); if (p != null) setState(() => selectedDate = p); }, 
          child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.indigo), borderRadius: BorderRadius.circular(5)), child: Text(DateFormat('MMMM yyyy').format(selectedDate), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)))
        )
      ]),
    );
  }

  Widget _buildGstr1Tabs(List<Sale> active, List<Sale> all) {
    return Expanded(
      child: DefaultTabController(length: 4, child: Column(children: [
        const TabBar(isScrollable: true, labelColor: Colors.indigo, tabs: [Tab(text: "B2B"), Tab(text: "B2C"), Tab(text: "HSN"), Tab(text: "DOCS")]),
        Expanded(child: TabBarView(children: [
          _table(active.where((s) => s.invoiceType == "B2B").toList(), true),
          _table(active.where((s) => s.invoiceType == "B2C").toList(), false),
          _hsnTable(active),
          _docTable(all),
        ]))
      ])),
    );
  }

  // --- GSTR-2 UI PREVIEW ---
  Widget _buildGstr2Preview(List<Purchase> purchases) {
    return Expanded(
      child: ListView(padding: const EdgeInsets.all(15), children: [
        _summaryCard("Total Purchase Records", purchases.length.toDouble(), Colors.orange, isInt: true),
        _summaryCard("Total Purchase Amount", purchases.fold(0.0, (sum, p) => sum + p.totalAmount), Colors.deepOrange),
        const Divider(height: 40),
        const Center(child: Text("Purchase bills for Input Tax Credit (ITC)", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))),
        const SizedBox(height: 10),
        ...purchases.map((p) => ListTile(
          title: Text(p.distributorName, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text("Bill: ${p.billNo} | Date: ${DateFormat('dd/MM/yy').format(p.date)}"),
          trailing: Text("₹${p.totalAmount.toStringAsFixed(2)}"),
        )).toList(),
      ]),
    );
  }

  Widget _build3bPreview(List<Sale> sales, List<Purchase> purchases) {
    return Expanded(
      child: ListView(padding: const EdgeInsets.all(15), children: [
        _summaryCard("Total Outward Supplies (Sales)", sales.fold(0.0, (sum, s) => sum + s.totalAmount), Colors.green),
        const SizedBox(height: 10),
        _summaryCard("Total Inward Supplies (Purchase ITC)", purchases.fold(0.0, (sum, p) => sum + p.totalAmount), Colors.orange),
        const Divider(height: 40),
        const Center(child: Text("Tap PDF icon to generate full 3B Report", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))),
      ]),
    );
  }

  Widget _summaryCard(String t, double v, Color c, {bool isInt = false}) {
    return Card(color: c.withOpacity(0.1), child: ListTile(title: Text(t, style: const TextStyle(fontWeight: FontWeight.bold)), trailing: Text(isInt ? v.toInt().toString() : "₹${v.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.w900, color: c, fontSize: 16))));
  }

  Widget _table(List<Sale> list, bool b2b) {
    return SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
      columns: [
        const DataColumn(label: Text('DATE')), 
        const DataColumn(label: Text('BILL')), 
        const DataColumn(label: Text('PARTY')), 
        if(b2b) const DataColumn(label: Text('GSTIN')), 
        const DataColumn(label: Text('TOTAL'))
      ], 
      rows: list.map((s) => DataRow(cells: [
        DataCell(Text(DateFormat('dd/MM').format(s.date))), 
        DataCell(Text(s.billNo)), 
        DataCell(Text(s.partyName)), 
        if(b2b) DataCell(Text(s.partyGstin)), 
        DataCell(Text(s.totalAmount.toStringAsFixed(2)))
      ])).toList()
    ));
  }

  Widget _hsnTable(List<Sale> sales) {
    Map<String, double> hsn = {}; for (var s in sales) { for (var it in s.items) { hsn[it.hsn] = (hsn[it.hsn] ?? 0) + it.total; } }
    return ListView(children: hsn.entries.map((e) => ListTile(title: Text("HSN: ${e.key}"), trailing: Text("₹${e.value.toStringAsFixed(2)}"))).toList());
  }

  Widget _docTable(List<Sale> all) {
    return Column(children: [
      ListTile(title: const Text("Total Invoices issued"), trailing: Text("${all.length}")), 
      ListTile(title: const Text("Cancelled Invoices"), trailing: Text("${all.where((s)=>s.status=="Cancelled").length}"))
    ]);
  }
}
