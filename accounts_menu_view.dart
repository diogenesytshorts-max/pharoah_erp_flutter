import 'package:flutter/material.dart';
import 'widgets.dart';
import 'accounting_views.dart'; // Naya View hum agle step me denge
import 'daybook_view.dart'; // Naya View hum agle step me denge
import 'ledger_reports_view.dart'; // Naya View hum agle step me denge

class AccountsMenuView extends StatelessWidget {
  const AccountsMenuView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("Accounts & Cash Management"),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "DAILY VOUCHERS",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey, letterSpacing: 1.2),
            ),
            const SizedBox(height: 15),
            
            // --- SECTION 1: VOUCHER ENTRIES ---
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 1.1,
              children: [
                ActionIconBtn(
                  title: "Receipt (Cash In)",
                  icon: Icons.add_chart_rounded,
                  color: Colors.green.shade700,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const VoucherEntryView(type: "Receipt"))),
                ),
                ActionIconBtn(
                  title: "Payment (Cash Out)",
                  icon: Icons.analytics_rounded,
                  color: Colors.red.shade700,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const VoucherEntryView(type: "Payment"))),
                ),
                ActionIconBtn(
                  title: "Contra (Bank Transfer)",
                  icon: Icons.sync_alt_rounded,
                  color: Colors.orange.shade800,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const VoucherEntryView(type: "Contra"))),
                ),
                ActionIconBtn(
                  title: "Expenses (Kharcha)",
                  icon: Icons.money_off_rounded,
                  color: Colors.brown,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const VoucherEntryView(type: "Expense"))),
                ),
              ],
            ),

            const SizedBox(height: 35),
            
            const Text(
              "REPORTS & STATEMENTS",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey, letterSpacing: 1.2),
            ),
            const SizedBox(height: 15),

            // --- SECTION 2: ACCOUNTING REPORTS ---
            Row(
              children: [
                Expanded(
                  child: _reportCard(
                    context, 
                    "Daybook", 
                    "Aaj ka poora hisaab", 
                    Icons.menu_book_rounded, 
                    Colors.blueGrey, 
                    const DaybookView()
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _reportCard(
                    context, 
                    "Khaata / Ledger", 
                    "Udhari & Balances", 
                    Icons.people_alt_rounded, 
                    Colors.indigo, 
                    const LedgerReportsView()
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportCard(BuildContext context, String title, String sub, IconData icon, Color color, Widget target) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => target)),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
          border: Border.all(color: Colors.grey.shade100)
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Text(sub, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
