import 'package:flutter/material.dart';
import 'widgets.dart';
import 'gst_report_detail_view.dart';

class GSTMenuView extends StatelessWidget {
  const GSTMenuView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("GST Reports & Returns"), 
        backgroundColor: Colors.green.shade700, 
        foregroundColor: Colors.white
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("STATUTORY REPORTS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 15),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              children: [
                ActionIconBtn(
                  title: "GSTR-1", 
                  icon: Icons.assignment_outlined, 
                  color: Colors.green, 
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const GSTReportDetailView(reportType: "GSTR-1 (Sales Register)"))),
                ),
                ActionIconBtn(
                  title: "GSTR-3B", 
                  icon: Icons.summarize_outlined, 
                  color: Colors.blue, 
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const GSTReportDetailView(reportType: "GSTR-3B (Monthly Summary)"))),
                ),
                ActionIconBtn(
                  title: "GSTR-2", 
                  icon: Icons.shopping_cart_checkout_rounded, 
                  color: Colors.orange, 
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const GSTReportDetailView(reportType: "GSTR-2 (Purchase Register)"))),
                ),
              ],
            ),
            const SizedBox(height: 30),
            const Card(
              child: ListTile(
                leading: Icon(Icons.info_outline, color: Colors.blue),
                title: Text("Tip for Accountant", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Use GSTR-1 for filing outward supplies and GSTR-3B for monthly tax payment summary."),
              ),
            )
          ],
        ),
      ),
    );
  }
}
