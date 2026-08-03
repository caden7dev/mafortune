import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

class ScreenshotWrapper extends StatefulWidget {
  final Widget child;
  const ScreenshotWrapper({super.key, required this.child});

  @override
  State<ScreenshotWrapper> createState() => _ScreenshotWrapperState();
}

class _ScreenshotWrapperState extends State<ScreenshotWrapper> {
  final GlobalKey _repaintKey = GlobalKey();
  bool _isCapturing = false;

  Future<void> _capture() async {
    setState(() => _isCapturing = true);
    try {
      await Future.delayed(const Duration(milliseconds: 200));

      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // ✅ Sauvegarde dans /storage/emulated/0/Pictures/MaFortune/
      // Visible directement dans la Galerie du téléphone
      Directory? dir;

      if (Platform.isAndroid) {
        // Dossier Pictures public sur Android
        dir = Directory('/storage/emulated/0/Pictures/MaFortune');
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      // Crée le dossier s'il n'existe pas
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final file = File('${dir.path}/mafortune_$timestamp.png');
      await file.writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Capture sauvegardée dans Galerie → MaFortune',
              style: const TextStyle(fontSize: 14),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur : $e',
                style: const TextStyle(fontSize: 14)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RepaintBoundary(
          key: _repaintKey,
          child: widget.child,
        ),

        // Bouton 📸
        Positioned(
          bottom: 100,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isCapturing ? null : _capture,
              borderRadius: BorderRadius.circular(30),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: _isCapturing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('📸', style: TextStyle(fontSize: 20)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}