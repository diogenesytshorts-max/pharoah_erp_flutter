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

    // --- 2. CORE CALCULATIONS FOR TAX SUMMARY ---
    double salesTaxableTotal = 0;
    double salesCgstTotal = 0;
    double salesSgstTotal = 0;
    double salesIgstTotal = 0;

    for (var s in monthlySales) {
      for (var it in s.items) {
        double itemTaxable = (it.rate * it.qty) - ((it.rate * it.qty) * it.discountPercent / 100) - it.discountRupees;
        salesTaxableTotal += itemTaxable;
        salesCgstTotal += it.cgst;
        salesSgstTotal += it.sgst;
        salesIgstTotal += it.igst;
      }
    }

    double purTaxableTotal = 0;
    double purGstTotal = 0; // Total ITC

    for (var p in monthlyPurchases) {
      for (var it in p.items) {
        double itemBaseVal = it.purchaseRate * it.qty;
        purTaxableTotal += itemBaseVal;
        purGstTotal += (itemBaseVal * it.gstRate / 100); // Input Tax Credit
      }
    }

    double totalOutputTax = salesCgstTotal + salesSgstTotal + salesIgstTotal;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: Text(widget.reportType),
        backgroundColor: Colors.indigo.shade800,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Month Selector Section
          _buildMonthHeader(),

          // Display specific report UI based on type
          if (widget.reportType.contains("GSTR-3B"))
            _buildGstr3BView(salesTaxableTotal, totalOutputTax, purTaxableTotal, purGstTotal)
          else if (widget.reportType.contains("GSTR-1"))
            _buildGstr1View(monthlySales, ph)
          else if (widget.reportType.contains("GSTR-2"))
            _buildGstr2View(monthlyPurchases, ph),
        ],
      ),
    );
  }

  // --- HEADER: MONTH & YEAR PICKER ---
  Widget _buildMonthHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("Reporting Period:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          InkWell(
            onTap: () async {
              DateTime? picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => selectedDate = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.indigo.shade100),
              ),
              child: Row(
                children: [
                  Text(
                    DateFormat('MMMM yyyy').format(selectedDate),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo.shade800),
                  ),
                  const Icon(Icons.calendar_month, color: Colors.indigo, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- REPORT UI: GSTR-3B (MONTHLY SUMMARY & ITC) ---
  Widget _buildGstr3BView(double sTax, double sGst, double pTax, double pGst) {
    double netTaxPayable = sGst - pGst;

    return Expanded(
      child: ListView(
        padding: const EdgeInsets.all(15),
        children: [
          _taxSummaryCard("OUTWARD SUPPLIES (SALES)", sTax, sGst, Colors.green),
          const SizedBox(height: 12),
          _taxSummaryCard("INWARD SUPPLIES (ITC)", pTax, pGst, Colors.orange),
          const SizedBox(height: 25),
          
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: netTaxPayable > 0 ? Colors.red.shade300 : Colors.green.shade300, width: 2),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            ),
            child: Column(
              children: [
                Text(
                  netTaxPayable > 0 ? "NET GST PAYABLE (OUTPUT - INPUT)" : "ELIGIBLE ITC TO CARRY FORWARD",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey),
                ),
                const SizedBox(height: 10),
                Text(
                  "₹${netTaxPayable.abs().toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: 32, 
                    fontWeight: FontWeight.w900, 
                    color: netTaxPayable > 0 ? Colors.red.shade700 : Colors.green.shade700
                  ),
                ),
                const Divider(height: 30),
                const Text(
                  "Note: GSTR-3B is a self-assessment summary return to be filed monthly.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- REPORT UI: GSTR-1 (B2B vs B2C TABS) ---
  Widget _buildGstr1View(List<Sale> sales, PharoahManager ph) {
    List<Sale> b2b = sales.where((s) => s.invoiceType == "B2B").toList();
    List<Sale> b2c = sales.where((s) => s.invoiceType == "B2C").toList();

    return Expanded(
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              labelColor: Colors.indigo,
              indicatorColor: Colors.indigo,
              unselectedLabelColor: Colors.grey,
              tabs: [Tab(text: "B2B (Tax Invoices)"), Tab(text: "B2C (Retail Invoices)")],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _transactionList(b2b, ph, Colors.blue),
                  _transactionList(b2c, ph, Colors.green),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- REPORT UI: GSTR-2 (PURCHASE REGISTER) ---
  Widget _buildGstr2View(List<Purchase> purchases, PharoahManager ph) {
    if (purchases.isEmpty) return const Expanded(child: Center(child: Text("No Purchase records for this month.")));

    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: purchases.length,
        itemBuilder: (context, index) {
          final p = purchases[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.downloading, color: Colors.white)),
              title: Text(p.distributorName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("Bill: ${p.billNo} | Date: ${DateFormat('dd/MM').format(p.date)}"),
              trailing: Text(
                "₹${p.totalAmount.toStringAsFixed(2)}",
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- REUSABLE WIDGETS & HELPERS ---

  Widget _taxSummaryCard(String title, double taxable, double gst, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color, letterSpacing: 1)),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Taxable Value:", style: TextStyle(fontSize: 13, color: Colors.grey)),
              Text("₹${taxable.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title.contains("SALE") ? "GST Collected:" : "Input Credit (ITC):", 
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
              Text("₹${gst.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _transactionList(List<Sale> sales, PharoahManager ph, Color themeColor) {
    if (sales.isEmpty) return const Center(child: Text("No transactions in this period."));
    
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: sales.length,
      itemBuilder: (context, index) {
        final s = sales[index];
        final party = ph.parties.firstWhere((p) => p.name == s.partyName, orElse: () => ph.parties[0]);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            title: Text(s.partyName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text("Inv: ${s.billNo} | GSTIN: ${party.gst}"),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("₹${s.totalAmount.toStringAsFixed(2)}", 
                  style: TextStyle(fontWeight: FontWeight.bold, color: themeColor)),
                Text(DateFormat('dd/MM/yy').format(s.date), style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }
}
