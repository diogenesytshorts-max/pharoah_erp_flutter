// FILE: lib/challans/challan_signature_view.dart

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart'; // NAYA: Orientation lock karne ke liye
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart'; // NAYA: Sharing ke liye
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
  bool isSignMode = false;
  bool isSaving = false;
  List<Offset?> points = [];
  String uniqueCode = "";
  final TransformationController _zoomController = TransformationController();
  final GlobalKey _boundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // NAYA: Screen ko khulte hi Landscape mode mein lock karna
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
  }

  @override
  void dispose() {
    // NAYA: Screen band hote hi phone wapas Portrait ho jayega
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  void _generateCode() {
    if (uniqueCode.isEmpty) {
      const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      setState(() {
        uniqueCode = "VR-${List.generate(5, (i) => chars[Random().nextInt(chars.length)]).join()}";
      });
    }
  }

  Future<void> _handleFinalize(PharoahManager ph) async {
    setState(() => isSaving = true);
    try {
      RenderRepaintBoundary boundary = _boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      String savedPath = await ph.saveSignatureFile(widget.challan.billNo, pngBytes);

      await ph.addSignatureToChallan(
        challanId: widget.challan.id,
        imagePath: savedPath,
        code: uniqueCode,
        amount: widget.challan.totalAmount,
      );

      // --- NAYA: SHARING LOGIC ---
      if (mounted) {
        await Share.shareXFiles(
          [XFile(savedPath)], 
          text: "Signed Challan: ${widget.challan.billNo}\nVerification Code: $uniqueCode"
        );
        Navigator.pop(context); 
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
      backgroundColor: const Color(0xFF323639),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Verification: ${widget.challan.billNo}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            Text(isSignMode ? "MODE: SIGNING (ZOOM LOCKED)" : "MODE: REVIEW (PINCH TO ZOOM)", 
                 style: TextStyle(fontSize: 10, color: isSignMode ? Colors.orangeAccent : Colors.greenAccent)),
          ],
        ),
        backgroundColor: Colors.black,
        actions: [
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
                  padding: const EdgeInsets.all(10.0),
                  child: RepaintBoundary(
                    key: _boundaryKey,
                    child: AspectRatio(
                      aspectRatio: 1.414 / 1, // A4 Landscape
                      child: Container(
                        color: Colors.white,
                        child: Stack(
                          children: [
                            _buildBillLayout(ph),
                            if (uniqueCode.isNotEmpty) _buildWatermark(),
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

  Widget _buildBillLayout(PharoahManager ph) {
    final shop = ph.activeCompany!;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              _box(3, [
                Text(shop.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                Text(shop.address, style: const TextStyle(fontSize: 8)),
                Text("GST: ${shop.gstin}", style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
              ]),
              _box(2, [
                const Center(child: Text("DELIVERY CHALLAN", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, decoration: TextDecoration.underline))),
                const Divider(height: 10),
                Text("No: ${widget.challan.billNo}", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                Text("Date: ${DateFormat('dd/MM/yyyy').format(widget.challan.date)}", style: const TextStyle(fontSize: 9)),
              ]),
              _box(3, [
                const Text("CONSIGNEE:", style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.grey)),
                Text(widget.party.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Text("City: ${widget.party.city} | GST: ${widget.party.gst}", style: const TextStyle(fontSize: 8)),
              ]),
            ],
          ),
          const SizedBox(height: 15),
          _buildItemsTable(),
          const Spacer(),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(uniqueCode.isNotEmpty ? "DIGITAL SEAL: $uniqueCode" : "PENDING SIGNATURE", 
                   style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: uniqueCode.isNotEmpty ? Colors.red : Colors.grey)),
              Text("GRAND TOTAL: ₹${widget.challan.totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
            ],
          ),
          const Align(alignment: Alignment.bottomRight, child: Text("Receiver's Stamp & Sign", style: TextStyle(fontSize: 8, color: Colors.grey))),
        ],
      ),
    );
  }

  Widget _buildItemsTable() {
    return Column(
      children: [
        Container(
          color: Colors.grey[100],
          child: Row(children: [
            _cell("S.N", 40, true), _cell("Item Description", 300, true, true),
            _cell("Batch", 100, true), _cell("Exp", 70, true),
            _cell("Qty", 60, true), _cell("Total", 100, true),
          ]),
        ),
        ...widget.challan.items.map((it) => Row(children: [
          _cell(it.srNo.toString(), 40, false),
          _cell(it.name, 300, false, true),
          _cell(it.batch, 100, false),
          _cell(it.exp, 70, false),
          _cell(it.qty.toInt().toString(), 60, false),
          _cell(it.total.toStringAsFixed(2), 100, false),
        ])).toList(),
      ],
    );
  }

  Widget _box(int f, List<Widget> ch) => Expanded(flex: f, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(border: Border.all(width: 0.5, color: Colors.black38)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: ch)));
  
  Widget _cell(String t, double w, bool b, [bool isLeft = false]) => Container(width: w, padding: const EdgeInsets.all(6), decoration: BoxDecoration(border: Border.all(color: Colors.black12, width: 0.5)), child: Text(t, textAlign: isLeft ? TextAlign.left : TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: b ? FontWeight.bold : FontWeight.normal)));

  Widget _buildWatermark() => Positioned.fill(child: Center(child: IgnorePointer(child: Transform.rotate(angle: -0.4, child: Opacity(opacity: 0.15, child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(border: Border.all(color: Colors.red, width: 4)), child: Text(uniqueCode, style: const TextStyle(fontSize: 50, fontWeight: FontWeight.bold, color: Colors.red))))))));

  Widget _buildBottomAction(PharoahManager ph) {
    return Container(
      padding: const EdgeInsets.all(15), color: Colors.black,
      child: Row(children: [
        if (uniqueCode.isNotEmpty) Text("CODE: $uniqueCode", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 18)),
        const Spacer(),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
          onPressed: (points.isEmpty || isSaving) ? null : () => _handleFinalize(ph),
          icon: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.share),
          label: const Text("LOCK & SHARE PDF"),
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
    Paint paint = Paint()..color = Colors.blue[900]!..strokeCap = StrokeCap.round..strokeWidth = 3.5;
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) canvas.drawLine(points[i]!, points[i + 1]!, paint);
    }
  }
  @override bool shouldRepaint(SignaturePainter oldDelegate) => true;
}
