// FILE: lib/finance/finance_dashboard.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../pharoah_manager.dart';
import 'pdc_entry_view.dart';
import 'outstanding_ageing_view.dart';
import 'salesman_recovery_view.dart';
import 'bank_book_view.dart'; // NAYA IMPORT

class FinanceDashboard extends StatelessWidget {
  const FinanceDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

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
            // --- 1. OVERALL OUTSTANDING SUMMARY ---
            _buildFinancialSummary(ph),

            const SizedBox(height: 25),
            _sectionTitle("PAYMENT AGEING ANALYSIS"),
            const SizedBox(height: 10),

            // --- 2. AGEING BOXES (COLOR CODED) ---
            Row(
              children: [
                _ageingBox("0-30 DAYS", Colors.green),
                const SizedBox(width: 10),
                _ageingBox("31-60 DAYS", Colors.orange),
                const SizedBox(width: 10),
                _ageingBox("60+ DAYS", Colors.red),
              ],
            ),

            const SizedBox(height: 30),
            _sectionTitle("FINANCIAL TOOLS & REPORTS"),
            const SizedBox(height: 15),

            // --- 3. FINANCE TOOLS GRID (FULLY CONNECTED) ---
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 1.3,
              children: [
                _toolCard(
                  context,
                  "OUTSTANDING", 
                  "Party-wise Udhaar", 
                  Icons.person_search_rounded, 
                  Colors.indigo, 
                  const OutstandingAgeingView()
                ),
                _toolCard(
                  context,
                  "NEW CHEQUE", 
                  "Post Dated Entry", 
                  Icons.add_card_rounded, 
                  const Color(0xFF00796B), 
                  const PdcEntryView()
                ),
                _toolCard(
                  context,
                  "SALESMAN", 
                  "Recovery Report", 
                  Icons.badge_rounded, 
                  Colors.blueGrey, 
                  const SalesmanRecoveryView()
                ),
                // UPDATED: BANK BOOK CONNECTED
                _toolCard(
                  context,
                  "BANK BOOK", 
                  "Passbook Ledger", 
                  Icons.account_balance_rounded, 
                  Colors.blue.shade800, 
                  const BankBookView()
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialSummary(PharoahManager ph) {
    // Note: Future mein yahan manager se actual totals calculate hoke aayenge
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)],
      ),
      child: Column(
        children: [
          const Text("TOTAL MARKET OUTSTANDING", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
          const SizedBox(height: 5),
          const Text("₹0.00", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.indigo)),
          const Divider(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _miniStat("Total Payable", "₹0.00", Colors.red.shade700),
              Container(width: 1, height: 30, color: Colors.grey.shade200),
              _miniStat("Net Cash Flow", "₹0.00", Colors.green.shade700),
            ],
          )
        ],
      ),
    );
  }

  Widget _miniStat(String label, String val, Color c) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
        Text(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c)),
      ],
    );
  }

  Widget _ageingBox(String label, Color c) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: c.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: c.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: c)),
            const SizedBox(height: 5),
            const Icon(Icons.trending_up, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _toolCard(BuildContext context, String title, String sub, IconData icon, Color color, Widget target) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => target)),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text(sub, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1.2));
}
