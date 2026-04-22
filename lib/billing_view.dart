import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import 'pdf/sale_invoice_pdf.dart';

// --- BATCH & EXPIRY FORMATTERS ---
class ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;
    if (newValue.selection.baseOffset < oldValue.selection.baseOffset) return newValue;
    if (text.length == 2 && !text.contains('/')) return TextEditingValue(text: '$text/', selection: TextSelection.collapsed(offset: 3));
    return newValue;
  }
}

class BillingView extends StatefulWidget {
  final Party party;
  final String billNo;
  final DateTime billDate;
  final String mode;
  final List<BillItem>? existingItems;
  final String? modifySaleId;

  const BillingView({
    super.key,
    required this.party,
    required this.billNo,
    required this.billDate,
    required this.mode,
    this.existingItems,
    this.modifySaleId,
  });

  @override
  State<BillingView> createState() => _BillingViewState();
}

class _BillingViewState extends State<BillingView> {
  List<BillItem> items = [];
  String searchQuery = "";
  Medicine? selectedMed;
  
  double get totalAmt => items.fold(0, (sum, it) => sum + it.total);

  @override
  void initState() {
    super.initState();
    if (widget.existingItems != null) items = List.from(widget.existingItems!);
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.party.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          Text("Bill No: ${widget.billNo}", style: const TextStyle(fontSize: 10))
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: items.isEmpty ? null : () => _printBill(),
          ),
          TextButton(
            onPressed: items.isEmpty ? null : () => _handleSave(ph),
            child: const Text("FINISH", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: Stack(children: [
        Column(children: [
          // 1. SEARCH BAR (Jab item select nahi hai)
          if (selectedMed == null)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.teal.shade50,
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: "Search Product for Sale...", 
                  prefixIcon: Icon(Icons.search, color: Colors.teal), 
                  border: OutlineInputBorder()
                ),
                onChanged: (v) => setState(() => searchQuery = v),
              ),
            ),

          // 2. ITEM ENTRY FORM (Jab item select ho jaye)
          if (selectedMed != null)
            SaleItemForm(
              med: selectedMed!,
              srNo: items.length + 1,
              batchHistory: ph.batchHistory[selectedMed!.id] ?? [],
              onAdd: (newItem) {
                setState(() {
                  items.add(newItem);
                  selectedMed = null;
                  searchQuery = "";
                });
              },
              onCancel: () => setState(() => selectedMed = null),
            ),

          // 3. BILL ITEMS LIST
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (c, i) => const Divider(),
              itemBuilder: (c, i) => ListTile(
                title: Text(items[i].name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                subtitle: Text("Qty: ${items[i].qty.toInt()} | Batch: ${items[i].batch} | Rate: ₹${items[i].rate}"),
                trailing: Text("₹${items[i].total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                onLongPress: () => setState(() => items.removeAt(i)),
              ),
            ),
          ),

          // 4. SEARCH RESULTS OVERLAY
          if (searchQuery.isNotEmpty && selectedMed == null)
            Container(
              constraints: const BoxConstraints(maxHeight: 250),
              color: Colors.white,
              child: ListView(
                children: ph.medicines
                    .where((m) => m.name.toLowerCase().contains(searchQuery.toLowerCase()))
                    .map((m) => ListTile(
                          leading: const Icon(Icons.medication, color: Colors.teal),
                          title: Text(m.name),
                          subtitle: Text("Stock: ${m.stock} | Pack: ${m.packing}"),
                          onTap: () => setState(() { selectedMed = m; searchQuery = ""; }),
                        ))
                    .toList(),
              ),
            ),

          // 5. BOTTOM TOTAL FOOTER
          Container(
            padding: const EdgeInsets.all(15),
            color: Colors.teal.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("ITEMS: ${items.length}", style: const TextStyle(fontWeight: FontWeight.bold)),
                Text("NET TOTAL: ₹${totalAmt.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
              ],
            ),
          ),
        ]),
      ]),
    );
  }

  void _handleSave(PharoahManager ph) {
    if (widget.modifySaleId != null) ph.deleteBill(widget.modifySaleId!);
    ph.finalizeSale(
      billNo: widget.billNo,
      date: widget.billDate,
      party: widget.party,
      items: items,
      total: totalAmt,
      mode: widget.mode,
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _printBill() async {
    final sale = Sale(
      id: widget.modifySaleId ?? DateTime.now().toString(), 
      billNo: widget.billNo, 
      date: widget.billDate, 
      partyName: widget.party.name, 
      partyGstin: widget.party.gst, 
      partyState: widget.party.state, 
      items: items, 
      totalAmount: totalAmt, 
      paymentMode: widget.mode
    );
    await SaleInvoicePdf.generate(sale, widget.party);
  }
}

// --- ITEM ENTRY FORM (Purchase style layout adapted for Sales) ---
class SaleItemForm extends StatefulWidget {
  final Medicine med;
  final int srNo;
  final List<BatchInfo> batchHistory;
  final Function(BillItem) onAdd;
  final VoidCallback onCancel;

  const SaleItemForm({super.key, required this.med, required this.srNo, required this.batchHistory, required this.onAdd, required this.onCancel});

  @override
  State<SaleItemForm> createState() => _SaleItemFormState();
}

class _SaleItemFormState extends State<SaleItemForm> {
  final bC = TextEditingController();
  final eC = TextEditingController();
  final gC = TextEditingController();
  final mC = TextEditingController();
  final rC = TextEditingController(); // Sale Rate
  final qC = TextEditingController(text: "1");

  @override
  void initState() {
    super.initState();
    mC.text = widget.med.mrp.toString();
    gC.text = widget.med.gst.toString();
    rC.text = widget.med.rateA.toString(); // Default to Rate A for sales
    
    // Auto fill if batch history exists
    if (widget.batchHistory.isNotEmpty) {
      final lastBatch = widget.batchHistory.last;
      bC.text = lastBatch.batch;
      eC.text = lastBatch.exp;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      color: Colors.teal.shade50,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text("${widget.srNo}. ${widget.med.name}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 16))),
              IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: widget.onCancel)
            ],
          ),
          
          // Batch Chips
          if (widget.batchHistory.isNotEmpty)
            SizedBox(
              height: 35,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: widget.batchHistory.map((b) => Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: ActionChip(
                    label: Text("${b.batch} (${b.exp})"),
                    onPressed: () => setState(() {
                      bC.text = b.batch;
                      eC.text = b.exp;
                      mC.text = b.mrp.toString();
                      rC.text = b.rate.toString();
                    }),
                  ),
                )).toList(),
              ),
            ),
          
          const SizedBox(height: 10),
          
          // Row 1
          Row(children: [
            Expanded(child: _field(bC, "Batch")),
            const SizedBox(width: 5),
            Expanded(child: _field(eC, "Exp", fmt: [ExpiryDateFormatter()])),
            const SizedBox(width: 5),
            Expanded(child: _field(gC, "GST%", en: false)),
          ]),
          
          const SizedBox(height: 10),
          
          // Row 2
          Row(children: [
            Expanded(child: _field(mC, "MRP", en: false)),
            const SizedBox(width: 5),
            Expanded(child: _field(rC, "Sale Rate")),
            const SizedBox(width: 5),
            Expanded(child: _field(qC, "Qty", isNum: true)),
          ]),
          
          const SizedBox(height: 15),
          
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 45), 
              backgroundColor: Colors.teal.shade700
            ),
            onPressed: () {
              double rate = double.tryParse(rC.text) ?? 0;
              double qty = double.tryParse(qC.text) ?? 0;
              double gstPercent = double.tryParse(gC.text) ?? 0;
              
              // Tax Calculations
              double taxableValue = rate * qty;
              double taxAmount = taxableValue * (gstPercent / 100);
              double total = taxableValue + taxAmount;

              widget.onAdd(BillItem(
                id: DateTime.now().toString(),
                srNo: widget.srNo,
                medicineID: widget.med.id,
                name: widget.med.name,
                packing: widget.med.packing,
                batch: bC.text.toUpperCase(),
                exp: eC.text,
                hsn: widget.med.hsnCode,
                mrp: double.tryParse(mC.text) ?? 0,
                qty: qty,
                rate: rate,
                gstRate: gstPercent,
                total: total,
                cgst: taxAmount / 2,
                sgst: taxAmount / 2,
                igst: 0,
              ));
            },
            child: const Text("ADD TO BILL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String l, {List<TextInputFormatter>? fmt, bool en = true, bool isNum = false}) {
    return TextField(
      controller: ctrl,
      enabled: en,
      inputFormatters: fmt,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: l, 
        border: const OutlineInputBorder(), 
        contentPadding: const EdgeInsets.all(8),
        filled: !en,
        fillColor: en ? Colors.white : Colors.grey.shade200,
      ),
    );
  }
}
