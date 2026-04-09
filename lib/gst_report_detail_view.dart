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
    
    // --- 1. FILTERING DATA BY SELECTED MONTH ---
    List<Sale> monthlySales = ph.sales.where((s) => 
      s.status == "Active" && s.date.month == selectedDate.month && s.date.year == selectedDate.year
    ).toList();

    List<Purchase> monthlyPurchases = ph.purchases.where((p) => 
      p.date.month == selectedDate.month && p.date.year == selectedDate.year
    ).toList();

    // --- 2. CALCULATING TAX TOTALS ---
    double salesTaxable = 0, salesGST = 0;
    for (var s in monthlySales) {
      for (var it in s.items) {
        salesTaxable += (it.rate * it.qty) - ((it.rate * it.qty) * it.discountPercent / 100) - it.discountRupees;
        salesGST += (it.cgst + it.sgst + it.igst);
      }
    }

    double purchaseTaxable = 0, purchaseGST = 0;
    for (var p in monthlyPurchases) {
      for (var it in p.items) {
        double baseVal = it.purchaseRate * it.qty;
        purchaseTaxable += baseVal;
        purchaseGST += (baseVal * it.gstRate / 100); // This is your ITC
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: Text(widget.reportType),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Month Selector Header
          _buildMonthPicker(),

          // Conditional UI based on Report Type
          if (widget.reportType.contains("GSTR-3B"))
            _buildGstr3BSummary(salesTaxable, salesGST, purchaseTaxable, purchaseGST)
          else if (widget.reportType.contains("GSTR-1"))
            _buildGstr1View(monthlySales, ph)
          else if (widget.reportType.contains("GSTR-2"))
            _buildGstr2View(monthlyPurchases, ph),
        ],
      ),
    );
  }

  // --- UI: GSTR-3B (ITC & NET TAX PAYABLE) ---
  Widget _buildGstr3BSummary(double sTaxable, double sGST, double pTaxable, double pGST) {
    double netPayable = sGST - pGST;
    return Expanded(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _summaryCard("OUTWARD SUPPLIES (SALES)", sTaxable, sGST, Colors.green),
          const SizedBox(height: 15),
          _summaryCard("ELIGIBLE ITC (PURCHASES)", pTaxable, pGST, Colors.orange),
          const SizedBox(height: 25),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: netPayable > 0 ? Colors.red : Colors.green, width: 2),
            ),
            child: Column(
              children: [
                Text(netPayable > 0 ? "NET GST PAYABLE TO GOVT" : "EXCESS ITC (CARRY FORWARD)", 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 10),
                Text("₹${netPayable.abs().toStringAsFixed(2)}", 
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: netPayable > 0 ? Colors.red : Colors.green)),
                const SizedBox(height: 5),
                const Text("(Net Tax = Sales GST - Purchase GST)", style: TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- UI: GSTR-1 (B2B vs B2C Tabs) ---
  Widget _buildGstr1View(List<Sale> sales, PharoahManager ph) {
    List<Sale> b2b = sales.where((s) => s.invoiceType == "B2B").toList();
    List<Sale> b2c = sales.where((s) => s.invoiceType == "B2C").toList();
    return Expanded(
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(labelColor: Colors.indigo, tabs: [Tab(text: "B2B (Tax)"), Tab(text: "B2C (Retail)")]),
            Expanded(child: TabBarView(children: [_saleList(b2b, ph), _saleList(b2c, ph)])),
          ],
        ),
      ),
    );
  }

  // --- UI: GSTR-2 (Purchase Register) ---
  Widget _buildGstr2View(List<Purchase> purcs, PharoahManager ph) {
    if (purcs.isEmpty) return const Expanded(child: Center(child: Text("No Purchases this month.")));
    return Expanded(
      child: ListView.builder(
        itemCount: purcs.length,
        itemBuilder: (c, i) {
          final p = purcs[i];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            child: ListTile(
              title: Text(p.distributorName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("Bill: ${p.billNo} | Date: ${DateFormat('dd/MM').format(p.date)}"),
              trailing: Text("₹${p.totalAmount.toStringAsFixed(2)}", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
            ),
          );
        },
      ),
    );
  }

  // --- HELPERS ---
  Widget _buildMonthPicker() {
    return Container(
      padding: const EdgeInsets.all(15),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("Reporting Month:", style: TextStyle(fontWeight: FontWeight.bold)),
          InkWell(
            onTap: () async {
              DateTime? picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (picked != null) setState(() => selectedDate = picked);
            },
            child: Row(children: [
              Text(DateFormat('MMMM yyyy').format(selectedDate), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)),
              const Icon(Icons.arrow_drop_down, color: Colors.indigo)
            ]),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String title, double taxable, double gst, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Taxable Amount:", style: TextStyle(fontSize: 13)),
              Text("₹${taxable.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title.contains("SALE") ? "GST Collected:" : "Input Tax Credit (ITC):", style: const TextStyle(fontSize: 13)),
              Text("₹${gst.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _saleList(List<Sale> sales, PharoahManager ph) {
    if (sales.isEmpty) return const Center(child: Text("No Records."));
    return ListView.builder(
      itemCount: sales.length,
      itemBuilder: (c, i) {
        final s = sales[i];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
          child: ListTile(
            title: Text(s.partyName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text("Inv: ${s.billNo} | ${DateFormat('dd/MM').format(s.date)}"),
            trailing: Text("₹${s.totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }
}
