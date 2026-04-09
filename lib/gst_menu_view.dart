import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'widgets.dart';

class GSTMenuView extends StatelessWidget {
  const GSTMenuView({super.key});

  void _showGstReport(BuildContext context, String type) {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    double taxable = 0; double cgst = 0; double sgst = 0;

    for (var s in ph.sales.where((s) => s.status == "Active")) {
      for (var it in s.items) {
        taxable += (it.rate * it.qty) - ((it.rate * it.qty) * it.discountPercent / 100) - it.discountRupees;
        cgst += it.cgst; sgst += it.sgst;
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
            Text(type, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
            const Divider(),
            _row("Total Taxable Value", "₹${taxable.toStringAsFixed(2)}"),
            _row("Total CGST", "₹${cgst.toStringAsFixed(2)}"),
            _row("Total SGST", "₹${sgst.toStringAsFixed(2)}"),
            const Divider(),
            _row("TOTAL TAX", "₹${(cgst + sgst).toStringAsFixed(2)}", b: true),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _row(String l, String v, {bool b = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: TextStyle(fontWeight: b ? FontWeight.bold : FontWeight.normal)), Text(v, style: TextStyle(fontWeight: b ? FontWeight.bold : FontWeight.normal, color: Colors.green))]),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("GST Reports"), backgroundColor: Colors.green, foregroundColor: Colors.white),
      body: GridView.count(
        padding: const EdgeInsets.all(20),
        crossAxisCount: 3, crossAxisSpacing: 15, mainAxisSpacing: 15,
        children: [
          ActionIconBtn(title: "GSTR-1", icon: Icons.description, color: Colors.green, onTap: () => _showGstReport(context, "GSTR-1 (Sales)")),
          ActionIconBtn(title: "GSTR-3B", icon: Icons.summarize, color: Colors.blue, onTap: () => _showGstReport(context, "GSTR-3B (Summary)")),
          ActionIconBtn(title: "GSTR-2", icon: Icons.shopping_bag, color: Colors.orange, onTap: () => _showGstReport(context, "GSTR-2 (Purchase)")),
        ],
      ),
    );
  }
}
