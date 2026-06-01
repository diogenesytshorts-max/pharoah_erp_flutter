// FILE: lib/item_entry_card.dart (NEW COMPACT REDESIGNED VERSION)

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
  final rateCDiscC = TextEditingController(text: "0.0");
  final qtyC = TextEditingController();
  final freeC = TextEditingController(text: "0"); 
  final gstC = TextEditingController();
  final normDiscC = TextEditingController(text: "0.0");
  final discAmtC = TextEditingController(text: "0.0"); 

  String selectedRateType = "A";
  bool hideZeroStock = true; 

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
      
      selectedRateType = i.appliedRateType; 
      rateCDiscC.text = i.rateCFormula.toString();
      normDiscC.text = i.discountPer.toString();
      
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
    double finalDerivedRate = baseTaxable - (baseTaxable * (formulaDisc / 100));
    rateC.text = finalDerivedRate.toStringAsFixed(2);
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

    final rawBatches = BatchSyncEngine.getFilteredBatches(
      ph: ph, 
      productKey: widget.med.identityKey, 
      hideExpired: !widget.allowExpired
    );

    final matchingBatches = rawBatches.where((b) {
      bool matchesSearch = b.batch.toLowerCase().contains(batchC.text.toLowerCase());
      if (!matchesSearch) return false;
      if (ph.showBatchFilter && hideZeroStock && b.qty <= 0) {
        return false; 
      }
      return true;
    }).toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 440,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 25,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "ITEM MASTER CONFIG",
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w900,
                            fontSize: 9,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${widget.srNo}. ${widget.med.name}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    style: IconButton.styleFrom(backgroundColor: const Color(0xFFF1F5F9)),
                    icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                    onPressed: widget.onCancel,
                  )
                ],
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: Batch & Expiry
                    Row(
                      children: [
                        Expanded(child: _modernInput("BATCH (Random Case)", batchC, onChanged: (v) => setState(() {}))),
                        const SizedBox(width: 12),
                        Expanded(child: _modernInput("EXPIRY (MM/YY)", expC, isNum: true, onChanged: _formatExpiry)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Conditional Batch Filter Header
                    if (ph.showBatchFilter && widget.existingItem == null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("AVAILABLE BATCHES", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                          InkWell(
                            onTap: () => setState(() => hideZeroStock = !hideZeroStock),
                            child: Row(
                              children: [
                                Icon(
                                  hideZeroStock ? Icons.check_box : Icons.check_box_outline_blank, 
                                  size: 14, 
                                  color: const Color(0xFF2563EB),
                                ),
                                const SizedBox(width: 4),
                                const Text("Hide Zero Stock", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                              ],
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],

                    if (matchingBatches.isNotEmpty && widget.existingItem == null) ...[
                      SizedBox(
                        height: 36,
                        child: ListView(
                          scrollDirection: Axis.horizontal, 
                          children: matchingBatches.map((b) => Padding(
                            padding: const EdgeInsets.only(right: 8), 
                            child: ActionChip(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              backgroundColor: const Color(0xFFEFF6FF),
                              side: const BorderSide(color: Color(0xFFBFDBFE)),
                              label: Text(
                                "${b.batch} (${b.qty.toInt()} Tab)",
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                              ),
                              onPressed: () {
                                setState(() { 
                                  batchC.text = b.batch; expC.text = b.exp; 
                                  mrpC.text = b.mrp.toString(); rateC.text = b.rate.toString(); 
                                  _updateRateLogic();
                                });
                              }
                            )
                          )).toList()
                        )
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Segmented Selector
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<String>(
                        style: SegmentedButton.styleFrom(
                          selectedBackgroundColor: const Color(0xFF0F172A),
                          selectedForegroundColor: Colors.white,
                        ),
                        segments: const [
                          ButtonSegment(value: "A", label: Text("Rate A", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          ButtonSegment(value: "B", label: Text("Rate B", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          ButtonSegment(value: "C", label: Text("Rate C", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        ],
                        selected: {selectedRateType},
                        onSelectionChanged: (v) { setState(() { selectedRateType = v.first; _updateRateLogic(); }); },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Inputs Row
                    Row(
                      children: [
                        if (selectedRateType == "C") ...[
                          Expanded(child: _modernInput("C DISC%", rateCDiscC, isNum: true, onChanged: (v) => _calculateRateC())),
                          const SizedBox(width: 12),
                        ],
                        Expanded(child: _modernInput("MRP", mrpC, isNum: true, onChanged: (v) { if(selectedRateType=="C") _calculateRateC(); })),
                        const SizedBox(width: 12),
                        Expanded(child: _modernInput("UNIT RATE", rateC, isNum: true, isReadOnly: selectedRateType == "C", onChanged: (v) => _syncBillDiscount(true))),
                        const SizedBox(width: 12),
                        Expanded(child: _modernInput("GST %", gstC, isReadOnly: true)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(child: _modernInput("QUANTITY", qtyC, isNum: true, onChanged: (v) => _syncBillDiscount(true))),
                        const SizedBox(width: 12),
                        Expanded(child: _modernInput("FREE QTY", freeC, isNum: true)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(child: _modernInput("DISCOUNT %", normDiscC, isNum: true, onChanged: (v) => _syncBillDiscount(true))),
                        const SizedBox(width: 12),
                        Expanded(child: _modernInput("DISCOUNT ₹", discAmtC, isNum: true, onChanged: (v) => _syncBillDiscount(false))),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Net Total Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "NET ITEM TOTAL",
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                          Text(
                            "₹ ${totals['total']!.toStringAsFixed(2)}",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.greenAccent.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ), 
                        onPressed: () {
                           widget.onAdd(BillItem(
                              id: widget.existingItem?.id ?? DateTime.now().toString(),
                              srNo: widget.srNo, medicineID: widget.med.id, name: widget.med.name, packing: widget.med.packing,
                              batch: batchC.text.trim(), 
                              exp: expC.text, hsn: widget.med.hsnCode, mrp: double.tryParse(mrpC.text) ?? 0,
                              qty: double.tryParse(qtyC.text) ?? 0, freeQty: double.tryParse(freeC.text) ?? 0,
                              rate: double.tryParse(rateC.text) ?? 0, gstRate: double.tryParse(gstC.text) ?? 0,
                              cgst: totals['cgst']!, sgst: totals['sgst']!, igst: totals['igst']!, total: totals['total']!,
                              discountRupees: totals['discountAmt']!, 
                              discountPer: double.tryParse(normDiscC.text) ?? 0.0,
                              appliedRateType: selectedRateType, 
                              rateCFormula: double.tryParse(rateCDiscC.text) ?? 0.0, 
                              isBreakage: widget.allowExpired
                           ));
                        }, 
                        child: const Text("CONFIRM & ADD", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.0))
                      ),
                    )
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _modernInput(
    String label,
    TextEditingController ctrl, {
    bool isNum = false,
    bool isReadOnly = false,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: Color(0xFF64748B),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          readOnly: isReadOnly,
          onChanged: onChanged,
          keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: isReadOnly ? const Color(0xFF64748B) : const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: isReadOnly ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
