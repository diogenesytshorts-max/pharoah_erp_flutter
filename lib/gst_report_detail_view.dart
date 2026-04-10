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

  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    List<Sale> mSales = ph.sales.where((s) => s.status == "Active" && s.date.month == selectedDate.month && s.date.year == selectedDate.year).toList();
    List<Purchase> mPurchases = ph.purchases.where((p) => p.date.month == selectedDate.month && p.date.year == selectedDate.year).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(title: Text(widget.reportType), backgroundColor: Colors.indigo.shade800, foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: () => PdfService.generateGstReport(widget.reportType, mSales, DateFormat('MMYYYY').format(selectedDate))),
          if (widget.reportType.contains("GSTR-1")) IconButton(icon: const Icon(Icons.code), onPressed: () => PdfService.generateGstJson(mSales, DateFormat('MMYYYY').format(selectedDate))),
        ],
      ),
      body: Column(children: [
        Container(padding: const EdgeInsets.all(15), color: Colors.white, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Reporting Period:"), InkWell(onTap: () async { DateTime? p = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2100)); if (p != null) setState(() => selectedDate = p); }, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(5)), child: Text(DateFormat('MMMM yyyy').format(selectedDate), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo))))])),
        if (widget.reportType.contains("GSTR-3B")) _build3B(mSales, mPurchases) else _buildList(mSales)
      ]),
    );
  }

  Widget _build3B(List<Sale> s, List<Purchase> p) {
    double saleTax = 0; s.forEach((x) => x.items.forEach((it) => saleTax += (it.cgst + it.sgst + it.igst)));
    double purTax = 0; p.forEach((x) => x.items.forEach((it) => purTax += (it.purchaseRate * it.qty * it.gstRate / 100)));
    return Expanded(child: ListView(padding: const EdgeInsets.all(15), children: [
      _card("3.1 Outward Taxable Supplies", saleTax, Colors.green),
      _card("4.0 Eligible ITC", purTax, Colors.orange),
      const Divider(height: 40),
      Center(child: Text("NET PAYABLE: ₹${(saleTax - purTax).toStringAsFixed(2)}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red)))
    ]));
  }

  Widget _buildList(List<Sale> list) {
    return Expanded(child: ListView.builder(itemCount: list.length, itemBuilder: (c, i) => ListTile(title: Text(list[i].partyName), subtitle: Text("Inv: ${list[i].billNo}"), trailing: Text("₹${list[i].totalAmount.toStringAsFixed(2)}"))));
  }

  Widget _card(String t, double v, Color c) { return Card(child: ListTile(title: Text(t), trailing: Text("₹${v.toStringAsFixed(2)}", style: TextStyle(color: c, fontWeight: FontWeight.bold)))); }
}
