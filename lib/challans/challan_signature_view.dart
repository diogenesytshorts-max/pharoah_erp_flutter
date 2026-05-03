// FILE: lib/challans/challan_signature_view.dart

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';

class ChallanSignatureView extends StatefulWidget {
  final SaleChallan challan;
  final Party party;

  const ChallanSignatureView({
    super.key, 
    required this.challan, 
    required this.party
  });

  @override
  State<ChallanSignatureView> createState() => _ChallanSignatureViewState();
}

class _ChallanSignatureViewState extends State<ChallanSignatureView> {
  // --- LOGIC STATES ---
  bool isSignMode = false;
  bool isSaving = false;
  List<Offset?> points = [];
  String uniqueCode = "";
  final TransformationController _zoomController = TransformationController();
  final GlobalKey _boundaryKey = GlobalKey(); // Snapshot lene ke liye

  // Unique Code Engine: Pehla touch hote hi trigger hoga
  void _generateCode() {
    if (uniqueCode.isEmpty) {
      const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      setState(() {
        uniqueCode = "VR-${List.generate(5, (i) => chars[Random().nextInt(chars.length)]).join()}";
      });
    }
  }

  // Final Save Logic: Widget ko Image mein badalna
  Future<void> _handleFinalize(PharoahManager ph) async {
    setState(() => isSaving = true);
    try {
      // 1. Capture the Widget as Image Bytes
      RenderRepaintBoundary boundary = _boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0); // High Resolution
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      // 2. Manager ke zariye file save karna
      String savedPath = await ph.saveSignatureFile(widget.challan.billNo, pngBytes);

      // 3. Database mein link karna
      await ph.addSignatureToChallan(
        challanId: widget.challan.id,
        imagePath: savedPath,
        code: uniqueCode,
        amount: widget.challan.totalAmount,
      );

      if (mounted) {
        Navigator.pop(context); // Close Signature View
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Challan Verified & Signed!"), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      debugPrint("Sign Save Error: $e");
    }
    setState(() => isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF323639), // Professional PDF Viewer Grey
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Verify: ${widget.challan.billNo}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            Text(isSignMode ? "MODE: SIGNING (ZOOM LOCKED)" : "MODE: REVIEW (PINCH TO ZOOM)", 
                 style: TextStyle(fontSize: 10, color: isSignMode ? Colors.orangeAccent : Colors.greenAccent)),
          ],
        ),
        backgroundColor: Colors.black,
        actions: [
          // Mode Toggle
          TextButton.icon(
            onPressed: () {
              setState(() {
                isSignMode = !isSignMode;
                if (!isSignMode) _zoomController.value = Matrix4.identity();
              });
            },
            icon: Icon(isSignMode ? Icons.zoom_in : Icons.edit_document, color: Colors.white),
            label: Text(isSignMode ? "VIEW" : "SIGN", style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              transformationController: _zoomController,
              panEnabled: !isSignMode,
              scaleEnabled: !isSignMode,
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: RepaintBoundary(
                    key: _boundaryKey, // Is area ka photo khichega
                    child: AspectRatio(
                      aspectRatio: 1.414 / 1, // A4 Landscape
                      child: Container(
                        color: Colors.white,
                        child: Stack(
                          children: [
                            // LAYER 1: BILL CONTENT
                            _buildBillLayout(ph),

                            // LAYER 2: WATERMARK
                            if (uniqueCode.isNotEmpty) _buildWatermark(),

                            // LAYER 3: SIGNATURE CANVAS
                            if (isSignMode)
                              GestureDetector(
                                onPanStart: (d) => _generateCode(),
                                onPanUpdate: (d) => setState(() => points.add(d.localPosition)),
                                onPanEnd: (d) => setState(() => points.add(null)),
                                child: CustomPaint(
                                  painter: SignaturePainter(points: points),
                                  size: Size.infinite,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          _buildBottomAction(ph),
        ],
      ),
    );
  }

  // --- UI: DYNAMIC BILL LAYOUT (Matches PDF Style) ---
  Widget _buildBillLayout(PharoahManager ph) {
    final shop = ph.activeCompany!;
    return Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        children: [
          Row(
            children: [
              _box(3, [
                Text(shop.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue)),
                Text(shop.address, style: const TextStyle(fontSize: 7)),
                Text("GST: ${shop.gstin}", style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold)),
              ]),
              _box(2, [
                const Center(child: Text("DELIVERY CHALLAN", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, decoration: TextDecoration.underline))),
                const Divider(height: 8),
                Text("No: ${widget.challan.billNo}", style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
                Text("Date: ${DateFormat('dd/MM/yyyy').format(widget.challan.date)}", style: const TextStyle(fontSize: 8)),
              ]),
              _box(3, [
                const Text("CONSIGNEE:", style: TextStyle(fontSize: 6, fontWeight: FontWeight.bold, color: Colors.grey)),
                Text(widget.party.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                Text("City: ${widget.party.city} | GST: ${widget.party.gst}", style: const TextStyle(fontSize: 7)),
              ]),
            ],
          ),
          const SizedBox(height: 10),
          _buildItemsTable(),
          const Spacer(),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(uniqueCode.isNotEmpty ? "CODE: $uniqueCode" : "UNSTAMPED", 
                   style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: uniqueCode.isNotEmpty ? Colors.red : Colors.grey)),
              Text("GRAND TOTAL: ₹${widget.challan.totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
            ],
          ),
          const Align(alignment: Alignment.bottomRight, child: Text("Receiver's Sign", style: TextStyle(fontSize: 7, color: Colors.grey))),
        ],
      ),
    );
  }

  Widget _buildItemsTable() {
    return Column(
      children: [
        Container(
          color: Colors.grey[200],
          child: Row(children: [
            _cell("S.N", 30, true), _cell("Item Description", 200, true, true),
            _cell("Batch", 80, true), _cell("Exp", 50, true),
            _cell("Qty", 40, true), _cell("Total", 80, true),
          ]),
        ),
        ...widget.challan.items.map((it) => Row(children: [
          _cell(it.srNo.toString(), 30, false),
          _cell(it.name, 200, false, true),
          _cell(it.batch, 80, false),
          _cell(it.exp, 50, false),
          _cell(it.qty.toInt().toString(), 40, false),
          _cell(it.total.toStringAsFixed(2), 80, false),
        ])).toList(),
      ],
    );
  }

  Widget _box(int f, List<Widget> ch) => Expanded(flex: f, child: Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(border: Border.all(width: 0.5, color: Colors.black38)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: ch)));
  
  Widget _cell(String t, double w, bool b, [bool isLeft = false]) => Container(width: w, padding: const EdgeInsets.all(4), decoration: BoxDecoration(border: Border.all(color: Colors.black12, width: 0.2)), child: Text(t, textAlign: isLeft ? TextAlign.left : TextAlign.center, style: TextStyle(fontSize: 7, fontWeight: b ? FontWeight.bold : FontWeight.normal)));

  Widget _buildWatermark() => Positioned.fill(child: Center(child: IgnorePointer(child: Transform.rotate(angle: -0.4, child: Opacity(opacity: 0.12, child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(border: Border.all(color: Colors.red, width: 3)), child: Text(uniqueCode, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.red))))))));

  Widget _buildBottomAction(PharoahManager ph) {
    return Container(
      padding: const EdgeInsets.all(15), color: Colors.black,
      child: Row(children: [
        if (uniqueCode.isNotEmpty) Text(uniqueCode, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 18)),
        const Spacer(),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
          onPressed: (points.isEmpty || isSaving) ? null : () => _handleFinalize(ph),
          child: isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text("LOCK & FINISH"),
        ),
      ]),
    );
  }
}

class SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  SignaturePainter({required this.points});
  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()..color = Colors.blue[900]!..strokeCap = StrokeCap.round..strokeWidth = 3.0;
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) canvas.drawLine(points[i]!, points[i + 1]!, paint);
    }
  }
  @override bool shouldRepaint(SignaturePainter oldDelegate) => true;
}
