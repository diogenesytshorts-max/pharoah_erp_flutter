import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models.dart';
import 'pharoah_manager.dart';
import 'expiry_master.dart'; // NAYA INTEGRATION

class ItemEntryCard extends StatefulWidget {
  final Medicine med;
  final int srNo;
  final BillItem? existingItem;
  final Function(BillItem) onAdd;
  final VoidCallback onCancel;

  const ItemEntryCard({
    super.key,
    required this.med,
    required this.srNo,
    this.existingItem,
    required this.onAdd,
    required this.onCancel,
  });

  @override
  State<ItemEntryCard> createState() => _ItemEntryCardState();
}

class _ItemEntryCardState extends State<ItemEntryCard> {
  // --- CONTROLLERS ---
  final batchC = TextEditingController();
  final expC = TextEditingController();
  final mrpC = TextEditingController();
  final rateC = TextEditingController();
  final qtyC = TextEditingController();
  final freeC = TextEditingController(text: "0"); 
  final gstC = TextEditingController();
  final rateCDiscC = TextEditingController(text: "0.0");
  final normDiscC = TextEditingController(text: "0.0");

  String selectedRateType = "A";
  String originalExp = ""; // Purana Logic preserved

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
      normDiscC.text = i.discountRupees > 0 
          ? ((i.discountRupees / (i.rate * i.qty)) * 100).toStringAsFixed(2) 
          : "0.0";
    } else {
      mrpC.text = widget.med.mrp.toString();
      gstC.text = widget.med.gst.toString();
      _updateRateLogic();
    }
  }

  // --- RATE CALCULATIONS (Preserved) ---
  void _calculateRateC() {
    double mrp = double.tryParse(mrpC.text) ?? 0.0;
    double gst = double.tryParse(gstC.text) ?? 0.0;
    double disc = double.tryParse(rateCDiscC.text) ?? 0.0;
    double baseTaxable = (mrp / (1 + (gst / 100)));
    double finalRate = baseTaxable - (baseTaxable * (disc / 100));
    rateC.text = finalRate.toStringAsFixed(2);
    setState(() {});
  }

  void _updateRateLogic() {
    if (selectedRateType == "C") {
      _calculateRateC();
    } else {
      rateC.text = selectedRateType == "A" 
          ? widget.med.rateA.toString() 
          : widget.med.rateB.toString();
    }
    setState(() {});
  }

  // --- EXPIRY FORMATTING (Preserved & Enhanced) ---
  void _formatExpiry(String val) {
    String text = val.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.length >= 2 && !val.contains('/')) {
      text = '${text.substring(0, 2)}/${text.substring(2)}';
    }
    if (text.length > 5) text = text.substring(0, 5);
    
    if (expC.text != text) {
      expC.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
    }
    setState(() {}); // Refresh UI for ExpiryMaster colors
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
    return {'taxable': taxable, 'cgst': taxAmt / 2, 'sgst': taxAmt / 2, 'total': taxable + taxAmt, 'discountAmt': discAmt};
  }

  // --- VALIDATION LOGIC (Preserved) ---
  void _validateAndAdd(PharoahManager ph) {
    if (qtyC.text.isEmpty || qtyC.text == "0") return;

    // Check against history for expiry mismatch
    final history = ph.batchHistory[widget.med.identityKey] ?? [];
    try {
      final existingBatch = history.firstWhere((b) => b.batch == batchC.text.toUpperCase());
      if (existingBatch.exp != expC.text) {
        originalExp = existingBatch.exp;
        _showExpiryWarning(); // Call the dialog
        return;
      }
    } catch (e) {}
    _addItemToBill();
  }

  // --- DIALOGS (Preserved) ---
  void _showExpiryWarning() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Expiry Mismatch!", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text("System records show expiry $originalExp for this batch. Do you want to overwrite it with ${expC.text}?"),
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
      batch: batchC.text.toUpperCase(),
      exp: expC.text,
      hsn: widget.med.hsnCode,
      mrp: double.tryParse(mrpC.text) ?? 0,
      qty: double.tryParse(qtyC.text) ?? 0,
      freeQty: double.tryParse(freeC.text) ?? 0,
      rate: double.tryParse(rateC.text) ?? 0,
      gstRate: double.tryParse(gstC.text) ?? 0,
      cgst: t['cgst']!,
      sgst: t['sgst']!,
      total: t['total']!,
      discountRupees: t['discountAmt']!,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    final totals = _calcTotals();
    
    // NEW INTEGRATION: Expiry Intelligence
    String expStr = expC.text;
    ExpiryStatus expStatus = ExpiryMaster.getStatus(expStr);
    Color statusColor = ExpiryMaster.getStatusColor(expStr);
    String? valMsg = ExpiryMaster.getValidationWarning(expStr);
    bool isAllowed = ExpiryMaster.isSaleAllowed(expStr);

    final matchingBatches = (ph.batchHistory[widget.med.identityKey] ?? [])
        .where((b) => b.batch.toLowerCase().contains(batchC.text.toLowerCase()))
        .toList();

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
            // EXPIRY FIELD: Now uses Master status color
            Expanded(child: _buildInput("EXPIRY (MM/YY)", expC, onChanged: _formatExpiry, isNum: true, color: statusColor)),
            const SizedBox(width: 8),
            Expanded(child: _buildInput("GST %", gstC, isNum: true, onChanged: (v){ if(selectedRateType=="C") _calculateRateC(); setState((){}); })),
          ]),

          // NEW: Warnings from ExpiryMaster
          if (valMsg != null) 
            Padding(padding: const EdgeInsets.only(top: 5), child: Text(valMsg, style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold))),

          if (expStr.length == 5) 
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
              child: Text(
                expStatus == ExpiryStatus.expired ? "🔴 BATCH EXPIRED - SALE BLOCKED" : 
                expStatus == ExpiryStatus.nearExpiry ? "⚠️ NEAR EXPIRY (LESS THAN 6 MONTHS)" : "✅ BATCH SAFE",
                style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),

          // BATCH CHIPS (Enhanced with Expiry Colors)
          if (matchingBatches.isNotEmpty && widget.existingItem == null)
            Container(height: 45, margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListView(scrollDirection: Axis.horizontal, children: matchingBatches.map((b) {
                  Color bColor = ExpiryMaster.getStatusColor(b.exp);
                  return Padding(padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      backgroundColor: bColor.withOpacity(0.05),
                      side: BorderSide(color: bColor.withOpacity(0.3)),
                      label: Text("${b.batch} (${b.exp})", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: bColor)),
                      onPressed: () {
                        setState(() {
                          batchC.text = b.batch; expC.text = b.exp; originalExp = b.exp;
                          mrpC.text = b.mrp.toString(); rateC.text = b.rate.toString();
                          if (selectedRateType == "C") _calculateRateC();
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: const [ButtonSegment(value: "A", label: Text("Rate A")), ButtonSegment(value: "B", label: Text("Rate B")), ButtonSegment(value: "C", label: Text("Rate C"))],
            selected: {selectedRateType},
            onSelectionChanged: (v) { setState(() { selectedRateType = v.first; _updateRateLogic(); }); },
          ),
          
          const SizedBox(height: 12),
          Row(children: [
            if (selectedRateType == "C") ...[Expanded(child: _buildInput("C DISC%", rateCDiscC, isNum: true, color: Colors.purple, onChanged: (v) => _calculateRateC())), const SizedBox(width: 8)],
            Expanded(child: _buildInput("MRP", mrpC, isNum: true)),
            const SizedBox(width: 8),
            Expanded(child: _buildInput("RATE", rateC, isNum: true, isReadOnly: selectedRateType == "C", color: selectedRateType == "C" ? Colors.purple : Colors.blue)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _buildInput("QTY", qtyC, isNum: true, onChanged: (v) => setState((){}))),
            const SizedBox(width: 8),
            Expanded(child: _buildInput("FREE", freeC, isNum: true)),
            const SizedBox(width: 8),
            Expanded(child: _buildInput("DISC %", normDiscC, isNum: true, onChanged: (v) => setState((){}))),
          ]),

          const SizedBox(height: 15),
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text("Taxable: ₹${totals['taxable']!.toStringAsFixed(2)}", style: const TextStyle(fontSize: 12)),
              Text("TOTAL: ₹${totals['total']!.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.green)),
            ]),
          ),

          const SizedBox(height: 15),
          // MAIN BUTTON: Now respects isSaleAllowed from ExpiryMaster
          SizedBox(width: double.infinity, height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: isAllowed ? Colors.green : Colors.grey.shade400, foregroundColor: Colors.white),
              onPressed: (!isAllowed || qtyC.text.isEmpty || qtyC.text == "0") ? null : () => _validateAndAdd(ph),
              child: Text(
                expStatus == ExpiryStatus.expired ? "EXPIRED BATCH: CANNOT SELL" : 
                (widget.existingItem != null ? "UPDATE ITEM" : "ADD TO BILL"), 
                style: const TextStyle(fontWeight: FontWeight.bold)
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl, {bool isNum = false, Function(String)? onChanged, bool isReadOnly = false, Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color ?? Colors.black54)),
        const SizedBox(height: 2),
        TextField(
          controller: ctrl, readOnly: isReadOnly,
          keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          onChanged: onChanged,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
          decoration: InputDecoration(
            isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(5)),
            filled: isReadOnly, fillColor: isReadOnly ? Colors.grey.shade100 : Colors.white,
          ),
        ),
      ],
    );
  }
}
