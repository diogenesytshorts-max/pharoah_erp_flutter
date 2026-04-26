// FILE: lib/staff_modules/staff_item_entry_card.dart

import 'package:flutter/material.dart';
import '../models.dart';

class StaffItemEntryCard extends StatefulWidget {
  final Medicine med;
  final int srNo;
  final BillItem? existingItem;
  final Function(BillItem) onAdd;
  final VoidCallback onCancel;

  const StaffItemEntryCard({
    super.key,
    required this.med,
    required this.srNo,
    this.existingItem,
    required this.onAdd,
    required this.onCancel,
  });

  @override
  State<StaffItemEntryCard> createState() => _StaffItemEntryCardState();
}

class _StaffItemEntryCardState extends State<StaffItemEntryCard> {
  final batchC = TextEditingController();
  final expC = TextEditingController();
  final mrpC = TextEditingController();
  final rateC = TextEditingController();
  final qtyC = TextEditingController();
  final freeC = TextEditingController(text: "0");
  final gstC = TextEditingController();
  final normDiscC = TextEditingController(text: "0.0");

  @override
  void initState() {
    super.initState();
    _setupInitialData();
  }

  void _setupInitialData() {
    if (widget.existingItem != null) {
      final i = widget.existingItem!;
      batchC.text = i.batch;
      expC.text = i.exp;
      mrpC.text = i.mrp.toString();
      rateC.text = i.rate.toString();
      qtyC.text = i.qty.toString();
      freeC.text = i.freeQty.toString();
      gstC.text = i.gstRate.toString();
    } else {
      mrpC.text = widget.med.mrp.toString();
      rateC.text = widget.med.rateA.toString(); 
      gstC.text = widget.med.gst.toString();
    }
  }

  Map<String, double> _calcTotals() {
    double q = double.tryParse(qtyC.text) ?? 0;
    double r = double.tryParse(rateC.text) ?? 0;
    double d = double.tryParse(normDiscC.text) ?? 0;
    double g = double.tryParse(gstC.text) ?? 0;

    double gross = r * q;
    double discAmt = gross * (d / 100);
    double taxable = gross - discAmt;
    double taxAmt = taxable * (g / 100);
    
    return {'total': taxable + taxAmt, 'discountAmt': discAmt};
  }

  @override
  Widget build(BuildContext context) {
    final totals = _calcTotals();

    return Container(
      padding: const EdgeInsets.all(15),
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${widget.srNo}. ${widget.med.name}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              IconButton(icon: const Icon(Icons.cancel, color: Colors.grey), onPressed: widget.onCancel)
            ],
          ),
          const Divider(),
          Row(
            children: [
              Expanded(child: _input(batchC, "BATCH", Icons.layers)),
              const SizedBox(width: 8),
              Expanded(child: _input(expC, "EXPIRY", Icons.event)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _input(mrpC, "MRP", Icons.tag, isReadOnly: true)),
              const SizedBox(width: 8),
              Expanded(child: _input(rateC, "SALE RATE", Icons.payments, color: Colors.blue)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _input(qtyC, "QTY", Icons.add_box, isNum: true)),
              const SizedBox(width: 8),
              // FIXED: Icons.card_giftcard used instead of giftcard
              Expanded(child: _input(freeC, "FREE", Icons.card_giftcard, isNum: true)),
              const SizedBox(width: 8),
              Expanded(child: _input(normDiscC, "DISC %", Icons.percent, isNum: true)),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Net Amount:", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("₹${totals['total']!.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: () {
                if (qtyC.text.isEmpty || qtyC.text == "0") return;
                widget.onAdd(BillItem(
                  id: widget.existingItem?.id ?? DateTime.now().toString(),
                  srNo: widget.srNo,
                  medicineID: widget.med.id,
                  name: widget.med.name,
                  packing: widget.med.packing,
                  batch: batchC.text.toUpperCase(),
                  exp: expC.text,
                  hsn: widget.med.hsnCode,
                  mrp: double.tryParse(mrpC.text) ?? 0,
                  qty: double.tryParse(qtyC.text) ?? 0,
                  freeQty: double.tryParse(freeC.text) ?? 0,
                  rate: double.tryParse(rateC.text) ?? 0,
                  gstRate: double.tryParse(gstC.text) ?? 0,
                  total: totals['total']!,
                  discountRupees: totals['discountAmt']!,
                ));
              },
              child: const Text("ADD TO BILL", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _input(TextEditingController ctrl, String label, IconData icon, {bool isNum = false, bool isReadOnly = false, Color? color}) {
    return TextField(
      controller: ctrl,
      readOnly: isReadOnly,
      keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13),
      decoration: InputDecoration(
        labelText: label, 
        prefixIcon: Icon(icon, size: 16),
        border: const OutlineInputBorder(), 
        isDense: true,
        filled: isReadOnly,
        fillColor: isReadOnly ? Colors.grey.shade100 : Colors.white,
      ),
    );
  }
}
