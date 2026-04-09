import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'audit_logs_view.dart';
import 'file_management_view.dart';
import 'user_master_view.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'widgets.dart';

class MoreFeaturesView extends StatelessWidget {
  final VoidCallback onLogout;
  const MoreFeaturesView({super.key, required this.onLogout});

  // --- 7-STEP RESET LOGIC ---
  void _startResetProcess(BuildContext context) {
    final List<Map<String, String>> steps = [
      {"t": "Step 1/7", "m": "Kya aap vastav me sara data delete karna chahte hain?", "b": "AGREE"},
      {"t": "Step 2/7", "m": "Isse aapki saari Sales, Purchase aur Inventory zero ho jayegi. Sure?", "b": "YES, I KNOW"},
      {"t": "Step 3/7", "m": "Kya aapne pehle backup le liya hai? Bina backup data wapas nahi aayega!", "b": "I HAVE BACKUP"},
      {"t": "Step 4/7", "m": "Ye action permanent hai. Kya aap abhi bhi aage badhna chahte hain?", "b": "YES, PROCEED"},
      {"t": "Step 5/7", "m": "Final warning: Pharoah ERP ka sara setup reset ho jayega.", "b": "AGREE & RESET"},
      {"t": "Step 6/7", "m": "Are you REALLY REALLY SURE? Last chance to go back.", "b": "YES, DELETE ALL"},
      {"t": "FINAL - 7/7", "m": "Ok, Tap below to wipe everything. No undo possible!", "b": "WIPE EVERYTHING NOW"},
    ];
    _showStep(context, steps, 0);
  }

  void _showStep(BuildContext context, List<Map<String, String>> steps, int index) {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: Text(steps[index]['t']!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text(steps[index]['m']!),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("NO / CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(c);
              if (index < steps.length - 1) {
                _showStep(context, steps, index + 1);
              } else {
                Provider.of<PharoahManager>(context, listen: false).masterReset();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("MASTER RESET COMPLETED SUCCESSFULLY!")));
              }
            },
            child: Text(steps[index]['b']!, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- GST REPORT POPUP ---
  void _showGstReport(BuildContext context, String type) {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    double taxable = 0;
    double cgst = 0;
    double sgst = 0;

    if (type == "GSTR-1") {
      // Sales Report Calculation
      for (var s in ph.sales.where((s) => s.status == "Active")) {
        for (var it in s.items) {
          double itemTaxable = (it.rate * it.qty) - ((it.rate * it.qty) * it.discountPercent / 100) - it.discountRupees;
          taxable += itemTaxable;
          cgst += it.cgst;
          sgst += it.sgst;
        }
      }
    } else if (type == "GSTR-3B") {
      // Summary: Sales Tax - Purchase Tax
      for (var s in ph.sales.where((s) => s.status == "Active")) {
        for (var it in s.items) {
          cgst += it.cgst; sgst += it.sgst;
        }
      }
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => Container(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(type, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo)),
            const Divider(),
            const SizedBox(height: 10),
            _reportRow("Total Taxable Value", "₹${taxable.toStringAsFixed(2)}"),
            _reportRow("Total CGST", "₹${cgst.toStringAsFixed(2)}"),
            _reportRow("Total SGST", "₹${sgst.toStringAsFixed(2)}"),
            const Divider(),
            _reportRow("TOTAL TAX PAYABLE", "₹${(cgst + sgst).toStringAsFixed(2)}", isBold: true),
            const SizedBox(height: 20),
            const Text("Detailed Excel/PDF export coming soon.", style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _reportRow(String label, String val, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(val, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: Colors.indigo)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("More Features & Tools"), 
        backgroundColor: Colors.indigo, 
        foregroundColor: Colors.white, 
        elevation: 0
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- SECTION 1: GST & TAX REPORTS ---
            _buildSectionTitle("GST & RETURNS"),
            const SizedBox(height: 15),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
              children: [
                ActionIconBtn(
                  title: "GSTR-1", // SALES REPORT
                  icon: Icons.assignment_outlined,
                  color: Colors.green,
                  onTap: () => _showGstReport(context, "GSTR-1"),
                ),
                ActionIconBtn(
                  title: "GSTR-3B", // SUMMARY REPORT
                  icon: Icons.Summarize_outlined,
                  color: Colors.blue,
                  onTap: () => _showGstReport(context, "GSTR-3B"),
                ),
                ActionIconBtn(
                  title: "GSTR-2", // PURCHASE REGISTER
                  icon: Icons.shopping_bag_outlined,
                  color: Colors.orange,
                  onTap: () => _showGstReport(context, "GSTR-2"),
                ),
              ],
            ),

            const SizedBox(height: 35),

            // --- SECTION 2: SYSTEM & ADMINISTRATION (THE 6 TOOLS) ---
            _buildSectionTitle("SYSTEM & ADMINISTRATION"),
            const SizedBox(height: 15),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
              children: [
                ActionIconBtn(
                  title: "Company",
                  icon: Icons.business,
                  color: Colors.indigo,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => UserMasterView(onLogout: onLogout))),
                ),
                ActionIconBtn(
                  title: "Audit Logs",
                  icon: Icons.history_edu,
                  color: Colors.brown,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AuditLogsView())),
                ),
                ActionIconBtn(
                  title: "Backup",
                  icon: Icons.cloud_done,
                  color: Colors.blueGrey,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const FileManagementView())),
                ),
                ActionIconBtn(
                  title: "Change FY",
                  icon: Icons.calendar_month,
                  color: Colors.teal,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const FileManagementView())),
                ),
                ActionIconBtn(
                  title: "Admin User",
                  icon: Icons.admin_panel_settings,
                  color: Colors.deepPurple,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => UserMasterView(onLogout: onLogout))),
                ),
                ActionIconBtn(
                  title: "Reset Data",
                  icon: Icons.delete_forever,
                  color: Colors.red,
                  onTap: () => _startResetProcess(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 5), 
      child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1.2))
    );
  }
}
