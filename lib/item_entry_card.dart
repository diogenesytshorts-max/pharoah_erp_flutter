// FILE: lib/item_entry_card.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models.dart';
import 'pharoah_manager.dart';
import 'expiry_master.dart';
import 'batch_sync_engine.dart';

class ItemEntryCard extends StatefulWidget {
  final Medicine med;
  final int srNo;
  final String partyState; 
  final BillItem? existingItem;
  final Function(BillItem) onAdd;
  final VoidCallback onCancel;
  final bool allowExpired; 

  const ItemEntryCard({
    super.key,
    required this.med,
    required this.srNo,
    required this.partyState, 
    this.existingItem,
    required this.onAdd,
    required this.onCancel,
    this.allowExpired = false, 
  });

  @override
  State<ItemEntryCard> createState() => _ItemEntryCardState();
}

class _ItemEntryCardState extends State<ItemEntryCard> {
  final batchC = TextEditingController();
  final expC = TextEditingController();
  final mrpC = TextEditingController();
  final rateC = TextEditingController(); 
  final rateCDiscC = TextEditingController(text: "0.0"); // Formula memory
  final qtyC = TextEditingController();
  final freeC = TextEditingController(text: "0"); 
  final gstC = TextEditingController();
  final normDiscC = TextEditingController(text: "0.0"); // % memory
  final discAmtC = TextEditingController(text: "0.0"); 

  String selectedRateType = "A";

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
      
      // 🔥 MEMORY LOAD: Selection and Formula
      selectedRateType = i.appliedRateType;
      rateCDiscC.text = i.rateCFormula.toString();
      normDiscC.text = i.discountPer.toString();
      
      // Load current Rs based on saved %
      _syncBillDiscount(true); 
    } else {
      mrpC.text = widget.med.mrp.toString();
      gstC.text = widget.med.gst.toString();
      _updateRateLogic();
    }
  }

  void _calculateRateC() {
    double mrp = double.tryParse(mrpC.text) ?? 0.0;
    double gst = double.tryParse(gstC.text) ?? 0.0;
    double formulaDisc = double.tryParse(rateCDiscC.text) ?? 0.0;
    double baseTaxable = (mrp / (1 + (gst / 100)));
    double finalRate = baseTaxable - (baseTaxable * (formulaDisc / 100));
    rateC.text = finalRate.toStringAsFixed(2);
    _syncBillDiscount(true);
  }

  void _syncBillDiscount(bool isPercentSource) {
    double q = double.tryParse(qtyC.text) ?? 0;
    double r = double.tryParse(rateC.text) ?? 0;
    double gross = q * r;
    if (gross <= 0) return;
    if (isPercentSource) {
      double p = double.tryParse(normDiscC.text) ?? 0;
      discAmtC.text = (gross * (p / 100)).toStringAsFixed(2);
    } else {
      double a = double.tryParse(discAmtC.text) ?? 0;
      normDiscC.text = ((a / gross) * 100).toStringAsFixed(2);
    }
    setState(() {});
  }

  void _updateRateLogic() {
    if (selectedRateType == "C") { _calculateRateC(); } 
    else { 
      rateC.text = selectedRateType == "A" ? widget.med.rateA.toString() : widget.med.rateB.toString(); 
      _syncBillDiscount(true);
    }
    setState(() {});
  }

  void _formatExpiry(String val) {
    String text = val.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.length >= 2 && !val.contains('/')) { text = '${text.substring(0, 2)}/${text.substring(2)}'; }
    if (text.length > 5) text = text.substring(0, 5);
    if (expC.text != text) {
      expC.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
    }
    setState(() {});
  }

  Map<String, double> _calcTotals() {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    double q = double.tryParse(qtyC.text) ?? 0;
    double r = double.tryParse(rateC.text) ?? 0;
    double dAmt = double.tryParse(discAmtC.text) ?? 0;
    double g = double.tryParse(gstC.text) ?? 0;
    double gross = r * q;
    double taxable = gross - dAmt;
    double totalTax = taxable * (g / 100);
    bool isLocal = (ph.activeCompany?.state.toLowerCase() == widget.partyState.toLowerCase());
    return {
      'taxable': taxable, 
      'cgst': isLocal ? totalTax / 2 : 0, 'sgst': isLocal ? totalTax / 2 : 0, 'igst': !isLocal ? totalTax : 0, 
      'total': taxable + totalTax, 'discountAmt': dAmt
    };
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    final totals = _calcTotals();
    final matchingBatches = BatchSyncEngine.getFilteredBatches(ph: ph, productKey: widget.med.identityKey, hideExpired: !widget.allowExpired)
        .where((b) => b.batch.toLowerCase().contains(batchC.text.toLowerCase())).toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 500, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text("${widget.srNo}. ${widget.med.name}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              IconButton(icon: const Icon(Icons.close), onPressed: widget.onCancel)
            ]),
            const Divider(),
            Row(children: [
              Expanded(child: _modernInput("BATCH", batchC, onChanged: (v)=>setState((){}))),
              const SizedBox(width: 8),
              Expanded(child: _modernInput("EXPIRY", expC, isNum: true, onChanged: _formatExpiry)),
            ]),
            const SizedBox(height: 15),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: "A", label: Text("Rate A")),
                ButtonSegment(value: "B", label: Text("Rate B")),
                ButtonSegment(value: "C", label: Text("Rate C")),
              ],
              selected: {selectedRateType},
              onSelectionChanged: (v) { setState(() { selectedRateType = v.first; _updateRateLogic(); }); },
            ),
            const SizedBox(height: 15),
            Row(children: [
              if (selectedRateType == "C") ...[
                Expanded(child: _modernInput("C FORMULA %", rateCDiscC, isNum: true, onChanged: (v) => _calculateRateC())),
                const SizedBox(width: 8),
              ],
              Expanded(child: _modernInput("MRP", mrpC, isNum: true)),
              const SizedBox(width: 8),
              Expanded(child: _modernInput("FINAL RATE", rateC, isNum: true, isReadOnly: selectedRateType == "C", onChanged: (v) => _syncBillDiscount(true))),
            ]),
            const SizedBox(height: 15),
            Row(children: [
              Expanded(child: _modernInput("QTY", qtyC, isNum: true, onChanged: (v) => _syncBillDiscount(true))),
              const SizedBox(width: 8),
              Expanded(child: _modernInput("FREE", freeC, isNum: true)),
            ]),
            const SizedBox(height: 15),
            Row(children: [
              Expanded(child: _modernInput("DISC %", normDiscC, isNum: true, onChanged: (v) => _syncBillDiscount(true))),
              const SizedBox(width: 8),
              Expanded(child: _modernInput("DISC ₹", discAmtC, isNum: true, onChanged: (v) => _syncBillDiscount(false))),
            ]),
            const SizedBox(height: 25),
            Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.blueGrey.shade900, borderRadius: BorderRadius.circular(15)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text("ITEM TOTAL", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
              Text("₹${totals['total']!.toStringAsFixed(2)}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
            ])),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, height: 55, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white), 
            onPressed: () {
               // 🔥 MEMORY SAVE: Storing choices
               widget.onAdd(BillItem(
                  id: widget.existingItem?.id ?? DateTime.now().toString(),
                  srNo: widget.srNo, medicineID: widget.med.id, name: widget.med.name, packing: widget.med.packing,
                  batch: batchC.text.trim(), exp: expC.text, hsn: widget.med.hsnCode, mrp: double.tryParse(mrpC.text) ?? 0,
                  qty: double.tryParse(qtyC.text) ?? 0, freeQty: double.tryParse(freeC.text) ?? 0,
                  rate: double.tryParse(rateC.text) ?? 0, gstRate: double.tryParse(gstC.text) ?? 0,
                  cgst: totals['cgst']!, sgst: totals['sgst']!, igst: totals['igst']!, total: totals['total']!,
                  discountRupees: totals['discountAmt']!, discountPer: double.tryParse(normDiscC.text) ?? 0.0,
                  appliedRateType: selectedRateType, // Memory
                  rateCFormula: double.tryParse(rateCDiscC.text) ?? 0.0, // Memory
               ));
            }, child: const Text("UPDATE ITEM", style: TextStyle(fontWeight: FontWeight.bold))))
          ]),
        ),
      ),
    );
  }

  Widget _modernInput(String l, TextEditingController c, {bool isNum = false, Function(String)? onChanged, bool isReadOnly = false}) => TextField(controller: c, readOnly: isReadOnly, onChanged: onChanged, keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text, decoration: InputDecoration(labelText: l, border: const OutlineInputBorder(), isDense: true));
}
