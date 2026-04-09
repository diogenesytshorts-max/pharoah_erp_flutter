import 'package:flutter/material.dart';
import 'widgets.dart';
import 'gst_report_detail_view.dart';
import 'eway_bill_management_view.dart';
import 'gst_reconciliation_view.dart'; // NAYA IMPORT

class GSTMenuView extends StatelessWidget {
  const GSTMenuView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(title: const Text("GST Reports & Compliance"), backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("GOVERNMENT RETURNS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 15),
            GridView.count(
              shrinkWrap: true, crossAxisCount: 3, crossAxisSpacing: 15, mainAxisSpacing: 15,
              children: [
                ActionIconBtn(title: "GSTR-1", icon: Icons.assignment_outlined, color: Colors.green, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const GSTReportDetailView(reportType: "GSTR-1")))),
                ActionIconBtn(title: "GSTR-3B", icon: Icons.summarize_outlined, color: Colors.blue, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const GSTReportDetailView(reportType: "GSTR-3B")))),
                ActionIconBtn(title: "GSTR-2", icon: Icons.shopping_cart_checkout_rounded, color: Colors.orange, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const GSTReportDetailView(reportType: "GSTR-2")))),
              ],
            ),
            const SizedBox(height: 35),
            const Text("RECONCILIATION & TOOLS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 15),
            GridView.count(
              shrinkWrap: true, crossAxisCount: 3, crossAxisSpacing: 15, mainAxisSpacing: 15,
              children: [
                ActionIconBtn(title: "E-Way Bill", icon: Icons.local_shipping_outlined, color: Colors.indigo, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const EWayBillManagementView()))),
                // NAYA BUTTON
                ActionIconBtn(title: "Portal Match", icon: Icons.fact_check_outlined, color: Colors.teal, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const GSTReconciliationView()))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
