// FILE: lib/challans/challan_signature_view.dart

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart'; 
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart'; 
import 'package:path_provider/path_provider.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import '../pdf/sale_challan_pdf.dart'; // Direct access for PDF generation

class ChallanSignatureView extends StatefulWidget {
  final SaleChallan challan;
  final Party party;

  const ChallanSignatureView({super.key, required this.challan, required this.party});

  @override
  State<ChallanSignatureView> createState() => _ChallanSignatureViewState();
}

class _ChallanSignatureViewState extends State<ChallanSignatureView> {
  bool isSignMode = false;
  bool isProcessing = false;
  String uniqueCode = "";
  List<Offset?> points = [];
  int currentPage = 0;
  
  double signXPercent = 0.5;
  double signYPercent = 0.8;

  final TransformationController _zoomController = TransformationController();
  final PageController _pageController = PageController();
  final GlobalKey _signBoundaryKey = GlobalKey(); 

  @override
  void initState() {
    super.initState();
    // Landscape Mode Lock
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _zoomController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _generateCode(Offset touchPoint) {
    if (uniqueCode.isEmpty) {
      const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      setState(() {
        uniqueCode = "VR-${List.generate(5, (i) => chars[Random().nextInt(chars.length)]).join()}";
        // Calculate percentage for PDF mapping
        signXPercent = touchPoint.dx / 600; // Based on internal canvas width
        signYPercent = touchPoint.dy / 420; // Based on internal canvas height
      });
    }
  }

  // ===========================================================================
  // THE NEW FINALIZE ENGINE (WITH POPUP)
  // ===========================================================================
  Future<void> _handleFinalize(PharoahManager ph) async {
    setState(() => isProcessing = true);
    try {
      // 1. Capture Signature as Transparent PNG
      RenderRepaintBoundary boundary = _signBoundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List sigBytes = byteData!.buffer.asUint8List();

      // 2. Save PNG and Update Database
      String savedImgPath = await ph.saveSignatureFile(widget.challan.billNo, sigBytes);
      await ph.addSignatureToChallan(
        challanId: widget.challan.id,
        imagePath: savedImgPath,
        code: uniqueCode,
        amount: widget.challan.totalAmount,
        x: signXPercent,
        y: signYPercent,
      );

      // 3. SHOW SUCCESS DIALOG (Share & Save Options)
      if (mounted) {
        _showSuccessActions(ph, savedImgPath);
      }
    } catch (e) {
      debugPrint("Finalize Error: $e");
    }
    setState(() => isProcessing = false);
  }

  void _showSuccessActions(PharoahManager ph, String signaturePath) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 10), Text("Verification Locked")]),
        content: const Text("Challan has been digitally signed and secured. Select an action below:"),
        actions: [
          // ACTION 1: SHARE
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () {
              // Trigger PDF Router to generate and share
              SaleChallanPdf.generate(widget.challan, widget.party, ph.activeCompany!);
              Navigator.pop(c); // Close Dialog
              Navigator.pop(context); // Exit Signature Screen
            },
            icon: const Icon(Icons.share),
            label: const Text("SHARE ON WHATSAPP"),
          ),
          // ACTION 2: DONE
          TextButton(
            onPressed: () { Navigator.pop(c); Navigator.pop(context); },
            child: const Text("EXIT TO REGISTER"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    int itemsPerPage = 12; // Reduced for better visibility
    int totalPages = (widget.challan.items.length / itemsPerPage).ceil();
    if (totalPages == 0) totalPages = 1;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              transformationController: _zoomController,
              panEnabled: !isSignMode,
              scaleEnabled: !isSignMode,
              child: PageView.builder(
                controller: _pageController,
                physics: isSignMode ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
                itemCount: totalPages,
                onPageChanged: (i) => setState(() => currentPage = i),
                itemBuilder: (context, index) {
                  bool isLastPage = (index == totalPages - 1);
                  // --- FIX 1: FITTEDBOX FOR FULL PAGE VISIBILITY ---
                  return Center(
                    child: FittedBox(
                      fit: BoxFit.contain, // Poora page screen ke andar fit hoga
                      child: Container(
                        width: 800, height: 550, // Standard Landscape Ratio
                        margin: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)]),
                        child: Stack(
                          children: [
                            _buildBillLayout(index, totalPages, isLastPage, ph),
                            if (uniqueCode.isNotEmpty) _buildWatermarkSeal(),
                            if (isLastPage && isSignMode)
                              RepaintBoundary(
                                key: _signBoundaryKey,
                                child: GestureDetector(
                                  onPanStart: (d) => _generateCode(d.localPosition),
                                  onPanUpdate: (d) => setState(() => points.add(d.localPosition)),
                                  onPanEnd: (d) => setState(() => points.add(null)),
                                  child: CustomPaint(painter: SignaturePainter(points: points), size: Size.infinite),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          _buildBottomActionPanel(ph),
        ],
      ),
    );
  }

  // --- UI: BILL CONTENT ---
  Widget _buildBillLayout(int pageIdx, int totalPages, bool isLastPage, PharoahManager ph) {
    final shop = ph.activeCompany!;
    return Padding(
      padding: const EdgeInsets.all(25),
      child: Column(
        children: [
          Row(children: [
            _headerBox(3, [
              Text(shop.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
              Text(shop.address, style: const TextStyle(fontSize: 9)),
              Text("GST: ${shop.gstin}", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
            ]),
            _headerBox(2, [
              const Center(child: Text("DELIVERY CHALLAN", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, decoration: TextDecoration.underline))),
              const Divider(),
              Text("No: ${widget.challan.billNo}", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
              Text("Date: ${DateFormat('dd/MM/yyyy').format(widget.challan.date)}", style: const TextStyle(fontSize: 9)),
            ]),
            _headerBox(3, [
              const Text("CONSIGNEE:", style: TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
              Text(widget.party.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Text("GST: ${widget.party.gst} | ${widget.party.city}", style: const TextStyle(fontSize: 9)),
            ]),
          ]),
          const SizedBox(height: 20),
          _buildPageTable(pageIdx),
          const Spacer(),
          if (isLastPage) ...[
            const Divider(),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _buildSecurityDisclaimer(),
              Text("GRAND TOTAL: ₹${widget.challan.totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            ]),
            const Align(alignment: Alignment.bottomRight, child: Text("Receiver's Sign", style: TextStyle(fontSize: 9, fontStyle: FontStyle.italic, color: Colors.grey))),
          ] else ...[
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _buildSecurityDisclaimer(),
              Text("Continued to Page ${pageIdx + 2}...", style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
            ]),
          ]
        ],
      ),
    );
  }

  Widget _buildPageTable(int pageIdx) {
    int start = pageIdx * 12;
    int end = (start + 12 < widget.challan.items.length) ? start + 12 : widget.challan.items.length;
    var pageItems = widget.challan.items.sublist(start, end);
    return Column(children: [
      Container(color: Colors.grey[200], child: Row(children: [
        _cell("S.N", 40, true), _cell("Item Description", 300, true, true),
        _cell("Batch", 100, true), _cell("Qty", 60, true), _cell("Total", 100, true),
      ])),
      ...pageItems.map((it) => Row(children: [
        _cell(it.srNo.toString(), 40, false), _cell(it.name, 300, false, true),
        _cell(it.batch, 100, false), _cell(it.qty.toInt().toString(), 60, false),
        _cell(it.total.toStringAsFixed(2), 100, false),
      ])).toList(),
    ]);
  }

  Widget _cell(String t, double w, bool b, [bool isLeft = false]) => Container(width: w, padding: const EdgeInsets.all(8), decoration: BoxDecoration(border: Border.all(color: Colors.black12, width: 0.5)), child: Text(t, textAlign: isLeft ? TextAlign.left : TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: b ? FontWeight.bold : FontWeight.normal)));

  Widget _headerBox(int f, List<Widget> ch) => Expanded(flex: f, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(border: Border.all(width: 0.5, color: Colors.black38)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: ch)));

  Widget _buildSecurityDisclaimer() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (uniqueCode.isNotEmpty) Text("DIGITAL SEAL: $uniqueCode", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red)),
    const SizedBox(width: 300, child: Text("SECURITY NOTICE: Locked with unique digital seal. Any unauthorized modification will permanently invalidate this code.", style: TextStyle(fontSize: 7, color: Colors.blueGrey, fontWeight: FontWeight.bold))),
  ]);

  Widget _buildWatermarkSeal() => Positioned.fill(child: Center(child: IgnorePointer(child: Transform.rotate(angle: -0.4, child: Opacity(opacity: 0.1, child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(border: Border.all(color: Colors.red, width: 5)), child: Text(uniqueCode, style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: Colors.red))))))));

  PreferredSizeWidget _buildAppBar() => AppBar(
    title: Text("Receiver Verification - Page ${currentPage + 1}", style: const TextStyle(fontSize: 16)),
    backgroundColor: Colors.black,
    actions: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: isSignMode ? Colors.red : Colors.blueAccent),
        onPressed: () => setState(() => isSignMode = !isSignMode),
        icon: Icon(isSignMode ? Icons.zoom_in : Icons.draw, color: Colors.white),
        label: Text(isSignMode ? "DONE" : "SIGN NOW", style: const TextStyle(color: Colors.white)),
      ))
    ],
  );

  Widget _buildBottomActionPanel(PharoahManager ph) => Container(
    padding: const EdgeInsets.all(15), color: Colors.black,
    child: Row(children: [
      if (uniqueCode.isNotEmpty) Text("CODE: $uniqueCode", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 18)),
      const Spacer(),
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15)),
        onPressed: (points.isEmpty || isProcessing) ? null : () => _handleFinalize(ph),
        icon: isProcessing ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.lock),
        label: const Text("LOCK & FINISH"),
      )
    ]),
  );
}

class SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  SignaturePainter({required this.points});
  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()..color = Colors.blue[900]!..strokeCap = StrokeCap.round..strokeWidth = 4.0;
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) canvas.drawLine(points[i]!, points[i + 1]!, paint);
    }
  }
  @override bool shouldRepaint(SignaturePainter oldDelegate) => true;
}
