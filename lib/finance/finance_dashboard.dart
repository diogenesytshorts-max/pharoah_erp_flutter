// FILE: lib/finance/finance_dashboard.dart

import 'package:flutter/material.dart';
import 'pdc_entry_view.dart'; // NAYA IMPORT

class FinanceDashboard extends StatelessWidget {
  const FinanceDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Finance & Recovery Hub"),
        backgroundColor: Colors.green.shade900,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFinancialSummary(),
            const SizedBox(height: 25),
            const Text("PAYMENT AGEING ANALYSIS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            Row(
              children: [
                _ageingBox("0-30 DAYS", "₹0.00", Colors.green),
                const SizedBox(width: 10),
                _ageingBox("31-60 DAYS", "₹0.00", Colors.orange),
                const SizedBox(width: 10),
                _ageingBox("60+ DAYS", "₹0.00", Colors.red),
              ],
            ),
            const SizedBox(height: 30),
            const Text("RECOVERY TOOLS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1.2)),
            const SizedBox(height: 15),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 1.3,
              children: [
                _toolCard("OUTSTANDING", "Party-wise List", Icons.person_search_rounded, Colors.indigo, () {}),
                
                // UPDATED: PDC TRACKER BUTTON CONNECT HO GAYA HAI
                _toolCard("NEW CHEQUE", "Post Dated Entry", Icons.layers_outlined, Colors.teal, () {
                  Navigator.push(context, MaterialPageRoute(builder: (c) => const PdcEntryView()));
                }),
                
                _toolCard("SALESMAN", "Collection Report", Icons.badge_rounded, Colors.blueGrey, () {}),
                _toolCard("INTEREST", "Late Pay Calc.", Icons.percent_rounded, Colors.brown, () {}),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- UI HELPERS ---
  Widget _buildFinancialSummary() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)]),
      child: Column(children: [
          const Text("TOTAL RECEIVABLE (MARKET UDHAAR)", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
          const SizedBox(height: 5),
          const Text("₹0.00", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.indigo)),
          const Divider(height: 30),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _miniStat("Total Payable", "₹0.00", Colors.red.shade700),
              Container(width: 1, height: 30, color: Colors.grey.shade200),
              _miniStat("Cash Flow", "₹0.00", Colors.green.shade700),
          ])
      ]),
    );
  }
  Widget _miniStat(String label, String val, Color c) => Column(children: [Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)), Text(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c))]);
  Widget _ageingBox(String label, String amt, Color c) => Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 15), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(15), border: Border.all(color: c.withOpacity(0.3))), child: Column(children: [Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: c)), const SizedBox(height: 5), Text(amt, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: c))])));
  Widget _toolCard(String title, String sub, IconData icon, Color color, VoidCallback onTap) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade100)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: color, size: 28), const SizedBox(height: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), Text(sub, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold))])));
}
