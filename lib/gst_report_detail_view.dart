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
    
    // Filter Data by Month
    List<Sale> mSales = ph.sales.where((s) => s.status == "Active" && s.date.month == selectedDate.month && s.date.year == selectedDate.year).toList();
    List<Purchase> mPurchases = ph.purchases.where((p) => p.date.month == selectedDate.month && p.date.year == selectedDate.year).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: Text(widget.reportType), backgroundColor: Colors.indigo.shade800, foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: () => _generateGstPdf(mSales, mPurchases))],
      ),
      body: Column(
        children: [
          _buildMonthHeader(),
          if (widget.reportType.contains("GSTR-1")) _buildGstr1View(mSales)
          else if (widget.reportType.contains("GSTR-2")) _buildGstr2View(mPurchases)
          else if (widget.reportType.contains("GSTR-3B")) _buildGstr3BView(mSales, mPurchases),
        ],
      ),
    );
  }

  Widget _buildMonthHeader() {
    return Container(
      padding: const EdgeInsets.all(15), color: Colors.white,
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text("Tax Period:", style: TextStyle(fontWeight: FontWeight.bold)),
        InkWell(
          onTap: () async {
            DateTime? p = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2100));
            if (p != null) setState(() => selectedDate = p);
          },
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(8)),
            child: Text(DateFormat('MMMM yyyy').format(selectedDate), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo))),
        ),
      ]),
    );
  }

  // --- GSTR-1: SALES VIEW (B2B / B2C / HSN) ---
  Widget _buildGstr1View(List<Sale> sales) {
    List<Sale> b2b = sales.where((s) => s.invoiceType == "B2B").toList();
    List<Sale> b2c = sales.where((s) => s.invoiceType == "B2C").toList();

    return Expanded(
      child: DefaultTabController(
        length: 3,
        child: Column(children: [
          const TabBar(labelColor: Colors.indigo, tabs: [Tab(text: "B2B"), Tab(text: "B2C"), Tab(text: "HSN SUM")]),
          Expanded(child: TabBarView(children: [
            _list(b2b, "Registered Sales"),
            _list(b2c, "Consumer Sales"),
            _hsnSummary(sales),
          ])),
        ]),
      ),
    );
  }

  // --- GSTR-2: PURCHASE & RECONCILIATION ---
  Widget _buildGstr2View(List<Purchase> purchases) {
    return Expanded(
      child: ListView.builder(
        itemCount: purchases.length,
        itemBuilder: (c, i) {
          final p = purchases[i];
          bool isMatched = p.gstStatus == "Matched";
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            color: isMatched ? Colors.green.shade50 : Colors.red.shade50,
            child: ListTile(
              leading: Icon(Icons.circle, color: isMatched ? Colors.green : Colors.red, size: 12),
              title: Text(p.distributorName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("Bill: ${p.billNo} | Status: ${p.gstStatus}"),
              trailing: Text("₹${p.totalAmount.toStringAsFixed(2)}", style: TextStyle(color: isMatched ? Colors.green.shade900 : Colors.red.shade900, fontWeight: FontWeight.bold)),
            ),
          );
        },
      ),
    );
  }

  // --- GSTR-3B: SUMMARY FORMAT ---
  Widget _buildGstr3BView(List<Sale> sales, List<Purchase> purchases) {
    double saleTax = 0; sales.forEach((s) => s.items.forEach((it) => saleTax += (it.cgst + it.sgst + it.igst)));
    double purTax = 0; purchases.forEach((p) => p.items.forEach((it) => purTax += (it.purchaseRate * it.qty * it.gstRate / 100)));

    return Expanded(
      child: ListView(padding: const EdgeInsets.all(15), children: [
        _margTable("3.1 Outward Taxable Supplies (Sales)", saleTax, Colors.green),
        const SizedBox(height: 10),
        _margTable("4. Eligible ITC (Purchases)", purTax, Colors.orange),
        const SizedBox(height: 20),
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.indigo)),
          child: Column(children: [
            const Text("NET GST PAYABLE", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            Text("₹${(saleTax - purTax).toStringAsFixed(2)}", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: (saleTax - purTax) > 0 ? Colors.red : Colors.green)),
          ]),
        )
      ]),
    );
  }

  Widget _list(List<Sale> list, String title) {
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (c, i) => ListTile(
        title: Text(list[i].partyName),
        subtitle: Text("Inv: ${list[i].billNo}"),
        trailing: Text("₹${list[i].totalAmount.toStringAsFixed(2)}"),
      ),
    );
  }

  Widget _hsnSummary(List<Sale> sales) {
    Map<String, double> hsnMap = {};
    for (var s in sales) {
      for (var it in s.items) {
        hsnMap[it.hsn] = (hsnMap[it.hsn] ?? 0) + it.total;
      }
    }
    return ListView(children: hsnMap.entries.map((e) => ListTile(title: Text("HSN: ${e.key}"), trailing: Text("₹${e.value.toStringAsFixed(2)}"))).toList());
  }

  Widget _margTable(String title, double amt, Color col) {
    return Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Text("₹${amt.toStringAsFixed(2)}", style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 16)),
      ]),
    );
  }

  void _generateGstPdf(List<Sale> s, List<Purchase> p) async {
    // PDF trigger logic
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Generating Marg Style PDF Report...")));
  }
}
