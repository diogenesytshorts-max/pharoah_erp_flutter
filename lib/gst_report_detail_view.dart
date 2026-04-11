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
    
    // Monthly Filtering
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
          // Export PDF Button
          IconButton(
            icon: const Icon(Icons.picture_as_pdf), 
            tooltip: "Export PDF",
            onPressed: () => PdfService.generateGstReport(widget.reportType, allSales, DateFormat('MMMM-yyyy').format(selectedDate))
          ),
          // Export JSON Button (Only for GSTR-1)
          if (widget.reportType.contains("GSTR-1"))
            IconButton(
              icon: const Icon(Icons.code), 
              tooltip: "Export JSON",
              onPressed: () => PdfService.generateGstJson(allSales, DateFormat('MMYYYY').format(selectedDate))
            ),
        ],
      ),
      body: Column(
        children: [
          _buildMonthHeader(),
          if (widget.reportType.contains("GSTR-1"))
            _buildGstr1DetailedTabs(activeSales, allSales)
          else if (widget.reportType.contains("GSTR-2"))
            _buildGstr2View(mPurchases)
          else if (widget.reportType.contains("GSTR-3B"))
            _buildGstr3BView(activeSales, mPurchases),
        ],
      ),
    );
  }

  // --- HEADER: PERIOD SELECTOR ---
  Widget _buildMonthHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey.shade100, border: const Border(bottom: BorderSide(color: Colors.divider))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("GST REPORTING PERIOD:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blueGrey)),
          InkWell(
            onTap: () async {
              DateTime? p = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (p != null) setState(() => selectedDate = p);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.indigo), borderRadius: BorderRadius.circular(5)),
              child: Text(DateFormat('MMMM yyyy').format(selectedDate), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
            ),
          ),
        ],
      ),
    );
  }

  // --- GSTR-1: MARG STYLE TABS & TABLES ---
  Widget _buildGstr1DetailedTabs(List<Sale> active, List<Sale> all) {
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
                  Tab(text: "B2B (Table 4)"),
                  Tab(text: "B2C (Table 7)"),
                  Tab(text: "HSN (Table 12)"),
                  Tab(text: "DOCS (Table 13)"),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildSalesTable(active.where((s) => s.invoiceType == "B2B").toList(), true),
                  _buildSalesTable(active.where((s) => s.invoiceType == "B2C").toList(), false),
                  _buildHsnSummaryTable(active),
                  _buildDocumentSummaryView(all),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // --- REUSABLE DATA TABLE FOR SALES (HORIZONTAL SCROLL) ---
  Widget _buildSalesTable(List<Sale> list, bool showGstin) {
    if (list.isEmpty) return const Center(child: Text("No transactions in this category."));
    
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(Colors.blueGrey.shade800),
          headingTextStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          columnSpacing: 20,
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
            double taxable = s.totalAmount / 1.12; // Example calculation
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

  // --- HSN SUMMARY TABLE ---
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

  // --- DOCUMENT SUMMARY VIEW ---
  Widget _buildDocumentSummaryView(List<Sale> all) {
    int total = all.length;
    int cancelled = all.where((s) => s.status == "Cancelled").length;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _summaryRow("Total Invoices Issued", total.toString(), Colors.black),
          _summaryRow("Cancelled Invoices", cancelled.toString(), Colors.red),
          const Divider(height: 30),
          _summaryRow("Net Valid Invoices", (total - cancelled).toString(), Colors.green, isBold: true),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, Color col, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: col)),
        ],
      ),
    );
  }

  // --- GSTR-2: PURCHASE REGISTER ---
  Widget _buildGstr2View(List<Purchase> purchases) {
    return Expanded(
      child: ListView.builder(
        itemCount: purchases.length,
        itemBuilder: (c, i) => Card(
          margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
          child: ListTile(
            title: Text(purchases[i].distributorName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Bill: ${purchases[i].billNo} | Date: ${DateFormat('dd/MM/yy').format(purchases[i].date)}"),
            trailing: Text("₹${purchases[i].totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
          ),
        ),
      ),
    );
  }

  // --- GSTR-3B: SUMMARY ---
  Widget _buildGstr3BView(List<Sale> sales, List<Purchase> purchases) {
    double saleTax = 0; sales.forEach((s) => s.items.forEach((it) => saleTax += (it.cgst + it.sgst + it.igst)));
    double purTax = 0; purchases.forEach((p) => p.items.forEach((it) => purTax += (it.purchaseRate * it.qty * it.gstRate / 100)));

    return Expanded(
      child: ListView(
        padding: const EdgeInsets.all(15),
        children: [
          _statCard("3.1 Outward Taxable Supplies", saleTax, Colors.green),
          const SizedBox(height: 10),
          _statCard("4.0 Eligible ITC (Purchases)", purTax, Colors.orange),
          const SizedBox(height: 25),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.indigo, width: 2)),
            child: Column(children: [
              const Text("NET TAX PAYABLE / (REFUNDABLE)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Text("₹${(saleTax - purTax).toStringAsFixed(2)}", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: (saleTax - purTax) > 0 ? Colors.red : Colors.green)),
            ]),
          )
        ],
      ),
    );
  }

  Widget _statCard(String t, double v, Color c) {
    return Card(
      elevation: 2,
      child: ListTile(
        title: Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        trailing: Text("₹${v.toStringAsFixed(2)}", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c)),
      ),
    );
  }
}
