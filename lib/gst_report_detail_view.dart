import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'pdf_service.dart';

class GSTReportDetailView extends StatefulWidget {
  final String reportType;
  const GSTReportDetailView({super.key, required this.reportType});

  @override State<GSTReportDetailView> createState() => _GSTReportDetailViewState();
}

class _GSTReportDetailViewState extends State<GSTReportDetailView> {
  DateTime selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    
    // Logic: Filter sales and purchases for the selected month
    List<Sale> allSales = ph.sales.where((s) => 
      s.date.month == selectedDate.month && s.date.year == selectedDate.year
    ).toList();
    
    List<Sale> activeSales = allSales.where((s) => s.status == "Active").toList();
    
    List<Purchase> mPurchases = ph.purchases.where((p) => 
      p.date.month == selectedDate.month && p.date.year == selectedDate.year
    ).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.reportType, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
        actions: [
          // Export PDF Tool
          IconButton(
            icon: const Icon(Icons.picture_as_pdf), 
            tooltip: "Export PDF Report",
            onPressed: () => PdfService.generateGstReport(widget.reportType, allSales, DateFormat('MMMM-yyyy').format(selectedDate))
          ),
          // Export JSON Tool (Specifically for GSTR-1)
          if (widget.reportType.contains("GSTR-1"))
            IconButton(
              icon: const Icon(Icons.code), 
              tooltip: "Export JSON for Portal",
              onPressed: () => PdfService.generateGstJson(allSales, DateFormat('MMYYYY').format(selectedDate))
            ),
        ],
      ),
      body: Column(
        children: [
          _buildMonthHeader(),
          if (widget.reportType.contains("GSTR-1"))
            _buildGstr1DetailedTableView(activeSales, allSales)
          else if (widget.reportType.contains("GSTR-2"))
            _buildGstr2ReconciliationView(mPurchases)
          else if (widget.reportType.contains("GSTR-3B"))
            _buildGstr3BSummaryView(activeSales, mPurchases),
        ],
      ),
    );
  }

  // --- HEADER: MONTH & YEAR SELECTOR ---
  Widget _buildMonthHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey.shade100, border: const Border(bottom: BorderSide(color: Colors.divider))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("REPORTING PERIOD:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blueGrey)),
          InkWell(
            onTap: () async {
              DateTime? p = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (p != null) setState(() => selectedDate = p);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.indigo), borderRadius: BorderRadius.circular(5)),
              child: Text(DateFormat('MMMM yyyy').format(selectedDate), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
            ),
          ),
        ],
      ),
    );
  }

  // --- GSTR-1: TABBED TABLE VIEW (MARG STYLE) ---
  Widget _buildGstr1DetailedTableView(List<Sale> active, List<Sale> all) {
    return Expanded(
      child: DefaultTabController(
        length: 4,
        child: Column(
          children: [
            Container(
              color: Colors.indigo.shade50,
              child: const TabBar(
                isScrollable: true,
                labelColor: Colors.indigo,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.indigo,
                tabs: [
                  Tab(text: "Table 4: B2B"),
                  Tab(text: "Table 7: B2C"),
                  Tab(text: "Table 12: HSN"),
                  Tab(text: "Table 13: DOCS"),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildDataTable(active.where((s) => s.invoiceType == "B2B").toList(), true),  // Registered
                  _buildDataTable(active.where((s) => s.invoiceType == "B2C").toList(), false), // Unregistered
                  _buildHsnSummaryTable(active),
                  _buildDocumentSummaryTable(all),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // --- REUSABLE WIDE DATA TABLE (HORIZONTAL SCROLL) ---
  Widget _buildDataTable(List<Sale> list, bool showGstin) {
    if (list.isEmpty) return const Center(child: Text("No records found for this period."));

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(Colors.blueGrey.shade800),
          headingTextStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          columnSpacing: 25,
          columns: [
            const DataColumn(label: Text('DATE')),
            const DataColumn(label: Text('BILL NO')),
            const DataColumn(label: Text('PARTY NAME')),
            if (showGstin) const DataColumn(label: Text('GSTIN')),
            const DataColumn(label: Text('STATE (POS)')),
            const DataColumn(label: Text('TAXABLE')),
            const DataColumn(label: Text('GST AMT')),
            const DataColumn(label: Text('TOTAL')),
          ],
          rows: list.map((s) {
            double taxable = s.totalAmount / 1.12; // Example tax back-calc
            double gst = s.totalAmount - taxable;
            return DataRow(cells: [
              DataCell(Text(DateFormat('dd/MM').format(s.date))),
              DataCell(Text(s.billNo)),
              DataCell(Text(s.partyName)),
              if (showGstin) DataCell(Text(s.partyGstin)),
              DataCell(Text(s.partyState)),
              DataCell(Text(taxable.toStringAsFixed(2))),
              DataCell(Text(gst.toStringAsFixed(2))),
              DataCell(Text(s.totalAmount.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold))),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  // --- HSN SUMMARY TABLE (TABLE 12) ---
  Widget _buildHsnSummaryTable(List<Sale> sales) {
    Map<String, Map<String, dynamic>> hsnMap = {};
    for (var s in sales) {
      for (var it in s.items) {
        if (!hsnMap.containsKey(it.hsn)) hsnMap[it.hsn] = {'qty': 0.0, 'val': 0.0, 'tax': 0.0};
        hsnMap[it.hsn]!['qty'] += it.qty;
        hsnMap[it.hsn]!['val'] += (it.rate * it.qty);
        hsnMap[it.hsn]!['tax'] += (it.cgst + it.sgst + it.igst);
      }
    }

    return SingleChildScrollView(
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(Colors.teal.shade700),
        headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        columns: const [
          DataColumn(label: Text('HSN CODE')),
          DataColumn(label: Text('QTY')),
          DataColumn(label: Text('TAXABLE VALUE')),
          DataColumn(label: Text('GST AMT')),
        ],
        rows: hsnMap.entries.map((e) => DataRow(cells: [
          DataCell(Text(e.key)),
          DataCell(Text(e.value['qty'].toString())),
          DataCell(Text(e.value['val'].toStringAsFixed(2))),
          DataCell(Text(e.value['tax'].toStringAsFixed(2))),
        ])).toList(),
      ),
    );
  }

  // --- DOCUMENT SUMMARY (TABLE 13) ---
  Widget _buildDocumentSummaryTable(List<Sale> all) {
    int total = all.length;
    int cancelled = all.where((s) => s.status == "Cancelled").length;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _summaryItem("Total Invoices Issued", total.toString(), Colors.black),
          _summaryItem("Cancelled Invoices", cancelled.toString(), Colors.red),
          const Divider(height: 40),
          _summaryItem("Net Valid for Filing", (total - cancelled).toString(), Colors.green, isBold: true),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color col, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: col)),
        ],
      ),
    );
  }

  // --- GSTR-2: PURCHASE LIST ---
  Widget _buildGstr2ReconciliationView(List<Purchase> purchases) {
    return Expanded(
      child: ListView.builder(
        itemCount: purchases.length,
        itemBuilder: (c, i) => Card(
          margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
          child: ListTile(
            title: Text(purchases[i].distributorName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Bill: ${purchases[i].billNo} | Date: ${DateFormat('dd/MM/yy').format(purchases[i].date)}"),
            trailing: Text("₹${purchases[i].totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
          ),
        ),
      ),
    );
  }

  // --- GSTR-3B: SUMMARY VIEW ---
  Widget _buildGstr3BSummaryView(List<Sale> sales, List<Purchase> purchases) {
    double saleTax = 0; sales.forEach((s) => s.items.forEach((it) => saleTax += (it.cgst + it.sgst + it.igst)));
    double purTax = 0; purchases.forEach((p) => p.items.forEach((it) => purTax += (it.purchaseRate * it.qty * it.gstRate / 100)));

    return Expanded(
      child: ListView(
        padding: const EdgeInsets.all(15),
        children: [
          _statBox("3.1 Total Tax Collected (Sales)", saleTax, Colors.green),
          const SizedBox(height: 10),
          _statBox("4.0 Total Tax Paid (ITC)", purTax, Colors.orange),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.indigo, width: 2)),
            child: Column(children: [
              const Text("NET TAX PAYABLE TO GOVT", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const SizedBox(height: 8),
              Text("₹${(saleTax - purTax).toStringAsFixed(2)}", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: (saleTax - purTax) > 0 ? Colors.red : Colors.green)),
            ]),
          )
        ],
      ),
    );
  }

  Widget _statBox(String t, double v, Color c) {
    return Card(
      elevation: 2,
      child: ListTile(
        title: Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        trailing: Text("₹${v.toStringAsFixed(2)}", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c)),
      ),
    );
  }
}
