import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import '../../services/delete_account_service.dart';
import '../../services/local_auth_service.dart';
import '../../models/utilisateur_model.dart';

// 🎨 CHARTE GRAPHIQUE MA FORTUNE
const Color emeraldGreen = Color(0xFF0B4F36);
const Color terracotta = Color(0xFFD96B43);
const Color textDark = Color(0xFF222222);
const Color textMedium = Color(0xFF555555);

class CompteEnSuppressionScreen extends StatefulWidget {
  final UtilisateurModel user;
  const CompteEnSuppressionScreen({super.key, required this.user});

  @override
  State<CompteEnSuppressionScreen> createState() => _CompteEnSuppressionScreenState();
}

class _CompteEnSuppressionScreenState extends State<CompteEnSuppressionScreen> {
  final AuthService _authService = AuthService();
  final DeleteAccountService _deleteService = DeleteAccountService();
  final LocalAuthService _localAuth = LocalAuthService();

  bool _isProcessing = false;

  // Calcul des jours restants
  int get _joursRestants {
    final dateDemande = widget.user.dateSuppressionDemandee ?? DateTime.now();
    final dateFin = dateDemande.add(const Duration(days: 30));
    final jours = dateFin.difference(DateTime.now()).inDays;
    return jours > 0 ? jours : 0;
  }

  // ✅ NOUVEAU : Fonction pour demander le PIN avant de réactiver
  Future<void> _verifierPinEtRestaurer() async {
    final pinController = TextEditingController();
    String? erreurPin;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Vérification de sécurité', textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 40, color: emeraldGreen),
              const SizedBox(height: 16),
              const Text(
                'Pour réactiver votre compte, veuillez entrer votre code PIN à 4 chiffres.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: textMedium),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 4,
                obscureText: true,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '****',
                  errorText: erreurPin,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: emeraldGreen, width: 2),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (pinController.text.length == 4) {
                  final estValide = await _localAuth.verifyPin(pinController.text);
                  if (estValide) {
                    Navigator.pop(ctx); // Fermer le dialog
                    _restaurerLeCompte(); // Lancer la restauration
                  } else {
                    setDialogState(() {
                      erreurPin = 'Code incorrect';
                      pinController.clear();
                    });
                    HapticFeedback.heavyImpact();
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: emeraldGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Valider'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _restaurerLeCompte() async {
    setState(() => _isProcessing = true);
    try {
      await _deleteService.restaurerCompte(widget.user.id);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Compte réactivé avec succès !'), backgroundColor: emeraldGreen),
      );
      
      // Redirection vers le dashboard
      Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _meDeconnecter() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.hourglass_empty_rounded, size: 80, color: terracotta),
              const SizedBox(height: 24),
              const Text(
                'Compte en attente de suppression',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textDark),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: terracotta.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: terracotta.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Text(
                      'Bonjour ${widget.user.prenom},',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textDark),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Votre compte sera définitivement effacé dans :',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: textMedium, height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$_joursRestants jours',
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: terracotta),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _verifierPinEtRestaurer, // ✅ Appelle la vérification PIN
                  icon: _isProcessing 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.undo_rounded, color: Colors.white),
                  label: const Text('Annuler la suppression', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: emeraldGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _isProcessing ? null : _meDeconnecter,
                child: const Text(
                  'Me déconnecter',
                  style: TextStyle(fontSize: 15, color: textMedium, decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}