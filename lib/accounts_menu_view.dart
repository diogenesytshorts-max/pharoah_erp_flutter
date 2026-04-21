import 'package:flutter/material.dart';
import 'widgets.dart';
import 'accounting_views.dart';
import 'daybook_view.dart';
import 'ledger_reports_view.dart';

class AccountsMenuView extends StatelessWidget {
  const AccountsMenuView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("Accounts & Cash"),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(20),
        crossAxisCount: 2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        childAspectRatio: 1.1,
        children: [
          ActionIconBtn(
            title: "Receipt (Cash In)",
            icon: Icons.add_chart_rounded,
            color: Colors.green,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const VoucherEntryView(type: "Receipt"))),
          ),
          ActionIconBtn(
            title: "Payment (Cash Out)",
            icon: Icons.analytics_rounded,
            color: Colors.red,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const VoucherEntryView(type: "Payment"))),
          ),
          ActionIconBtn(
            title: "Daybook",
            icon: Icons.menu_book_rounded,
            color: Colors.blueGrey,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const DaybookView())),
          ),
          ActionIconBtn(
            title: "Khaata / Ledgers",
            icon: Icons.people_alt_rounded,
            color: Colors.indigo,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const LedgerReportsView())),
          ),
        ],
      ),
    );
  }
}
