import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart'; // ✅ Pour ouvrir le lien Notion

// 🎨 CHARTE GRAPHIQUE
const Color emeraldDark = Color(0xFF0B4F36);
const Color terracotta = Color(0xFFD96B43);
const Color textDark = Color(0xFF222222);

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool _isAccepted = false;

  // ✅ Fonction pour ouvrir ton lien Notion réel
  Future<void> _launchNotionPrivacy() async {
    final Uri url = Uri.parse('https://garnet-stone-55f.notion.site/Politique-de-Confidentialit-MaFortune-3e9256a556ad80409f3ad78e0a6c6e70'); 
    
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir le lien de confidentialité.')),
        );
      }
    }
  }

  Future<void> _acceptTerms() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('terms_accepted', true);
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/welcome'); 
    }
  }

  void _refuseTerms() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Accès refusé', style: TextStyle(color: textDark, fontWeight: FontWeight.bold)),
        content: const Text('Vous devez accepter les conditions d\'utilisation et la politique de confidentialité pour utiliser MaFortune.', style: TextStyle(fontSize: 15, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              SystemNavigator.pop(); // Ferme l'application
            },
            child: const Text('Quitter', style: TextStyle(color: terracotta, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(color: emeraldDark.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.shield_outlined, size: 40, color: emeraldDark),
                ),
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text('Bienvenue sur MaFortune', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textDark)),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text('Veuillez lire et accepter nos documents légaux pour garantir la sécurité de vos données.', style: TextStyle(fontSize: 15, color: Colors.grey, height: 1.5), textAlign: TextAlign.center),
              ),
              const SizedBox(height: 32),
              
              // ✅ BOUTON 1 : Conditions d'Utilisation (Dans l'app)
              _buildDocumentCard(
                icon: Icons.description_outlined,
                title: 'Conditions d\'Utilisation (CGU)',
                subtitle: 'Règles d\'utilisation, responsabilités et gestion du compte.',
                onTap: () {
                  Navigator.pushNamed(context, '/cgu'); 
                },
              ),

              const SizedBox(height: 16),

              // ✅ BOUTON 2 : Politique de Confidentialité (Ton lien Notion)
              _buildDocumentCard(
                icon: Icons.lock_outline,
                title: 'Politique de Confidentialité',
                subtitle: 'Comment nous protégeons et utilisons vos données.',
                onTap: _launchNotionPrivacy, // Ouvre ton lien Notion ici
              ),

              const Spacer(),

              // Case à cocher
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _isAccepted,
                    activeColor: emeraldDark,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (val) {
                      HapticFeedback.selectionClick();
                      setState(() => _isAccepted = val ?? false);
                    },
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isAccepted = !_isAccepted),
                      child: const Padding(
                        padding: EdgeInsets.only(top: 14),
                        child: Text('J\'ai lu et j\'accepte les conditions d\'utilisation et la politique de confidentialité.', style: TextStyle(fontSize: 14, color: textDark, height: 1.3)),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Boutons d'action
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _refuseTerms,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Colors.grey),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Refuser', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isAccepted ? _acceptTerms : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: emeraldDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Accepter et continuer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Widget personnalisé pour les cartes de documents
  Widget _buildDocumentCard({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, color: emeraldDark, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textDark)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}