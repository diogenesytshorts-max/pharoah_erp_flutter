import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'pharoah_manager.dart';
import 'models.dart';

class GSTReconciliationView extends StatefulWidget {
  const GSTReconciliationView({super.key});
  @override State<GSTReconciliationView> createState() => _GSTReconciliationViewState();
}

class _GSTReconciliationViewState extends State<GSTReconciliationView> {
  DateTime selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    List<Purchase> purchases = ph.purchases.where((p) => p.date.month == selectedDate.month && p.date.year == selectedDate.year).toList();

    return Scaffold(
      appBar: AppBar(title: const Text("GSTR-2A Reconciliation"), backgroundColor: Colors.teal, foregroundColor: Colors.white),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15), color: Colors.teal.shade50,
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text("Select Month:", style: TextStyle(fontWeight: FontWeight.bold)),
              InkWell(
                onTap: () async {
                  DateTime? p = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (p != null) setState(() => selectedDate = p);
                },
                child: Text(DateFormat('MMMM yyyy').format(selectedDate), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
              )
            ]),
          ),
          const Padding(padding: EdgeInsets.all(10), child: Text("Mark bills 'Matched' if they appear on GST Portal (2A/2B).", style: TextStyle(fontSize: 11, color: Colors.grey))),
          Expanded(
            child: purchases.isEmpty 
              ? const Center(child: Text("No Purchases for this month."))
              : ListView.builder(
                  itemCount: purchases.length,
                  itemBuilder: (c, i) {
                    final p = purchases[i];
                    bool isMatched = p.gstStatus == "Matched";
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                      color: isMatched ? Colors.green.shade50 : Colors.white,
                      child: ListTile(
                        title: Text(p.distributorName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Bill: ${p.billNo} | Amt: ₹${p.totalAmount.toStringAsFixed(2)}"),
                        trailing: ChoiceChip(
                          label: Text(isMatched ? "MATCHED" : "MISSING"),
                          selected: isMatched,
                          selectedColor: Colors.green,
                          onSelected: (val) {
                            setState(() {
                              p.gstStatus = val ? "Matched" : "Pending";
                              ph.save();
                            });
                          },
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
}
