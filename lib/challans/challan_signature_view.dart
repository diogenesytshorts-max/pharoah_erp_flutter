// FILE: lib/challans/challan_signature_view.dart

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart'; // Orientation control
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import '../pdf/pdf_router_service.dart';

class ChallanSignatureView extends StatefulWidget {
  final SaleChallan challan;
  final Party party;

  const ChallanSignatureView({super.key, required this.challan, required this.party});

  @override
  State<ChallanSignatureView> createState() => _ChallanSignatureViewState();
}

class _ChallanSignatureViewState extends State<ChallanSignatureView> {
  // Logic States
  bool isSignMode = false;
  bool isSaving = false;
  String uniqueCode = "";
  List<Offset?> points = [];
  int currentPage = 0;
  
  // Signature Coordinates (Mapping Logic)
  double signXPercent = 0.0;
  double signYPercent = 0.0;

  final TransformationController _zoomController = TransformationController();
  final PageController _pageController = PageController();
  final GlobalKey _signBoundaryKey = GlobalKey(); // To capture the signature strokes

  @override
  void initState() {
    super.initState();
    // 1. Lock screen to Landscape for better bill view
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
  }

  @override
  void dispose() {
    // 2. Return to Portrait on exit
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _zoomController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // --- UNIQUE CODE ENGINE (Alphanumeric) ---
  void _generateVerificationSeal(Offset firstTouch) {
    if (uniqueCode.isEmpty) {
      const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      uniqueCode = "VR-${List.generate(5, (i) => chars[Random().nextInt(chars.length)]).join()}";
      
      // Capture the first touch point as the base for mapping
      // Standard A4 container size will be used to calculate %
      setState(() {});
    }
  }

  // --- FINAL SAVE & SHARE ENGINE ---
  Future<void> _handleFinalize(PharoahManager ph) async {
    setState(() => isSaving = true);
    try {
      // 1. Capture ONLY the Signature Strokes as a transparent image
      RenderRepaintBoundary boundary = _signBoundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List sigPngBytes = byteData!.buffer.asUint8List();

      // 2. Save PNG to storage
      String savedImgPath = await ph.saveSignatureFile(widget.challan.billNo, sigPngBytes);

      // 3. Update Database with Coordinates & Code
      await ph.addSignatureToChallan(
        challanId: widget.challan.id,
        imagePath: savedImgPath,
        code: uniqueCode,
        amount: widget.challan.totalAmount,
        x: signXPercent,
        y: signYPercent,
      );

      // 4. GENERATE & SHARE ORIGINAL PDF (The Hybrid Logic)
      if (mounted) {
        // We will call the PDF Printer - It will now look for isSigned status
        await PdfRouterService.printChallan(
          challan: widget.challan, 
          party: widget.party, 
          ph: ph, 
          isSaleChallan: true
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Finalize Error: $e");
    }
    setState(() => isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    
    // Pagination: 15 items per page logic
    int itemsPerPage = 15;
    int totalPages = (widget.challan.items.length / itemsPerPage).ceil();
    if (totalPages == 0) totalPages = 1;

    return Scaffold(
      backgroundColor: const Color(0xFF2C2C2C),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildStepIndicator(totalPages),
          Expanded(
            child: InteractiveViewer(
              transformationController: _zoomController,
              panEnabled: !isSignMode,
              scaleEnabled: !isSignMode,
              minScale: 0.5,
              maxScale: 4.0,
              child: PageView.builder(
                controller: _pageController,
                physics: isSignMode ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
                itemCount: totalPages,
                onPageChanged: (i) => setState(() => currentPage = i),
                itemBuilder: (context, index) {
                  bool isLastPage = (index == totalPages - 1);
                  return _buildA4Paper(index, totalPages, isLastPage, ph);
                },
              ),
            ),
          ),
          _buildBottomActionPanel(ph),
        ],
      ),
    );
  }

  // --- UI: THE A4 VIRTUAL PAPER ---
  Widget _buildA4Paper(int pageIdx, int totalPages, bool isLastPage, PharoahManager ph) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 30),
        child: AspectRatio(
          aspectRatio: 1.414 / 1, // A4 Landscape
          child: Container(
            color: Colors.white,
            child: Stack(
              children: [
                // Layer 1: Content (Header + Table)
                _buildContent(pageIdx, totalPages, isLastPage, ph),
                
                // Layer 2: Universal Code Watermark
                if (uniqueCode.isNotEmpty) _buildWatermarkSeal(),

                // Layer 3: Signature Layer (Only on Last Page)
                if (isLastPage && isSignMode)
                  RepaintBoundary(
                    key: _signBoundaryKey,
                    child: GestureDetector(
                      onPanStart: (d) {
                        _generateVerificationSeal(d.localPosition);
                        // Store relative center for PDF mapping
                        signXPercent = d.localPosition.dx / (MediaQuery.of(context).size.width * 0.8); // Approx
                        signYPercent = d.localPosition.dy / (MediaQuery.of(context).size.height * 0.7);
                      },
                      onPanUpdate: (d) => setState(() => points.add(d.localPosition)),
                      onPanEnd: (d) => setState(() => points.add(null)),
                      child: CustomPaint(
                        painter: SignaturePainter(points: points),
                        size: Size.infinite,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(int pageIdx, int totalPages, bool isLastPage, PharoahManager ph) {
    final shop = ph.activeCompany!;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Header (Matches PDF)
          Row(children: [
            _headerBox(3, [
              Text(shop.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
              Text(shop.address, style: const TextStyle(fontSize: 8)),
              Text("GST: ${shop.gstin}", style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
            ]),
            _headerBox(2, [
              const Center(child: Text("DELIVERY CHALLAN", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, decoration: TextDecoration.underline))),
              const Divider(height: 10),
              Text("No: ${widget.challan.billNo}", style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
              Text("Date: ${DateFormat('dd/MM/yyyy').format(widget.challan.date)}", style: const TextStyle(fontSize: 8)),
            ]),
            _headerBox(3, [
              const Text("CONSIGNEE:", style: TextStyle(fontSize: 7, color: Colors.grey, fontWeight: FontWeight.bold)),
              Text(widget.party.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              Text("GST: ${widget.party.gst} | City: ${widget.party.city}", style: const TextStyle(fontSize: 8)),
            ]),
          ]),
          const SizedBox(height: 15),
          
          // Simplified Table for Preview
          _buildPageTable(pageIdx),
          
          const Spacer(),

          // --- SMART FOOTER LOGIC ---
          if (isLastPage) ...[
            const Divider(),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _buildSecurityDisclaimer(),
              Text("GRAND TOTAL: ₹${widget.challan.totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
            ]),
            const Align(alignment: Alignment.bottomRight, child: Text("Receiver's Sign (Sign anywhere on this page)", style: TextStyle(fontSize: 7, fontStyle: FontStyle.italic, color: Colors.grey))),
          ] else ...[
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _buildSecurityDisclaimer(),
              Text("Continued to Page ${pageIdx + 2}...", style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey)),
            ]),
          ]
        ],
      ),
    );
  }

  // --- SECURITY DISCLAIMER (Aapka bataya hua English message) ---
  Widget _buildSecurityDisclaimer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (uniqueCode.isNotEmpty) Text("DIGITAL SEAL: $uniqueCode", style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.red)),
        const SizedBox(height: 2),
        const SizedBox(
          width: 250,
          child: Text(
            "SECURITY NOTICE: This document is locked with a unique digital seal. Any unauthorized modification to the source data or this record will permanently invalidate the verification code.",
            style: TextStyle(fontSize: 6, color: Colors.blueGrey, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  // UI Helpers (Table, HeaderBox, etc.)
  Widget _headerBox(int f, List<Widget> ch) => Expanded(flex: f, child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(border: Border.all(width: 0.5, color: Colors.black38)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: ch)));

  Widget _buildPageTable(int pageIdx) {
    int start = pageIdx * 15;
    int end = (start + 15 < widget.challan.items.length) ? start + 15 : widget.challan.items.length;
    var pageItems = widget.challan.items.sublist(start, end);

    return Column(children: [
      Container(color: Colors.grey[200], child: Row(children: [
        _cell("S.N", 35, true), _cell("Description", 250, true, true),
        _cell("Batch", 90, true), _cell("Qty", 50, true), _cell("Total", 100, true),
      ])),
      ...pageItems.map((it) => Row(children: [
        _cell(it.srNo.toString(), 35, false), _cell(it.name, 250, false, true),
        _cell(it.batch, 90, false), _cell(it.qty.toInt().toString(), 50, false),
        _cell(it.total.toStringAsFixed(2), 100, false),
      ])).toList(),
    ]);
  }

  Widget _cell(String t, double w, bool b, [bool isLeft = false]) => Container(width: w, padding: const EdgeInsets.all(5), decoration: BoxDecoration(border: Border.all(color: Colors.black12, width: 0.3)), child: Text(t, textAlign: isLeft ? TextAlign.left : TextAlign.center, style: TextStyle(fontSize: 8, fontWeight: b ? FontWeight.bold : FontWeight.normal)));

  Widget _buildWatermarkSeal() => Positioned.fill(child: Center(child: IgnorePointer(child: Transform.rotate(angle: -0.4, child: Opacity(opacity: 0.12, child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(border: Border.all(color: Colors.red, width: 4)), child: Text(uniqueCode, style: const TextStyle(fontSize: 55, fontWeight: FontWeight.bold, color: Colors.red))))))));

  PreferredSizeWidget _buildAppBar() => AppBar(
    title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("Receiver Review: Page ${currentPage + 1}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      const Text("PINCH TO ZOOM | SWIPE FOR NEXT PAGE", style: TextStyle(fontSize: 9, color: Colors.greenAccent)),
    ]),
    backgroundColor: Colors.black,
    actions: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: isSignMode ? Colors.red : Colors.blueAccent),
          onPressed: () => setState(() => isSignMode = !isSignMode),
          icon: Icon(isSignMode ? Icons.zoom_in : Icons.draw_rounded, size: 16, color: Colors.white),
          label: Text(isSignMode ? "DONE SIGNING" : "SIGN ON LAST PAGE", style: const TextStyle(color: Colors.white, fontSize: 11)),
        ),
      )
    ],
  );

  Widget _buildStepIndicator(int total) => Container(width: double.infinity, padding: const EdgeInsets.all(5), color: Colors.black87, child: Center(child: Text("Page ${currentPage + 1} of $total", style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold))));

  Widget _buildBottomActionPanel(PharoahManager ph) {
    bool canFinalize = points.isNotEmpty && !isSaving;
    return Container(
      padding: const EdgeInsets.all(15), color: Colors.black,
      child: Row(children: [
        if (uniqueCode.isNotEmpty) Text(uniqueCode, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 18)),
        const Spacer(),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15)),
          onPressed: canFinalize ? () => _handleFinalize(ph) : null,
          icon: isSaving ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.verified),
          label: const Text("LOCK & GENERATE PDF"),
        )
      ]),
    );
  }
}

// --- CUSTOM PAINTER FOR SIGNATURE ---
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
