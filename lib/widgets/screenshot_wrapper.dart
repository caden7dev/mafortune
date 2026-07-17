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
    // 1. On masque le bouton de capture immédiatement
    setState(() => _isCapturing = true);
    
    try {
      // On laisse le temps au framework de reconstruire l'arbre sans le bouton
      await Future.delayed(const Duration(milliseconds: 100));

      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();

      // ✅ Utilisation du répertoire de documents de l'application (Pas besoin de permissions intrusives)
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/mafortune_$timestamp.png');
      await file.writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✅ Capture sauvegardée dans vos documents !',
              style: TextStyle(fontSize: 14),
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Contenu principal avec coins arrondis ────────────────────────
        RepaintBoundary(
          key: _repaintKey,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40), // coins arrondis téléphone
            child: widget.child,
          ),
        ),

        // ── Bordure téléphone par-dessus ─────────────────────────────────
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                color: Colors.black,
                width: 6,
              ),
            ),
          ),
        ),

        // ── Bouton 📸 (Masqué pendant la capture) ────────────────────────
        if (!_isCapturing)
          Positioned(
            bottom: 110,
            right: 20,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _capture,
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    // ✅ Remplacement de withOpacity par la nouvelle norme de couleur
                    color: Colors.black.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: const Center(
                    child: Text('📸', style: TextStyle(fontSize: 20)),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}