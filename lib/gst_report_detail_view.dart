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
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf), 
            onPressed: () => PdfService.generateGstReport("${widget.reportType} - ${DateFormat('MMM yyyy').format(selectedDate)}", mSales, mPurchases)
          )
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
        const Text("Select Period:", style: TextStyle(fontWeight: FontWeight.bold)),
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

  // --- GSTR-1: SALES VIEW ---
  Widget _buildGstr1View(List<Sale> sales) {
    List<Sale> b2b = sales.where((s) => s.invoiceType == "B2B").toList();
    List<Sale> b2c = sales.where((s) => s.invoiceType == "B2C").toList();

    return Expanded(
      child: DefaultTabController(
        length: 2,
        child: Column(children: [
          const TabBar(labelColor: Colors.indigo, tabs: [Tab(text: "B2B (Registered)"), Tab(text: "B2C (Small)")]),
          Expanded(child: TabBarView(children: [
            _simpleList(b2b),
            _simpleList(b2c),
          ])),
        ]),
      ),
    );
  }

  // --- GSTR-2: PURCHASE REGISTER ---
  Widget _buildGstr2View(List<Purchase> purchases) {
    return Expanded(
      child: ListView.builder(
        itemCount: purchases.length,
        itemBuilder: (c, i) {
          final p = purchases[i];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            child: ListTile(
              title: Text(p.distributorName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("Bill No: ${p.billNo} | Status: ${p.gstStatus}"),
              trailing: Text("₹${p.totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
            ),
          );
        },
      ),
    );
  }

  // --- GSTR-3B: SUMMARY ---
  Widget _buildGstr3BView(List<Sale> sales, List<Purchase> purchases) {
    double saleTax = 0; sales.forEach((s) => s.items.forEach((it) => saleTax += (it.cgst + it.sgst + it.igst)));
    double purTax = 0; purchases.forEach((p) => p.items.forEach((it) => purTax += (it.purchaseRate * it.qty * it.gstRate / 100)));

    return Expanded(
      child: ListView(padding: const EdgeInsets.all(15), children: [
        _statCard("3.1 Outward Taxable Supplies", saleTax, Colors.green),
        const SizedBox(height: 10),
        _statCard("4.0 Eligible ITC", purTax, Colors.orange),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.indigo, width: 2)),
          child: Column(children: [
            const Text("NET TAX TO BE PAID", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            Text("₹${(saleTax - purTax).toStringAsFixed(2)}", style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: (saleTax - purTax) > 0 ? Colors.red : Colors.green)),
          ]),
        )
      ]),
    );
  }

  Widget _simpleList(List<Sale> list) {
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (c, i) => ListTile(
        title: Text(list[i].partyName),
        subtitle: Text("Invoice: ${list[i].billNo}"),
        trailing: Text("₹${list[i].totalAmount.toStringAsFixed(2)}"),
      ),
    );
  }

  Widget _statCard(String title, double val, Color col) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text("₹${val.toStringAsFixed(2)}", style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
      ),
    );
  }
}
