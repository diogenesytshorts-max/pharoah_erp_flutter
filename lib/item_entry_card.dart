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
  final bool allowExpired; // 🔥 NAYA: Returns ke liye expiry bypass

  const ItemEntryCard({
    super.key,
    required this.med,
    required this.srNo,
    required this.partyState, 
    this.existingItem,
    required this.onAdd,
    required this.onCancel,
    this.allowExpired = false, // 🔥 Default False (Sale Bill ke liye)
  });

  @override
  State<ItemEntryCard> createState() => _ItemEntryCardState();
}

class _ItemEntryCardState extends State<ItemEntryCard> {
  // --- Controllers ---
  final batchC = TextEditingController();
  final expC = TextEditingController();
  final mrpC = TextEditingController();
  final rateC = TextEditingController(); 
  final rateCDiscC = TextEditingController(text: "0.0");
  final qtyC = TextEditingController();
  final freeC = TextEditingController(text: "0"); 
  final gstC = TextEditingController();
  final normDiscC = TextEditingController(text: "0.0");
  final discAmtC = TextEditingController(text: "0.0"); 

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
      discAmtC.text = i.discountRupees.toStringAsFixed(2);
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

    String shopState = ph.activeCompany?.state.trim().toLowerCase() ?? "rajasthan";
    String pState = widget.partyState.trim().toLowerCase();
    bool isLocal = shopState == pState || pState.isEmpty;

    return {
      'taxable': taxable, 
      'cgst': isLocal ? totalTax / 2 : 0, 
      'sgst': isLocal ? totalTax / 2 : 0, 
      'igst': !isLocal ? totalTax : 0, 
      'total': taxable + totalTax, 
      'discountAmt': dAmt
    };
  }

  void _validateAndAdd(PharoahManager ph) {
    if (qtyC.text.isEmpty || qtyC.text == "0") return;

    // 🔥 Conditional Expiry Check: Returns ke liye bypass
    if (!widget.allowExpired && !ExpiryMaster.isSaleAllowed(expC.text)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cannot add expired batch in Sale Bill!"), backgroundColor: Colors.red));
      return;
    }

    _addItemToBill();
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
      isBreakage: widget.allowExpired, // 🔥 TAG PASSING
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    final totals = _calcTotals();
    
    // Batch Suggestions (Filtered for Expiry if not in Return mode)
    final matchingBatches = BatchSyncEngine.getFilteredBatches(ph: ph, productKey: widget.med.identityKey, hideExpired: !widget.allowExpired)
        .where((b) => b.batch.toLowerCase().contains(batchC.text.toLowerCase())).toList();

    bool isAllowed = widget.allowExpired ? true : ExpiryMaster.isSaleAllowed(expC.text);
    Color statusColor = ExpiryMaster.getStatusColor(expC.text);

    return Dialog( // 🔥 Use Dialog instead of Container for better overlay control
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        child: SingleChildScrollView( // 🔥 PREVENTS YELLOW LINES
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(child: Text("${widget.srNo}. ${widget.med.name}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.indigo))),
                IconButton(icon: const Icon(Icons.cancel, color: Colors.grey), onPressed: widget.onCancel)
              ]),
              const Divider(),

              // ROW 1: Batch & Exp
              Row(children: [
                Expanded(child: _buildInput("BATCH", batchC, onChanged: (v) => setState(() {}))),
                const SizedBox(width: 8),
                Expanded(child: _buildInput("EXP (MM/YY)", expC, onChanged: _formatExpiry, isNum: true, color: widget.allowExpired ? Colors.black : statusColor)),
              ]),

              // Batch Chips
              if (matchingBatches.isNotEmpty && widget.existingItem == null)
                Container(height: 45, margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListView(scrollDirection: Axis.horizontal, children: matchingBatches.map((b) => Padding(padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(label: Text("${b.batch} (${b.exp})"), onPressed: () {
                            setState(() { batchC.text = b.batch; expC.text = b.exp; mrpC.text = b.mrp.toString(); rateC.text = b.rate.toString(); _syncBillDiscount(true); });
                        }))).toList())),
              
              const SizedBox(height: 10),
              SegmentedButton<String>(
                segments: const [ButtonSegment(value: "A", label: Text("A")), ButtonSegment(value: "B", label: Text("B")), ButtonSegment(value: "C", label: Text("Rate C"))],
                selected: {selectedRateType},
                onSelectionChanged: (v) { setState(() { selectedRateType = v.first; _updateRateLogic(); }); },
              ),
              
              const SizedBox(height: 12),
              // ROW 2: Pricing
              Row(children: [
                if (selectedRateType == "C") ...[Expanded(child: _buildInput("C FORMULA %", rateCDiscC, isNum: true, color: Colors.purple, onChanged: (v) => _calculateRateC())), const SizedBox(width: 8)],
                Expanded(child: _buildInput("MRP", mrpC, isNum: true, onChanged: (v) { if(selectedRateType=="C") _calculateRateC(); })),
                const SizedBox(width: 8),
                Expanded(child: _buildInput("SALE RATE", rateC, isNum: true, color: Colors.blue, onChanged: (v) => _syncBillDiscount(true))),
              ]),
              
              const SizedBox(height: 12),
              // ROW 3: Quantities
              Row(children: [
                Expanded(child: _buildInput("QTY", qtyC, isNum: true, onChanged: (v) => _syncBillDiscount(true))),
                const SizedBox(width: 8),
                Expanded(child: _buildInput("FREE", freeC, isNum: true)),
                const SizedBox(width: 8),
                Expanded(child: _buildInput("GST %", gstC, isNum: true, onChanged: (v) { if(selectedRateType=="C") _calculateRateC(); })),
              ]),

              const SizedBox(height: 12),
              // ROW 4: Item Discounts
              Row(children: [
                Expanded(child: _buildInput("DISC %", normDiscC, isNum: true, color: Colors.orange.shade900, onChanged: (v) => _syncBillDiscount(true))),
                const SizedBox(width: 8),
                Expanded(child: _buildInput("DISC ₹", discAmtC, isNum: true, color: Colors.red.shade900, onChanged: (v) => _syncBillDiscount(false))),
              ]),

              const SizedBox(height: 20),
              // Summary Box
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text("Taxable: ₹${totals['taxable']!.toStringAsFixed(2)}", style: const TextStyle(fontSize: 10)),
                    Text(totals['igst']! > 0 ? "IGST: ₹${totals['igst']!.toStringAsFixed(2)}" : "CGST+SGST: ₹${(totals['cgst']! + totals['sgst']!).toStringAsFixed(2)}", style: const TextStyle(fontSize: 9, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                  ]),
                  Text("TOTAL: ₹${totals['total']!.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.green)),
                ]),
              ),

              const SizedBox(height: 15),
              SizedBox(width: double.infinity, height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: isAllowed ? Colors.green.shade800 : Colors.grey, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: (!isAllowed || qtyC.text.isEmpty || qtyC.text == "0") ? null : () => _validateAndAdd(ph),
                  child: Text(isAllowed ? (widget.existingItem != null ? "UPDATE ITEM" : "ADD TO LIST") : "BATCH EXPIRED", style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl, {bool isNum = false, Function(String)? onChanged, Color? color}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color ?? Colors.black54)),
      const SizedBox(height: 2),
      TextField(
        controller: ctrl, onChanged: onChanged, 
        keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text, 
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
        decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
      ),
    ]);
  }
}
