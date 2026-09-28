import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/utilisateur_model.dart';

const Color emeraldDark = Color(0xFF0B4F36);
const Color textDark = Color(0xFF222222);

class MonQrCodeScreen extends StatelessWidget {
  final UtilisateurModel user;
  const MonQrCodeScreen({super.key, required this.user});

  String _buildPayload() {
    // Format JSON simple, facilement extensible plus tard (Moov, Mixx, etc.)
    final data = {
      'type': 'mafortune_profile',
      'id': user.id,
      'nom': user.nomComplet,
      'telephone': user.telephone,
    };
    return jsonEncode(data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Mon QR Code', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: emeraldDark,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
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
              Text(user.nomComplet, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textDark)),
              const SizedBox(height: 6),
              Text(user.telephone, style: TextStyle(fontSize: 15, color: Colors.grey[600])),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: emeraldDark.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: emeraldDark),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Faites scanner ce code pour partager vos coordonnées.',
                        style: TextStyle(fontSize: 13, color: emeraldDark.withOpacity(0.9)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}