// FILE: lib/gst_report_detail_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'gst_report_service.dart';

class GSTReportDetailView extends StatefulWidget {
  final String reportType;
  const GSTReportDetailView({super.key, required this.reportType});

  @override
  State<GSTReportDetailView> createState() => _GSTReportDetailViewState();
}

class _GSTReportDetailViewState extends State<GSTReportDetailView> {
  DateTime fromDate = DateTime.now();
  DateTime toDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Default: Current Month 1st to Today
    final now = DateTime.now();
    fromDate = DateTime(now.year, now.month, 1);
    toDate = now;
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    final activeShop = ph.activeCompany;

    // --- FILTERING LOGIC (ORIGINAL) ---
    List<Sale> allSales = ph.sales.where((s) =>
      s.date.isAfter(fromDate.subtract(const Duration(days: 1))) && 
      s.date.isBefore(toDate.add(const Duration(days: 1)))
    ).toList();
    
    List<Sale> activeSales = allSales.where((s) => s.status == "Active").toList();

    List<Purchase> monthlyPurchases = ph.purchases.where((p) =>
      p.date.isAfter(fromDate.subtract(const Duration(days: 1))) && 
      p.date.isBefore(toDate.add(const Duration(days: 1)))
    ).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.reportType),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: "Download PDF Report",
            onPressed: (activeShop == null) ? null : () {
              String rangeLabel = "${DateFormat('dd/MM/yy').format(fromDate)} to ${DateFormat('dd/MM/yy').format(toDate)}";
              
              // NAYA: Passing 'activeShop' to all PDF calls
              if (widget.reportType.contains("GSTR-1")) {
                GstReportService.generateGstr1Pdf(allSales, rangeLabel, activeShop);
              } 
              else if (widget.reportType.contains("GSTR-3B")) {
                GstReportService.generateGstr3bPdf(activeSales, monthlyPurchases, rangeLabel, activeShop);
              }
              else if (widget.reportType.contains("GSTR-2")) {
                GstReportService.generateGstr2Pdf(monthlyPurchases, ph.vouchers, ph.parties, rangeLabel, activeShop);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildDateRangePicker(),
          if (widget.reportType.contains("GSTR-1")) 
            _buildGstr1Tabs(activeSales, allSales)
          else if (widget.reportType.contains("GSTR-2")) 
            _buildGstr2Preview(monthlyPurchases)
          else 
            _build3bPreview(activeSales, monthlyPurchases)
        ],
      ),
    );
  }

  // --- UI COMPONENTS (ORIGINAL) ---

  Widget _buildDateRangePicker() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Expanded(child: _dateTile("FROM DATE", fromDate, (d) => setState(() => fromDate = d))),
          const SizedBox(width: 10),
          Expanded(child: _dateTile("TO DATE", toDate, (d) => setState(() => toDate = d))),
        ],
      ),
    );
  }

  Widget _dateTile(String label, DateTime date, Function(DateTime) onPick) {
    return InkWell(
      onTap: () async {
        DateTime? picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) onPick(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.indigo.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(DateFormat('dd/MM/yyyy').format(date), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo)),
                const Icon(Icons.calendar_month, size: 14, color: Colors.indigo),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGstr1Tabs(List<Sale> active, List<Sale> all) {
    return Expanded(
      child: DefaultTabController(
        length: 4,
        child: Column(
          children: [
            const TabBar(
              isScrollable: true,
              labelColor: Colors.indigo,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.indigo,
              tabs: [Tab(text: "B2B"), Tab(text: "B2C"), Tab(text: "HSN"), Tab(text: "DOCS")],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _table(active.where((s) => s.invoiceType == "B2B").toList(), true),
                  _table(active.where((s) => s.invoiceType == "B2C").toList(), false),
                  _hsnTable(active),
                  _docTable(all),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildGstr2Preview(List<Purchase> purchases) {
    return Expanded(
      child: ListView(
        padding: const EdgeInsets.all(15),
        children: [
          _summaryCard("Bills in Range", purchases.length.toDouble(), Colors.orange, isInt: true),
          _summaryCard("Range Pur. Value", purchases.fold(0.0, (sum, p) => sum + p.totalAmount), Colors.deepOrange),
          const Divider(height: 40),
          const Center(child: Text("Purchase Inward Details", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))),
          const SizedBox(height: 10),
          ...purchases.map((p) => ListTile(
            title: Text(p.distributorName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Bill: ${p.billNo} | Date: ${DateFormat('dd/MM/yy').format(p.date)}"),
            trailing: Text("₹${p.totalAmount.toStringAsFixed(2)}"),
          )).toList(),
        ],
      ),
    );
  }

  Widget _build3bPreview(List<Sale> sales, List<Purchase> purchases) {
    return Expanded(
      child: ListView(
        padding: const EdgeInsets.all(15),
        children: [
          _summaryCard("Taxable Outward (Sales)", sales.fold(0.0, (sum, s) => sum + s.totalAmount), Colors.green),
          const SizedBox(height: 10),
          _summaryCard("Eligible ITC (Purchases)", purchases.fold(0.0, (sum, p) => sum + p.totalAmount), Colors.orange),
          const Divider(height: 40),
          const Center(child: Text("Use PDF icon for full 3B computation", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))),
        ],
      ),
    );
  }

  Widget _summaryCard(String t, double v, Color c, {bool isInt = false}) {
    return Card(
      elevation: 0,
      color: c.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: c.withOpacity(0.2))),
      child: ListTile(
        title: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        trailing: Text(
          isInt ? v.toInt().toString() : "₹${v.toStringAsFixed(2)}",
          style: TextStyle(fontWeight: FontWeight.w900, color: c, fontSize: 16),
        ),
      ),
    );
  }

  Widget _table(List<Sale> list, bool b2b) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 25,
        columns: [
          const DataColumn(label: Text('DATE')),
          const DataColumn(label: Text('BILL')),
          const DataColumn(label: Text('PARTY')),
          if (b2b) const DataColumn(label: Text('GSTIN')),
          const DataColumn(label: Text('TOTAL'))
        ],
        rows: list.map((s) => DataRow(cells: [
          DataCell(Text(DateFormat('dd/MM').format(s.date))),
          DataCell(Text(s.billNo)),
          DataCell(Text(s.partyName.length > 15 ? "${s.partyName.substring(0, 15)}.." : s.partyName)),
          if (b2b) DataCell(Text(s.partyGstin)),
          DataCell(Text(s.totalAmount.toStringAsFixed(2)))
        ])).toList(),
      ),
    );
  }

  Widget _hsnTable(List<Sale> sales) {
    Map<String, double> hsn = {};
    for (var s in sales) {
      for (var it in s.items) {
        hsn[it.hsn] = (hsn[it.hsn] ?? 0) + it.total;
      }
    }
    return ListView(
      children: hsn.entries.map((e) => ListTile(
        title: Text("HSN: ${e.key}"),
        trailing: Text("₹${e.value.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
      )).toList(),
    );
  }

  Widget _docTable(List<Sale> all) {
    return Column(
      children: [
        ListTile(title: const Text("Total Invoices Issued"), trailing: Text("${all.length}", style: const TextStyle(fontWeight: FontWeight.bold))),
        ListTile(title: const Text("Cancelled Invoices"), trailing: Text("${all.where((s) => s.status == "Cancelled").length}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red))),
      ],
    );
  }
}
