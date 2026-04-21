import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'pharoah_manager.dart';
import 'models.dart';

class DaybookView extends StatefulWidget {
  const DaybookView({super.key});
  @override State<DaybookView> createState() => _DaybookViewState();
}

class _DaybookViewState extends State<DaybookView> {
  DateTime selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    
    // 1. Collect all types of transactions for the selected date
    List<Map<String, dynamic>> allEntries = [];

    // Add Sales
    for (var s in ph.sales.where((s) => _isSameDay(s.date, selectedDate) && s.status == "Active")) {
      allEntries.add({
        'time': s.date,
        'type': 'SALE',
        'party': s.partyName,
        'ref': '#${s.billNo}',
        'amount': s.totalAmount,
        'mode': s.paymentMode,
        'isIn': true
      });
    }

    // Add Purchases
    for (var p in ph.purchases.where((p) => _isSameDay(p.date, selectedDate))) {
      allEntries.add({
        'time': p.date,
        'type': 'PURCHASE',
        'party': p.distributorName,
        'ref': '#${p.billNo}',
        'amount': p.totalAmount,
        'mode': p.paymentMode,
        'isIn': false
      });
    }

    // Add Vouchers (Receipts & Payments)
    for (var v in ph.vouchers.where((v) => _isSameDay(v.date, selectedDate))) {
      allEntries.add({
        'time': v.date,
        'type': v.type.toUpperCase(),
        'party': v.partyName,
        'ref': v.refBillNo.isNotEmpty ? 'Agst ${v.refBillNo}' : 'Direct',
        'amount': v.amount,
        'mode': v.paymentMode,
        'isIn': v.type == 'Receipt'
      });
    }

    // Sort by time (Latest on top)
    allEntries.sort((a, b) => b['time'].compareTo(a['time']));

    // Calculate Summary
    double totalIn = allEntries.where((e) => e['isIn']).fold(0, (sum, e) => sum + e['amount']);
    double totalOut = allEntries.where((e) => !e['isIn']).fold(0, (sum, e) => sum + e['amount']);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("Daybook (Daily Register)"),
        backgroundColor: Colors.blueGrey.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () async {
              DateTime? p = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (p != null) setState(() => selectedDate = p);
            },
          )
        ],
      ),
      body: Column(
        children: [
          // --- SUMMARY HEADER ---
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade900,
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20))
            ),
            child: Column(
              children: [
                Text(DateFormat('EEEE, dd MMMM yyyy').format(selectedDate), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _summaryCol("TOTAL IN (Inflow)", totalIn, Colors.greenAccent),
                    Container(width: 1, height: 40, color: Colors.white24),
                    _summaryCol("TOTAL OUT (Outflow)", totalOut, Colors.orangeAccent),
                    Container(width: 1, height: 40, color: Colors.white24),
                    _summaryCol("NET CASH", totalIn - totalOut, Colors.white),
                  ],
                ),
              ],
            ),
          ),

          // --- TRANSACTIONS LIST ---
          Expanded(
            child: allEntries.isEmpty
                ? const Center(child: Text("No transactions recorded for this day."))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: allEntries.length,
                    itemBuilder: (c, i) {
                      final e = allEntries[i];
                      bool isIn = e['isIn'];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isIn ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                              shape: BoxShape.circle
                            ),
                            child: Icon(
                              isIn ? Icons.arrow_downward : Icons.arrow_upward,
                              color: isIn ? Colors.green : Colors.red,
                              size: 20,
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(e['type'], style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                              const Spacer(),
                              Text(e['mode'], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e['party'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                              Text("Ref: ${e['ref']}", style: const TextStyle(fontSize: 11)),
                            ],
                          ),
                          trailing: Text(
                            "${isIn ? '+' : '-'} ₹${e['amount'].toStringAsFixed(2)}",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: isIn ? Colors.green.shade700 : Colors.red.shade700
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

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.day == d2.day && d1.month == d2.month && d1.year == d2.year;
  }

  Widget _summaryCol(String label, double val, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 8, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text("₹${val.toStringAsFixed(0)}", style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16)),
      ],
    );
  }
}
