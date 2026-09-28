import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/local_auth_service.dart';
import '../../services/tts_service.dart';

// 🎨 CHARTE GRAPHIQUE MA FORTUNE (Mobile) - Accessible partout dans ce fichier
const Color emeraldGreen = Color(0xFF0B4F36);
const Color terracotta = Color(0xFFD96B43);
const Color textDark = Color(0xFF222222); // Gris très foncé texturé pour le pavé
const Color errorRed = Color(0xFF9B2C2C);

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen>
    with TickerProviderStateMixin {
  final LocalAuthService _localAuth = LocalAuthService();
  final TtsService _tts = TtsService();

  List<int> _pin = [];
  List<int> _confirmPin = [];
  bool _isConfirming = false;
  bool _isLoading = false;
  String? _errorMessage;

  late AnimationController _shakeController;
  late AnimationController _successController;
  late AnimationController _fadeController;
  late Animation<double> _shakeAnim;
  late Animation<double> _successScale;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _successScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _successController, curve: Curves.elasticOut),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _successController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  List<int> get _currentPin => _isConfirming ? _confirmPin : _pin;

  void _appuyerTouche(int chiffre) {
    HapticFeedback.lightImpact();
    if (_currentPin.length >= 4) return;

    setState(() {
      _errorMessage = null;
      _currentPin.add(chiffre);
    });

    if (_currentPin.length == 4) {
      Future.delayed(const Duration(milliseconds: 200), _validerEtape);
    }
  }

  void _supprimer() {
    HapticFeedback.lightImpact();
    if (_currentPin.isEmpty) return;
    setState(() {
      _currentPin.removeLast();
      _errorMessage = null;
    });
  }

  Future<void> _validerEtape() async {
    if (!_isConfirming) {
      // Passage à la confirmation
      _fadeController.reset();
      setState(() {
        _isConfirming = true;
        _errorMessage = null;
      });
      _fadeController.forward();
      _tts.parler('Confirme ton code');
    } else {
      // Vérification
      if (_listEquals(_pin, _confirmPin)) {
        await _sauvegarderPin();
      } else {
        HapticFeedback.vibrate();
        _shakeController.reset();
        _shakeController.forward();
        setState(() {
          _confirmPin.clear();
          _errorMessage = 'Les codes ne correspondent pas.\nRéessaie.';
        });
        _tts.parler('Code incorrect, réessaie');
      }
    }
  }

  bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _sauvegarderPin() async {
    setState(() => _isLoading = true);
    try {
      final pinStr = _pin.join();
      await _localAuth.savePin(pinStr);
      _tts.parler('Code créé avec succès');
      await _successController.forward();

    if (mounted) {
  Navigator.pushReplacementNamed(context, '/mes_produits');
}
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erreur lors de la création du PIN';
        });
      }
    }
  }

  void _recommencer() {
    _fadeController.reset();
    setState(() {
      _pin.clear();
      _confirmPin.clear();
      _isConfirming = false;
      _errorMessage = null;
    });
    _fadeController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final currentLength = _currentPin.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            children: [
              // ── 1. HEADER : Vert Émeraude Sombre uni ──────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                decoration: const BoxDecoration(
                  color: emeraldGreen,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
                ),
                child: Column(
                  children: [
                    // ── 2. ICÔNE : Moderne et épurée (blanche) ─────────────
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                      ),
                      child: Center(
                        child: Icon(
                          _isConfirming ? Icons.lock_rounded : Icons.shield_outlined,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      _isConfirming ? 'Confirme ton code' : 'Crée ton code secret',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      _isConfirming
                          ? 'Entre le même code une deuxième fois'
                          : 'Ce code protège ton application',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 24),

                    // ── 3. INDICATEUR D'ÉTAPE ──────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildStep(!_isConfirming, _isConfirming, '1', 'Créer'),
                        _buildStepLine(_isConfirming),
                        _buildStep(_isConfirming, false, '2', 'Confirmer'),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // ── POINTS PIN ───────────────────────────────────────────────
              AnimatedBuilder(
                animation: _shakeAnim,
                builder: (context, child) {
                  final offset = _shakeAnim.value *
                      12 *
                      (1 - _shakeAnim.value) *
                      ((_shakeController.value > 0.5) ? -1 : 1);
                  return Transform.translate(
                    offset: Offset(offset, 0),
                    child: child,
                  );
                },
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        final filled = index < currentLength;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          width: filled ? 22 : 20,
                          height: filled ? 22 : 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: filled ? emeraldGreen : Colors.grey[300],
                            boxShadow: filled
                                ? [
                                    BoxShadow(
                                      color: emeraldGreen.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                        );
                      }),
                    ),

                    // Message d'erreur harmonisé
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 40),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: errorRed.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: errorRed.withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, color: errorRed, size: 18),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: errorRed,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const Spacer(),

              // ── 4. PAVÉ NUMÉRIQUE ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    _buildNumRow([1, 2, 3]),
                    const SizedBox(height: 14),
                    _buildNumRow([4, 5, 6]),
                    const SizedBox(height: 14),
                    _buildNumRow([7, 8, 9]),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        // Recommencer
                        Expanded(
                          child: GestureDetector(
                            onTap: _isConfirming ? _recommencer : null,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: 70,
                              decoration: BoxDecoration(
                                color: _isConfirming ? terracotta.withOpacity(0.1) : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: _isConfirming
                                    ? const Icon(Icons.refresh_rounded, color: terracotta, size: 28)
                                    : const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        ),
                        // 0
                        Expanded(child: _buildNumButton(0)),
                        // Supprimer
                        Expanded(
                          child: GestureDetector(
                            onTap: _supprimer,
                            child: Container(
                              height: 70,
                              decoration: const BoxDecoration(shape: BoxShape.circle),
                              child: const Center(
                                child: Icon(Icons.backspace_outlined, color: textDark, size: 28),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumRow(List<int> nums) {
    return Row(
      children: nums.map((n) {
        return Expanded(child: _buildNumButton(n));
      }).toList(),
    );
  }

  Widget _buildNumButton(int num) {
    return _PressableNumButton(
      number: num,
      onTap: () => _appuyerTouche(num),
    );
  }

  // ✅ CORRECTION : Utilisation dynamique du paramètre 'label'
  Widget _buildStep(bool isActive, bool isDone, String number, String label) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isActive || isDone ? Colors.white : Colors.white.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, color: emeraldGreen, size: 20)
                : Text(
                    number,
                    style: TextStyle(
                      color: isActive ? emeraldGreen : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label, // Affiche "Créer" pour l'étape 1 et "Confirmer" pour l'étape 2
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(bool active) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      width: 40,
      height: 2,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(1)),
      ),
    );
  }
}

// ─── Bouton numérique avec effet press ───────────────────────────────────────
class _PressableNumButton extends StatefulWidget {
  final int number;
  final VoidCallback onTap;

  const _PressableNumButton({
    required this.number,
    required this.onTap,
  });

  @override
  State<_PressableNumButton> createState() => _PressableNumButtonState();
}

class _PressableNumButtonState extends State<_PressableNumButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          height: 70,
          margin: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${widget.number}',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: textDark,
              ),
            ),
          ),
        ),
      ),
    );
  }
}