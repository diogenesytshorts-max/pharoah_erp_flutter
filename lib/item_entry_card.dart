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
      'cgst': isLocal ? totalTax / 2 : 0, 'sgst': isLocal ? totalTax / 2 : 0, 'igst': !isLocal ? totalTax : 0, 
      'total': taxable + totalTax, 'discountAmt': dAmt
    };
  }

  void _validateAndAdd(PharoahManager ph) {
    if (qtyC.text.isEmpty || qtyC.text == "0") return;

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
      srNo: widget.srNo, medicineID: widget.med.id, name: widget.med.name, packing: widget.med.packing,
      batch: batchC.text.trim(), exp: expC.text, hsn: widget.med.hsnCode, mrp: double.tryParse(mrpC.text) ?? 0,
      qty: double.tryParse(qtyC.text) ?? 0, freeQty: double.tryParse(freeC.text) ?? 0,
      rate: double.tryParse(rateC.text) ?? 0, gstRate: double.tryParse(gstC.text) ?? 0,
      cgst: t['cgst']!, sgst: t['sgst']!, igst: t['igst']!, total: t['total']!,
      discountRupees: t['discountAmt']!, isBreakage: widget.allowExpired,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    final totals = _calcTotals();
    final matchingBatches = BatchSyncEngine.getFilteredBatches(ph: ph, productKey: widget.med.identityKey, hideExpired: !widget.allowExpired)
        .where((b) => b.batch.toLowerCase().contains(batchC.text.toLowerCase())).toList();

    bool isAllowed = widget.allowExpired ? true : ExpiryMaster.isSaleAllowed(expC.text);
    Color statusColor = widget.allowExpired ? Color(0xFF0891B2) : ExpiryMaster.getStatusColor(expC.text);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
      child: Container(
        width: 500,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 10))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Enterprise Header
            Container(
              padding: const EdgeInsets.all(20), width: double.infinity, color: const Color(0xFFF8FAFC),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("PRODUCT CONFIGURATION", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 2)),
                  const SizedBox(height: 4),
                  Text("${widget.srNo}. ${widget.med.name}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)), overflow: TextOverflow.ellipsis),
                ])),
                IconButton(icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)), onPressed: widget.onCancel)
              ]),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(25),
                child: Column(children: [
                  // Row 1: Batch & Exp
                  Row(children: [
                    Expanded(child: _modernInput("BATCH", batchC, const Color(0xFF475569), onChanged: (v)=>setState((){}))),
                    const SizedBox(width: 12),
                    Expanded(child: _modernInput("EXPIRY", expC, statusColor, isNum: true, onChanged: _formatExpiry)),
                  ]),
                  
                  if (matchingBatches.isNotEmpty && widget.existingItem == null)
                    Container(height: 40, margin: const EdgeInsets.only(top: 15),
                      child: ListView(scrollDirection: Axis.horizontal, children: matchingBatches.map((b) => Padding(padding: const EdgeInsets.only(right: 8),
                            child: ActionChip(
                              label: Text(b.batch, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), 
                              onPressed: () {
                                setState(() { batchC.text = b.batch; expC.text = b.exp; mrpC.text = b.mrp.toString(); rateC.text = b.rate.toString(); _syncBillDiscount(true); });
                            }))).toList())),

                  const SizedBox(height: 20),
                  // Row 2: MRP & GST
                  Row(children: [
                    Expanded(child: _modernInput("MRP", mrpC, const Color(0xFFBE185D), isNum: true, isBold: true, onChanged: (v) { if(selectedRateType=="C") _calculateRateC(); })),
                    const SizedBox(width: 12),
                    Expanded(child: _modernInput("GST %", gstC, const Color(0xFF6366F1), isNum: true, onChanged: (v) { if(selectedRateType=="C") _calculateRateC(); })),
                  ]),
                  
                  const SizedBox(height: 25),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: "A", label: Text("Rate A")),
                      ButtonSegment(value: "B", label: Text("Rate B")),
                      ButtonSegment(value: "C", label: Text("Rate C")),
                    ],
                    selected: {selectedRateType},
                    onSelectionChanged: (v) { setState(() { selectedRateType = v.first; _updateRateLogic(); }); },
                  ),
                  
                  const SizedBox(height: 25),
                  // Row 3: Rates
                  Row(children: [
                    if (selectedRateType == "C") ...[
                      Expanded(child: _modernInput("C FORMULA %", rateCDiscC, const Color(0xFF7C3AED), isNum: true, onChanged: (v) => _calculateRateC())),
                      const SizedBox(width: 12),
                    ],
                    Expanded(child: _modernInput("FINAL RATE", rateC, const Color(0xFF2563EB), isNum: true, isReadOnly: selectedRateType == "C", onChanged: (v) => _syncBillDiscount(true))),
                  ]),

                  const SizedBox(height: 20),
                  // Row 4: Quantity & Free
                  Row(children: [
                    Expanded(child: _modernInput("QUANTITY", qtyC, const Color(0xFF059669), isNum: true, hasFocus: true, onChanged: (v) => _syncBillDiscount(true))),
                    const SizedBox(width: 12),
                    Expanded(child: _modernInput("FREE QTY", freeC, const Color(0xFF059669), isNum: true)),
                  ]),

                  const SizedBox(height: 20),
                  // Row 5: Bill Discounts
                  Row(children: [
                    Expanded(child: _modernInput("DISC %", normDiscC, const Color(0xFFEA580C), isNum: true, onChanged: (v) => _syncBillDiscount(true))),
                    const SizedBox(width: 12),
                    Expanded(child: _modernInput("DISC ₹", discAmtC, const Color(0xFFBE185D), isNum: true, onChanged: (v) => _syncBillDiscount(false))),
                  ]),

                  const SizedBox(height: 35),
                  // Final High-Impact Summary Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                         const Text("ITEM TOTAL (NET)", style: TextStyle(color: Colors.white60, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                         Text("GST Breakdown Applied", style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 8)),
                      ]),
                      Text("₹${totals['total']!.toStringAsFixed(2)}", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
                    ]),
                  ),

                  const SizedBox(height: 25),
                  SizedBox(width: double.infinity, height: 60, child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAllowed ? const Color(0xFF2563EB) : Colors.grey, 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 0,
                    ),
                    onPressed: (!isAllowed || qtyC.text.isEmpty || qtyC.text == "0") ? null : () => _validateAndAdd(ph),
                    child: Text(isAllowed ? "UPDATE & SAVE" : "BATCH EXPIRED", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
                  ))
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _modernInput(String label, TextEditingController ctrl, Color accentColor, {bool isBold = false, bool hasFocus = false, bool isNum = false, Function(String)? onChanged, bool isReadOnly = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(left: 4, bottom: 6), child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: accentColor.withOpacity(0.8)))),
      TextField(
        controller: ctrl, readOnly: isReadOnly, onChanged: onChanged,
        keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        style: TextStyle(fontSize: 14, fontWeight: isBold || hasFocus ? FontWeight.w900 : FontWeight.w700, color: const Color(0xFF1E293B)),
        decoration: InputDecoration(
          isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14), 
          filled: true, fillColor: hasFocus ? accentColor.withOpacity(0.05) : const Color(0xFFF8FAFC),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accentColor, width: 2.5)),
        ),
      ),
    ]);
  }
}
