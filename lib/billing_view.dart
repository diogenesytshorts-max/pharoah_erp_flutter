import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'sale_bill_number.dart';
import 'pdf_service.dart';

class BillingView extends StatefulWidget {
  final Party party;
  final String billNo;
  final DateTime billDate;
  final String mode;
  final List<BillItem>? existingItems;
  final String? modifySaleId;
  final bool isReadOnly;

  const BillingView({
    super.key,
    required this.party,
    required this.billNo,
    required this.billDate,
    required this.mode,
    this.existingItems,
    this.modifySaleId,
    this.isReadOnly = false,
  });

  @override
  State<BillingView> createState() => _BillingViewState();
}

class _BillingViewState extends State<BillingView> {
  List<BillItem> items = [];
  String search = "";
  Medicine? selectedMed;
  int? editingIndex;

  // Computed totals for summary
  double get grandTotal => items.fold(0, (sum, item) => sum + item.total);
  double get totalTaxable => items.fold(0, (sum, item) => sum + (item.total - (item.cgst + item.sgst + item.igst)));
  double get totalGSTAmount => items.fold(0, (sum, item) => sum + (item.cgst + item.sgst + item.igst));

  @override
  void initState() {
    super.initState();
    if (widget.existingItems != null) {
      items = List.from(widget.existingItems!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 2,
        backgroundColor: widget.isReadOnly ? Colors.purple : Colors.blue,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.party.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text("${widget.billNo} | ${widget.party.isB2B ? 'B2B' : 'B2C'} | ${widget.party.state}", style: const TextStyle(fontSize: 10)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.print), onPressed: items.isEmpty ? null : () => _saveAndPrint(ph)),
          if (!widget.isReadOnly)
            TextButton(
              onPressed: items.isEmpty ? null : () => _saveAndClose(ph),
              child: const Text("SAVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
        ],
      ),
      body: Stack(
        children: [
          Column(
