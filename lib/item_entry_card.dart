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

  const ItemEntryCard({
    super.key,
    required this.med,
    required this.srNo,
    required this.partyState, 
    this.existingItem,
    required this.onAdd,
    required this.onCancel,
  });

  @override
  State<ItemEntryCard> createState() => _ItemEntryCardState();
}

class _ItemEntryCardState extends State<ItemEntryCard> {
  // --- Controllers for Rate & Formula ---
  final batchC = TextEditingController();
  final expC = TextEditingController();
  final mrpC = TextEditingController();
  final rateC = TextEditingController(); // Final Unit Rate
  final rateCDiscC = TextEditingController(text: "0.0"); // 🔥 RATE C SPECIAL FORMULA BOX
  
  // --- Controllers for Billing ---
  final qtyC = TextEditingController();
  final freeC = TextEditingController(text: "0"); 
  final gstC = TextEditingController();
  
  // --- Controllers for Item Discount (Two-Way Sync) ---
  final normDiscC = TextEditingController(text: "0.0"); // Bill Disc %
  final discAmtC = TextEditingController(text: "0.0");  // Bill Disc ₹

  String selectedRateType = "A";
  String originalExp = "";

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
      originalExp = i.exp;
      mrpC.text = i.mrp.toString();
      rateC.text = i.rate.toString();
      qtyC.text = i.qty.toString();
      freeC.text = i.freeQty.toString();
      gstC.text = i.gstRate.toString();
      
      // Load Existing Discount into Two-Way Sync
      discAmtC.text = i.discountRupees.toStringAsFixed(2);
      double gross = i.rate * i.qty;
      if (gross > 0) {
        normDiscC.text = ((i.discountRupees / gross) * 100).toStringAsFixed(2);
      }
    } else {
      mrpC.text = widget.med.mrp.toString();
      gstC.text = widget.med.gst.toString();
      _updateRateLogic();
    }
  }

  // ===========================================================================
  // 🔥 RATE C SPECIAL FORMULA: MRP -> Tax Free -> Formula % = Rate
  // ===========================================================================
  void _calculateRateC() {
    double mrp = double.tryParse(mrpC.text) ?? 0.0;
    double gst = double.tryParse(gstC.text) ?? 0.0;
    double formulaDisc = double.tryParse(rateCDiscC.text) ?? 0.0;

    // Formula: MRP se tax bahar nikalna aur fir formula discount minus karna
    double baseTaxable = (mrp / (1 + (gst / 100)));
    double finalDerivedRate = baseTaxable - (baseTaxable * (formulaDisc / 100));
    
    rateC.text = finalDerivedRate.toStringAsFixed(2);
    _syncBillDiscount(true); // Sync extra discounts based on new rate
  }

  // ===========================================================================
  // 🔥 TWO-WAY BILL DISCOUNT SYNC: % <-> ₹
  // ===========================================================================
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
    if (selectedRateType == "C") { 
      _calculateRateC(); 
    } else { 
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
    double discAmt = double.tryParse(discAmtC.text) ?? 0;
    double g = double.tryParse(gstC.text) ?? 0;

    double gross = r * q;
    double taxable = gross - discAmt;
    double totalTax = taxable * (g / 100);

    String shopState = ph.activeCompany?.state.trim().toLowerCase() ?? "rajasthan";
    String partyState = widget.partyState.trim().toLowerCase();

    bool isLocal = shopState == partyState || partyState.isEmpty;

    double cgst = 0, sgst = 0, igst = 0;
    if (isLocal) {
      cgst = totalTax / 2;
      sgst = totalTax / 2;
    } else {
      igst = totalTax;
    }

    return {
      'taxable': taxable, 
      'cgst': cgst, 
      'sgst': sgst, 
      'igst': igst, 
      'total': taxable + totalTax, 
      'discountAmt': discAmt
    };
  }

  void _validateAndAdd(PharoahManager ph) {
    if (qtyC.text.isEmpty || qtyC.text == "0") return;

    BatchSyncEngine.registerBatchActivity(
      ph: ph, productKey: widget.med.identityKey, batchNo: batchC.text.trim(), 
      exp: expC.text, packing: widget.med.packing, 
      mrp: double.tryParse(mrpC.text) ?? 0, rate: double.tryParse(rateC.text) ?? 0
    );

    final history = BatchSyncEngine.getFilteredBatches(ph: ph, productKey: widget.med.identityKey);
    try {
      final existingBatch = history.firstWhere((b) => b.batch == batchC.text.trim());
      if (existingBatch.exp != expC.text) {
        originalExp = existingBatch.exp;
        _showExpiryWarning();
        return;
      }
    } catch (e) {}

    _addItemToBill();
  }

  void _showExpiryWarning() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Expiry Mismatch!", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text("Records show $originalExp. Overwrite with ${expC.text}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
          TextButton(onPressed: () { expC.text = originalExp; Navigator.pop(c); _addItemToBill(); }, child: Text("USE OLD ($originalExp)")),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () { Navigator.pop(c); _addItemToBill(); }, child: const Text("USE NEW", style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  void _addItemToBill() {
    final t = _calcTotals();
    widget.onAdd(BillItem(
      id: widget.existingItem?.id ?? DateTime.now().toString(),
      srNo: widget.srNo,
      medicineID: widget.med.id,
      name: widget.med.name,
      packing: widget.med.packing,
      batch: batchC.text.trim(),
      exp: expC.text,
      hsn: widget.med.hsnCode,
      mrp: double.tryParse(mrpC.text) ?? 0,
      qty: double.tryParse(qtyC.text) ?? 0,
      freeQty: double.tryParse(freeC.text) ?? 0,
      rate: double.tryParse(rateC.text) ?? 0,
      gstRate: double.tryParse(gstC.text) ?? 0,
      cgst: t['cgst']!,
      sgst: t['sgst']!,
      igst: t['igst']!,
      total: t['total']!,
      discountRupees: t['discountAmt']!,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    final totals = _calcTotals();
    final matchingBatches = BatchSyncEngine.getFilteredBatches(ph: ph, productKey: widget.med.identityKey, hideExpired: true)
        .where((b) => b.batch.toLowerCase().contains(batchC.text.toLowerCase())).toList();

    String expStr = expC.text;
    Color statusColor = ExpiryMaster.getStatusColor(expStr);
    bool isAllowed = ExpiryMaster.isSaleAllowed(expStr);

    return Container(
      padding: const EdgeInsets.all(15),
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text("${widget.srNo}. ${widget.med.name}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            IconButton(icon: const Icon(Icons.cancel, color: Colors.grey), onPressed: widget.onCancel)
          ]),

          Row(children: [
            Expanded(child: _buildInput("BATCH", batchC, onChanged: (v) => setState(() {}))),
            const SizedBox(width: 8),
            Expanded(child: _buildInput("EXPIRY (MM/YY)", expC, onChanged: _formatExpiry, isNum: true, color: statusColor)),
            const SizedBox(width: 8),
            Expanded(child: _buildInput("GST %", gstC, isNum: true, onChanged: (v){ if(selectedRateType=="C") _calculateRateC(); setState((){}); })),
          ]),

          if (matchingBatches.isNotEmpty && widget.existingItem == null)
            Container(height: 45, margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListView(scrollDirection: Axis.horizontal, children: matchingBatches.map((b) => Padding(padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text("${b.batch} (${b.exp})"),
                      onPressed: () {
                        setState(() {
                          batchC.text = b.batch; expC.text = b.exp; originalExp = b.exp;
                          mrpC.text = b.mrp.toString(); rateC.text = b.rate.toString();
                          if (selectedRateType == "C") _calculateRateC();
                          else _syncBillDiscount(true);
                        });
                      },
                    ))).toList())),
          
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: const [ButtonSegment(value: "A", label: Text("Rate A")), ButtonSegment(value: "B", label: Text("Rate B")), ButtonSegment(value: "C", label: Text("Rate C"))],
            selected: {selectedRateType},
            onSelectionChanged: (v) { setState(() { selectedRateType = v.first; _updateRateLogic(); }); },
          ),
          
          const SizedBox(height: 12),
          // --- ROW 3: Derived Selling Rate Section ---
          Row(children: [
            if (selectedRateType == "C") ...[
              Expanded(child: _buildInput("C FORMULA %", rateCDiscC, isNum: true, color: Colors.purple, onChanged: (v) => _calculateRateC())),
              const SizedBox(width: 8),
            ],
            Expanded(child: _buildInput("MRP", mrpC, isNum: true, onChanged: (v) { if(selectedRateType=="C") _calculateRateC(); })),
            const SizedBox(width: 8),
            Expanded(child: _buildInput("RATE", rateC, isNum: true, isReadOnly: selectedRateType == "C", color: Colors.blue, onChanged: (v) => _syncBillDiscount(true))),
          ]),
          
          const SizedBox(height: 8),
          // --- ROW 4: Qty & Bill Adjustment Section ---
          Row(
            children: [
              Expanded(child: _buildInput("QTY", qtyC, isNum: true, isReadOnly: widget.existingItem?.sourceChallanNo.isNotEmpty ?? false, onChanged: (v) => _syncBillDiscount(true))),
              const SizedBox(width: 8),
              Expanded(child: _buildInput("FREE", freeC, isNum: true)),
              const SizedBox(width: 8),
              Expanded(child: _buildInput("BILL DISC %", normDiscC, isNum: true, color: Colors.orange.shade900, onChanged: (v) => _syncBillDiscount(true))),
              const SizedBox(width: 8),
              Expanded(child: _buildInput("BILL DISC ₹", discAmtC, isNum: true, color: Colors.red.shade900, onChanged: (v) => _syncBillDiscount(false))),
          ]),

          const SizedBox(height: 15),
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Taxable: ₹${totals['taxable']!.toStringAsFixed(2)}", style: const TextStyle(fontSize: 10)),
                Text(totals['igst']! > 0 ? "IGST: ₹${totals['igst']!.toStringAsFixed(2)}" : "CGST+SGST: ₹${(totals['cgst']! + totals['sgst']!).toStringAsFixed(2)}", style: const TextStyle(fontSize: 9, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
              ]),
              Text("TOTAL: ₹${totals['total']!.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.green)),
            ]),
          ),

          const SizedBox(height: 15),
          SizedBox(width: double.infinity, height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: isAllowed ? Colors.green : Colors.grey.shade400, foregroundColor: Colors.white),
              onPressed: (!isAllowed || qtyC.text.isEmpty || qtyC.text == "0") ? null : () => _validateAndAdd(ph),
              child: Text(widget.existingItem != null ? "UPDATE ITEM" : "ADD TO BILL", style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl, {bool isNum = false, Function(String)? onChanged, bool isReadOnly = false, Color? color}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color ?? Colors.black54)),
        const SizedBox(height: 2),
        TextField(
          controller: ctrl, readOnly: isReadOnly, 
          keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text, 
          onChanged: onChanged, 
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
          decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(5)), filled: isReadOnly, fillColor: isReadOnly ? Colors.grey.shade100 : Colors.white),
        ),
      ],
    );
  }
}
