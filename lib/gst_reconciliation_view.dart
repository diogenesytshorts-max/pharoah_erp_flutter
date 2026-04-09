import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'pharoah_manager.dart';
import 'models.dart';

class GSTReconciliationView extends StatefulWidget {
  const GSTReconciliationView({super.key});

  @override
  State<GSTReconciliationView> createState() => _GSTReconciliationViewState();
}

class _GSTReconciliationViewState extends State<GSTReconciliationView> {
  DateTime selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    // --- 1. FILTERING PURCHASES BY SELECTED MONTH ---
    // This allows the accountant to reconcile bills month by month
    List<Purchase> monthlyPurchases = ph.purchases.where((p) => 
      p.date.month == selectedDate.month && 
      p.date.year == selectedDate.year
    ).toList();

    // Summary counts for the header
    int matchedCount = monthlyPurchases.where((p) => p.gstStatus == "Matched").length;
    int pendingCount = monthlyPurchases.length - matchedCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("Portal Reconciliation (2A/2B)"),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // --- HEADER: MONTH SELECTOR & SUMMARY ---
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(25),
                bottomRight: Radius.circular(25),
              ),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            ),
            child: Column(
              children: [
                Row(
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
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.teal.shade100),
                        ),
                        child: Row(
                          children: [
                            Text(
                              DateFormat('MMMM yyyy').format(selectedDate),
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal.shade800),
                            ),
                            const Icon(Icons.arrow_drop_down, color: Colors.teal),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _statBadge("TOTAL BILLS", "${monthlyPurchases.length}", Colors.blueGrey),
                    const SizedBox(width: 10),
                    _statBadge("MATCHED", "$matchedCount", Colors.green),
                    const SizedBox(width: 10),
                    _statBadge("MISSING", "$pendingCount", Colors.orange),
                  ],
                ),
              ],
            ),
          ),

          // --- INFO BANNER ---
          Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Mark bills as 'Matched' if they appear in your GSTR-2A/2B portal report.",
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ),

          // --- PURCHASE LIST FOR RECONCILIATION ---
          Expanded(
            child: monthlyPurchases.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.fact_check_outlined, size: 70, color: Colors.grey.shade300),
                        const SizedBox(height: 10),
                        const Text("No purchase entries found for this month.", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    itemCount: monthlyPurchases.length,
                    itemBuilder: (context, index) {
                      final p = monthlyPurchases[index];
                      bool isMatched = p.gstStatus == "Matched";

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(left: BorderSide(color: isMatched ? Colors.green : Colors.orange, width: 5)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                            title: Text(p.distributorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Bill No: ${p.billNo} | Date: ${DateFormat('dd/MM/yy').format(p.date)}"),
                                Text(
                                  "Amount: ₹${p.totalAmount.toStringAsFixed(2)}",
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
                                ),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Switch(
                                  value: isMatched,
                                  activeColor: Colors.green,
                                  onChanged: (val) {
                                    setState(() {
                                      p.gstStatus = val ? "Matched" : "Pending";
                                      // Save state changes to JSON file immediately
                                      ph.save();
                                    });
                                    _showStatusSnackBar(context, p.distributorName, val);
                                  },
                                ),
                                Text(
                                  isMatched ? "MATCHED" : "MISSING",
                                  style: TextStyle(
                                    fontSize: 9, 
                                    fontWeight: FontWeight.bold,
                                    color: isMatched ? Colors.green : Colors.orange
                                  ),
                                )
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statBadge(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.black, color: color)),
          ],
        ),
      ),
    );
  }

  void _showStatusSnackBar(BuildContext context, String name, bool matched) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(matched ? "$name marked as Matched" : "$name marked as Missing from Portal"),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        backgroundColor: matched ? Colors.green.shade800 : Colors.orange.shade800,
      ),
    );
  }
}
