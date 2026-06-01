// FILE: lib/staff_modules/staff_item_entry_card.dart (ROYAL COBALT + BACKDROP BLUR)

import 'dart:ui'; // Backdrop Filter के ब्लर इफ़ेक्ट के लिए अनिवार्य
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../pharoah_manager.dart';
import '../batch_sync_engine.dart'; 
import '../expiry_master.dart';    

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
    } else {
      mrpC.text = widget.med.mrp.toString();
      rateC.text = widget.med.rateA.toString(); 
      gstC.text = widget.med.gst.toString();
    }
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
    final ph = Provider.of<PharoahManager>(context);
    final totals = _calcTotals();

    // Vibrant Royal Cobalt Theme Colors
    const Color brandDark = Color(0xFF1E1B4B); 
    const Color accentElectric = Color(0xFF3B82F6); 
    const Color neonGreen = Color(0xFF10B981); 

    final rawBatches = BatchSyncEngine.getFilteredBatches(
      ph: ph, 
      productKey: widget.med.identityKey,
      hideExpired: true 
    );

    final matchingBatches = rawBatches.where((b) {
      bool matchesSearch = b.batch.toLowerCase().contains(batchC.text.toLowerCase());
      if (!matchesSearch) return false;
      if (ph.showBatchFilter && hideZeroStock && b.qty <= 0) {
        return false;
      }
      return true;
    }).toList();

    String expStr = expC.text;
    ExpiryStatus expStatus = ExpiryMaster.getStatus(expStr);
    Color statusColor = ExpiryMaster.getStatusColor(expStr);
    bool isAllowed = ExpiryMaster.isSaleAllowed(expStr);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          width: 440,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: accentElectric.withOpacity(0.4), width: 1.5),
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
                  gradient: LinearGradient(
                    colors: [brandDark, Color(0xFF312E81)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "STAFF BILLING ENTRY",
                            style: TextStyle(
                              color: Color(0xFF818CF8),
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
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      style: IconButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.1)),
                      icon: const Icon(Icons.close_rounded, size: 20, color: Colors.white70),
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
                          Expanded(child: _vibrantInput("BATCH (Case-Sensitive)", batchC, accentElectric, false, onChanged: (v) => setState(() {}))),
                          const SizedBox(width: 12),
                          Expanded(child: _vibrantInput("EXPIRY (MM/YY)", expC, accentElectric, false, isNum: true, labelColor: statusColor, onChanged: _formatExpiry)),
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
                                    color: accentElectric,
                                  ),
                                  const SizedBox(width: 4),
                                  const Text("Hide Zero Stock", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: accentElectric)),
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
                                  });
                                }
                              )
                            )).toList()
                          )
                        ),
                        const SizedBox(height: 16),
                      ],

                      Row(
                        children: [
                          Expanded(child: _vibrantInput("MRP", mrpC, accentElectric, true)),
                          const SizedBox(width: 12),
                          Expanded(child: _vibrantInput("SALE RATE", rateC, accentElectric, false, isNum: true, labelColor: Colors.blue)),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(child: _vibrantInput("QUANTITY", qtyC, accentElectric, false, isNum: true, highlight: true, onChanged: (v) => setState(() {}))),
                          const SizedBox(width: 12),
                          Expanded(child: _vibrantInput("FREE", freeC, accentElectric, false, isNum: true)),
                          const SizedBox(width: 12),
                          Expanded(child: _vibrantInput("DISC %", normDiscC, accentElectric, false, isNum: true, onChanged: (v) => setState(() {}))),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Net Amount Box
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: brandDark,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: neonGreen.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
                          ]
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "NET AMOUNT",
                              style: TextStyle(color: Color(0xFFC7D2FE), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                            ),
                            Text(
                              "₹ ${totals['total']!.toStringAsFixed(2)}",
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: neonGreen),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Confirm Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isAllowed ? Colors.green : Colors.grey.shade400,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ), 
                          onPressed: (!isAllowed || qtyC.text.isEmpty || qtyC.text == "0") ? null : () {
                            BatchSyncEngine.registerBatchActivity(ph: ph, productKey: widget.med.identityKey, batchNo: batchC.text, exp: expC.text, packing: widget.med.packing, mrp: double.tryParse(mrpC.text) ?? 0, rate: double.tryParse(rateC.text) ?? 0);

                            widget.onAdd(BillItem(
                              id: widget.existingItem?.id ?? DateTime.now().toString(),
                              srNo: widget.srNo,
                              medicineID: widget.med.id,
                              name: widget.med.name,
                              packing: widget.med.packing,
                              batch: batchC.text.trim(), // 👈 Case Preserved
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
                          child: Text(expStatus == ExpiryStatus.expired ? "EXPIRED BATCH" : "ADD TO BILL", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.0)),
                        ),
                      )
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _vibrantInput(
    String label,
    TextEditingController ctrl,
    Color activeColor,
    bool isReadOnly, {
    Color? labelColor,
    bool highlight = false,
    bool isNum = false,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: labelColor ?? const Color(0xFF64748B),
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: highlight ? activeColor.withOpacity(0.05) : (isReadOnly ? const Color(0xFFF1F5F9) : Colors.white),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: highlight ? activeColor : (isReadOnly ? const Color(0xFFE2E8F0) : activeColor.withOpacity(0.3)),
              width: highlight ? 1.8 : 1.0,
            ),
          ),
          child: TextField(
            controller: ctrl,
            readOnly: isReadOnly,
            onChanged: onChanged,
            keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: isReadOnly ? const Color(0xFF64748B) : const Color(0xFF0F172A),
            ),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 10),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}
