import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../models/utilisateur_model.dart';

const Color emeraldDark = Color(0xFF0B4F36);
const Color brickRed = Color(0xFFB91C1C);
const Color textDark = Color(0xFF222222);

class MonQrCodeScreen extends StatefulWidget {
  final UtilisateurModel user;
  const MonQrCodeScreen({super.key, required this.user});

  @override
  State<MonQrCodeScreen> createState() => _MonQrCodeScreenState();
}

class _MonQrCodeScreenState extends State<MonQrCodeScreen> {
  // 0 = Mon Code, 1 = Scanner
  int _currentIndex = 0; 
  final MobileScannerController _cameraController = MobileScannerController();
  bool _hasScanned = false;

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  String _buildPayload() {
    final data = {
      'type': 'mafortune_profile',
      'id': widget.user.id,
      'nom': widget.user.nomComplet,
      'telephone': widget.user.telephone,
    };
    return jsonEncode(data);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    final barcode = capture.barcodes.firstOrNull;
    final raw = barcode?.rawValue;
    if (raw == null) return;

    setState(() => _hasScanned = true);
    _cameraController.stop();

    Map<String, dynamic>? data;
    try {
      data = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      data = null;
    }

    if (data == null || data['type'] != 'mafortune_profile') {
      _showResult(title: 'QR non reconnu', content: 'Ce code ne provient pas de MaFortune.', isError: true);
      return;
    }

    _showResult(title: data['nom'] ?? 'Contact', content: data['telephone'] ?? '', isError: false);
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
            Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_rounded, color: isError ? brickRed : emeraldDark, size: 48),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textDark), textAlign: TextAlign.center),
            if (content.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(content, style: TextStyle(fontSize: 15, color: Colors.grey[600])),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _hasScanned = false;
                    _cameraController.start();
                  });
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('QR Code', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: emeraldDark,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ✅ LE TOGGLE EN HAUT (Mon Code / Scanner)
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (_currentIndex != 0) {
                        setState(() => _currentIndex = 0);
                        _cameraController.stop(); // Éteint la caméra pour économiser la batterie
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _currentIndex == 0 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _currentIndex == 0 ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : [],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code_rounded, size: 18, color: _currentIndex == 0 ? emeraldDark : Colors.grey),
                          const SizedBox(width: 8),
                          Text('Mon Code', style: TextStyle(fontWeight: FontWeight.bold, color: _currentIndex == 0 ? emeraldDark : Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (_currentIndex != 1) {
                        setState(() => _currentIndex = 1);
                        _cameraController.start(); // Allume la caméra
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _currentIndex == 1 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _currentIndex == 1 ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : [],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code_scanner_rounded, size: 18, color: _currentIndex == 1 ? emeraldDark : Colors.grey),
                          const SizedBox(width: 8),
                          Text('Scanner', style: TextStyle(fontWeight: FontWeight.bold, color: _currentIndex == 1 ? emeraldDark : Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ✅ CONTENU QUI CHANGE SELON LE BOUTON CLIQUÉ
          Expanded(
            child: _currentIndex == 0 
                ? _buildMonCodeView() 
                : _buildScannerView(),
          ),
        ],
      ),
    );
  }

  // VUE 1 : MON CODE QR
  Widget _buildMonCodeView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: QrImageView(
                data: _buildPayload(),
                version: QrVersions.auto,
                size: 240,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: emeraldDark),
                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.circle, color: textDark),
              ),
            ),
            const SizedBox(height: 24),
            Text(widget.user.nomComplet, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textDark)),
            const SizedBox(height: 6),
            Text(widget.user.telephone, style: TextStyle(fontSize: 15, color: Colors.grey[600])),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: emeraldDark.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: emeraldDark),
                  const SizedBox(width: 8),
                  Flexible(child: Text('Faites scanner ce code pour partager vos coordonnées.', style: TextStyle(fontSize: 13, color: emeraldDark.withOpacity(0.9)))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // VUE 2 : LE SCANNER (CAMÉRA)
  Widget _buildScannerView() {
    return Stack(
      children: [
        MobileScanner(controller: _cameraController, onDetect: _onDetect),
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
        Positioned(
          top: 20,
          right: 20,
          child: IconButton(
            icon: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 28),
            onPressed: () => _cameraController.toggleTorch(),
          ),
        ),
      ],
    );
  }
}