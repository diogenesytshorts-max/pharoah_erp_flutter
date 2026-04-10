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
    List<Sale> mSales = ph.sales.where((s) => s.status == "Active" && s.date.month == selectedDate.month && s.date.year == selectedDate.year).toList();
    List<Purchase> mPurchases = ph.purchases.where((p) => p.date.month == selectedDate.month && p.date.year == selectedDate.year).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: Text(widget.reportType), backgroundColor: Colors.indigo.shade800, foregroundColor: Colors.white,
        actions: [
          // Button 1: PDF Export
          IconButton(icon: const Icon(Icons.picture_as_pdf), tooltip: "Export PDF", 
            onPressed: () => PdfService.generateGstReport("${widget.reportType}", mSales, mPurchases, DateFormat('MMYYYY').format(selectedDate))),
          
          // Button 2: JSON Export (For GSTR-1)
          if (widget.reportType.contains("GSTR-1"))
            IconButton(icon: const Icon(Icons.code), tooltip: "Export JSON for Portal", 
              onPressed: () => PdfService.generateGstJson(mSales, DateFormat('MMYYYY').format(selectedDate))),
        ],
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
        const Text("Reporting Period:", style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildGstr1View(List<Sale> sales) {
    List<Sale> b2b = sales.where((s) => s.invoiceType == "B2B").toList();
    List<Sale> b2c = sales.where((s) => s.invoiceType == "B2C").toList();
    return Expanded(
      child: DefaultTabController(length: 2, child: Column(children: [
        const TabBar(labelColor: Colors.indigo, tabs: [Tab(text: "B2B (Tax)"), Tab(text: "B2C (Retail)")]),
        Expanded(child: TabBarView(children: [_list(b2b), _list(b2c)]))
      ])),
    );
  }

  Widget _buildGstr2View(List<Purchase> purchases) {
    return Expanded(child: ListView.builder(itemCount: purchases.length, itemBuilder: (c, i) => Card(margin: const EdgeInsets.all(8), child: ListTile(title: Text(purchases[i].distributorName), subtitle: Text("Bill: ${purchases[i].billNo}"), trailing: Text("₹${purchases[i].totalAmount.toStringAsFixed(2)}")))));
  }

  Widget _buildGstr3BView(List<Sale> sales, List<Purchase> purchases) {
    double saleTax = 0; sales.forEach((s) => s.items.forEach((it) => saleTax += (it.cgst + it.sgst + it.igst)));
    double purTax = 0; purchases.forEach((p) => p.items.forEach((it) => purTax += (it.purchaseRate * it.qty * it.gstRate / 100)));
    return Expanded(child: ListView(padding: const EdgeInsets.all(15), children: [
      _card("3.1 Outward Supplies", saleTax, Colors.green),
      _card("4.0 Eligible ITC", purTax, Colors.orange),
      const SizedBox(height: 20),
      Center(child: Text("NET PAYABLE: ₹${(saleTax - purTax).toStringAsFixed(2)}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red))),
    ]));
  }

  Widget _list(List<Sale> list) {
    return ListView.builder(itemCount: list.length, itemBuilder: (c, i) => ListTile(title: Text(list[i].partyName), subtitle: Text(list[i].billNo), trailing: Text("₹${list[i].totalAmount.toStringAsFixed(2)}")));
  }

  Widget _card(String t, double v, Color c) {
    return Card(child: ListTile(title: Text(t), trailing: Text("₹${v.toStringAsFixed(2)}", style: TextStyle(color: c, fontWeight: FontWeight.bold))));
  }
}
