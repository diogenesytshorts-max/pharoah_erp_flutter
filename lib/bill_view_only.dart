import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'pdf/sale_invoice_pdf.dart';

class BillViewOnly extends StatelessWidget {
  final Sale sale;
  final Party party;

  const BillViewOnly({super.key, required this.sale, required this.party});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: Text("Bill: ${sale.billNo}"),
        backgroundColor: Colors.purple.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => SaleInvoicePdf.generate(sale, party),
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(party.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.purple)),
                  Text(DateFormat('dd/MM/yyyy').format(sale.date), style: const TextStyle(fontWeight: FontWeight.bold)),
                ]),
                const Divider(),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text("Mode: ${sale.paymentMode}"),
                  Text("GSTIN: ${sale.partyGstin}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ]),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: sale.items.length,
              itemBuilder: (c, i) {
                final it = sale.items[i];
                return Card(
                  child: ListTile(
                    title: Text(it.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("Batch: ${it.batch} | Exp: ${it.exp} | Qty: ${it.qty.toInt()}"),
                    trailing: Text("₹${it.total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.purple.shade50,
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text("GRAND TOTAL", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("₹${sale.totalAmount.toStringAsFixed(2)}", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.purple.shade900)),
            ]),
          ),
        ],
      ),
    );
  }
}
