import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

const Color emeraldDark = Color(0xFF0B4F36);
const Color brickRed = Color(0xFFB91C1C);
const Color textDark = Color(0xFF222222);

class ScannerQrScreen extends StatefulWidget {
  const ScannerQrScreen({super.key});

  @override
  State<ScannerQrScreen> createState() => _ScannerQrScreenState();
}

class _ScannerQrScreenState extends State<ScannerQrScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _hasScanned = false;

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    final barcode = capture.barcodes.firstOrNull;
    final raw = barcode?.rawValue;
    if (raw == null) return;

    setState(() => _hasScanned = true);
    _controller.stop();

    Map<String, dynamic>? data;
    try {
      data = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      data = null;
    }

    if (data == null || data['type'] != 'mafortune_profile') {
      _showResult(
        title: 'QR non reconnu',
        content: 'Ce code ne provient pas de MaFortune.',
        isError: true,
      );
      return;
    }

    _showResult(
      title: data['nom'] ?? 'Contact',
      content: data['telephone'] ?? '',
      isError: false,
    );
  }

  void _showResult({required String title, required String content, required bool isError}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: isError ? brickRed : emeraldDark,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textDark), textAlign: TextAlign.center),
            if (content.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(content, style: TextStyle(fontSize: 15, color: Colors.grey[600])),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // ferme le sheet
                  setState(() => _hasScanned = false);
                  _controller.start(); // relance le scan
                },
                style: ElevatedButton.styleFrom(backgroundColor: emeraldDark, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Text('Scanner un autre code', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scanner un QR', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: emeraldDark,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_rounded),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}