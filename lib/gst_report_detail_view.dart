import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'pharoah_manager.dart';
import 'models.dart';

class GSTReportDetailView extends StatefulWidget {
  final String reportType;
  const GSTReportDetailView({super.key, required this.reportType});

  @override
  State<GSTReportDetailView> createState() => _GSTReportDetailViewState();
}

class _GSTReportDetailViewState extends State<GSTReportDetailView> {
  DateTime selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    
    // Filter sales by selected month and year
    List<Sale> monthlySales = ph.sales.where((s) => 
      s.status == "Active" && 
      s.date.month == selectedDate.month && 
      s.date.year == selectedDate.year
    ).toList();

    // Grouping for GSTR-1
    List<Sale> b2bSales = monthlySales.where((s) => s.invoiceType == "B2B").toList();
    List<Sale> b2cSales = monthlySales.where((s) => s.invoiceType == "B2C").toList();

    double totalTaxable = 0;
    double totalGst = 0;

    for (var s in monthlySales) {
      for (var it in s.items) {
        totalTaxable += (it.rate * it.qty) - ((it.rate * it.qty) * it.discountPercent / 100) - it.discountRupees;
        totalGst += (it.cgst + it.sgst + it.igst);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.reportType),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 1. Month Selector Header
          Container(
            padding: const EdgeInsets.all(15),
            color: Colors.indigo.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Report Period:", style: TextStyle(fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: () async {
                    // Simple month/year picker workaround
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => selectedDate = picked);
                  },
                  icon: const Icon(Icons.calendar_month),
                  label: Text(DateFormat('MMMM yyyy').format(selectedDate), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          // 2. Summary Boxes
          Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                _statBox("Taxable Val", totalTaxable, Colors.blue),
                const SizedBox(width: 10),
                _statBox("GST Collected", totalGst, Colors.green),
              ],
            ),
          ),

          // 3. Detailed List
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    labelColor: Colors.indigo,
                    unselectedLabelColor: Colors.grey,
                    tabs: [Tab(text: "B2B (Tax)"), Tab(text: "B2C (Retail)")],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildSaleList(b2bSales, ph),
                        _buildSaleList(b2cSales, ph),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String label, double val, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.3))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 5),
            Text("₹${val.toStringAsFixed(2)}", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildSaleList(List<Sale> sales, PharoahManager ph) {
    if (sales.isEmpty) return const Center(child: Text("No transactions in this category."));
    return ListView.builder(
      itemCount: sales.length,
      itemBuilder: (c, i) {
        final s = sales[i];
        final party = ph.parties.firstWhere((p) => p.name == s.partyName, orElse: () => ph.parties[0]);
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: ListTile(
            title: Text(s.partyName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Inv: ${s.billNo} | GSTIN: ${party.gst}"),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("₹${s.totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(DateFormat('dd/MM/yy').format(s.date), style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }
}
