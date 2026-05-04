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
import '../pharoah_manager.dart';
import '../models.dart';
import '../pdf/sale_challan_pdf.dart';

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

  final PageController _pageController = PageController();
  final GlobalKey _signBoundaryKey = GlobalKey(); 

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeRight, DeviceOrientation.landscapeLeft]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _pageController.dispose();
    super.dispose();
  }

  void _generateCode(Offset touchPoint) {
    if (uniqueCode.isEmpty) {
      const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      setState(() {
        uniqueCode = "VR-${List.generate(5, (i) => chars[Random().nextInt(chars.length)]).join()}";
        signXPercent = touchPoint.dx / 800;
        signYPercent = touchPoint.dy / 550;
      });
    }
  }

  Future<void> _handleFinalize(PharoahManager ph) async {
    setState(() => isProcessing = true);
    try {
      RenderRepaintBoundary boundary = _signBoundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List sigBytes = byteData!.buffer.asUint8List();

      String savedImgPath = await ph.saveSignatureFile(widget.challan.billNo, sigBytes);
      await ph.addSignatureToChallan(
        challanId: widget.challan.id,
        imagePath: savedImgPath,
        code: uniqueCode,
        amount: widget.challan.totalAmount,
        x: signXPercent,
        y: signYPercent,
      );

      if (mounted) {
        final updatedChallan = ph.saleChallans.firstWhere((c) => c.id == widget.challan.id);
        _showSuccessActions(ph, updatedChallan);
      }
    } catch (e) {
      debugPrint("Finalize Error: $e");
    }
    setState(() => isProcessing = false);
  }

  void _showSuccessActions(PharoahManager ph, SaleChallan latestChallan) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Success! Verification Locked"),
        content: const Text("Challan is now secured. Share the professional signed PDF:"),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.all(15)),
            onPressed: () async {
              await SaleChallanPdf.generate(latestChallan, widget.party, ph.activeCompany!);
              Navigator.pop(c);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.share),
            label: const Text("SHARE ON WHATSAPP"),
          ),
          TextButton(onPressed: () { Navigator.pop(c); Navigator.pop(context); }, child: const Text("EXIT"))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    int itemsPerPage = 12;
    int totalPages = (widget.challan.items.length / itemsPerPage).ceil();
    if (totalPages == 0) totalPages = 1;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        title: Text("Receiver Review: Page ${currentPage + 1} of $totalPages"),
        backgroundColor: Colors.black,
        actions: [
          Padding(padding: const EdgeInsets.all(8.0), child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: isSignMode ? Colors.red : Colors.blueAccent),
            onPressed: () => setState(() => isSignMode = !isSignMode),
            icon: Icon(isSignMode ? Icons.done : Icons.draw),
            label: Text(isSignMode ? "DONE SIGNING" : "SIGN NOW"),
          ))
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: isSignMode ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
              itemCount: totalPages,
              onPageChanged: (i) => setState(() => currentPage = i),
              itemBuilder: (context, index) {
                bool isLastPage = (index == totalPages - 1);
                // --- FIX: Zoom inside each page ---
                return InteractiveViewer(
                  minScale: 1.0, maxScale: 4.0,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Container(
                        width: 800, height: 550,
                        margin: const EdgeInsets.all(20),
                        color: Colors.white,
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
                  ),
                );
              },
            ),
          ),
          _buildBottomActionPanel(ph),
        ],
      ),
    );
  }

  Widget _buildBillLayout(int pageIdx, int totalPages, bool isLastPage, PharoahManager ph) {
    final shop = ph.activeCompany!;
    return Padding(
      padding: const EdgeInsets.all(25),
      child: Column(
        children: [
          Row(children: [
            _headerBox(290, [
              Text(shop.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
              Text(shop.address, style: const TextStyle(fontSize: 9)),
              Text("GST: ${shop.gstin}", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
            ]),
            _headerBox(175, [
              const Center(child: Text("DELIVERY CHALLAN", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
              const Divider(),
              Text("No: ${widget.challan.billNo}", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
              Text("Date: ${DateFormat('dd/MM/yyyy').format(widget.challan.date)}", style: const TextStyle(fontSize: 9)),
            ]),
            _headerBox(335, [
              const Text("CONSIGNEE:", style: TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
              Text(widget.party.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Text("${widget.party.city} | GST: ${widget.party.gst}", style: const TextStyle(fontSize: 9)),
            ]),
          ]),
          const SizedBox(height: 20),
          _buildFullTable(pageIdx),
          const Spacer(),
          if (isLastPage) ...[
            const Divider(),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _buildSecurityDisclaimer(),
              Text("GRAND TOTAL: ₹${widget.challan.totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            ]),
          ] else
             Row(mainAxisAlignment: MainAxisAlignment.end, children: [Text("Continued to Page ${pageIdx + 2}...", style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic))]),
        ],
      ),
    );
  }

  Widget _buildFullTable(int pageIdx) {
    int start = pageIdx * 12;
    int end = (start + 12 < widget.challan.items.length) ? start + 12 : widget.challan.items.length;
    var pageItems = widget.challan.items.sublist(start, end);
    return Column(children: [
      Container(color: Colors.grey[100], child: Row(children: [
        _cell("S.N", 25, true), _cell("Qty+Free", 55, true), _cell("Pack", 45, true),
        _cell("Product Description", 210, true, true), _cell("Batch", 75, true),
        _cell("Exp", 45, true), _cell("HSN", 50, true), _cell("MRP", 55, true),
        _cell("Rate", 55, true), _cell("GST%", 30, true), _cell("Net Total", 155, true),
      ])),
      ...pageItems.map((it) => Row(children: [
        _cell(it.srNo.toString(), 25, false), _cell("${it.qty.toInt()} + ${it.freeQty.toInt()}", 55, false),
        _cell(it.packing, 45, false), _cell(it.name, 210, false, true), _cell(it.batch, 75, false),
        _cell(it.exp, 45, false), _cell(it.hsn, 50, false), _cell(it.mrp.toStringAsFixed(2), 55, false),
        _cell(it.rate.toStringAsFixed(2), 55, false), _cell("${it.gstRate.toInt()}%", 30, false), _cell(it.total.toStringAsFixed(2), 155, false),
      ])).toList(),
    ]);
  }

  Widget _cell(String t, double w, bool b, [bool isLeft = false]) => Container(width: w, padding: const EdgeInsets.all(6), decoration: BoxDecoration(border: Border.all(color: Colors.black12, width: 0.4)), child: Text(t, textAlign: isLeft ? TextAlign.left : TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: b ? FontWeight.bold : FontWeight.normal)));
  Widget _headerBox(double w, List<Widget> ch) => Container(width: w, padding: const EdgeInsets.all(8), decoration: BoxDecoration(border: Border.all(width: 0.5, color: Colors.black38)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: ch));
  Widget _buildSecurityDisclaimer() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (uniqueCode.isNotEmpty) Text("DIGITAL SEAL: $uniqueCode", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red)),
    const SizedBox(width: 320, child: Text("SECURITY NOTICE: Locked with unique digital seal. Any unauthorized modification will permanently invalidate this code.", style: TextStyle(fontSize: 7, color: Colors.blueGrey, fontWeight: FontWeight.bold))),
  ]);
  Widget _buildWatermarkSeal() => Positioned.fill(child: Center(child: IgnorePointer(child: Transform.rotate(angle: -0.4, child: Opacity(opacity: 0.1, child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(border: Border.all(color: Colors.red, width: 5)), child: Text(uniqueCode, style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: Colors.red))))))));
  Widget _buildBottomActionPanel(PharoahManager ph) => Container(padding: const EdgeInsets.all(15), color: Colors.black, child: Row(children: [
      if (uniqueCode.isNotEmpty) Text("CODE: $uniqueCode", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 18)),
      const Spacer(),
      ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15)), onPressed: (points.isEmpty || isProcessing) ? null : () => _handleFinalize(ph), icon: isProcessing ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.lock), label: const Text("LOCK & FINISH"))
  ]));
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
