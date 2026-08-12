import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../services/local_auth_service.dart';
import '../../services/tts_service.dart';

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
        // ✅ Redirige vers l'écran de sécurisation du compte
        Navigator.pushReplacementNamed(context, '/securiser_compte');
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
              // ── Header ─────────────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(28)),
                ),
                child: Column(
                  children: [
                    // Icône
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withOpacity(0.3), width: 2),
                      ),
                      child: Center(
                        child: Text(
                          _isConfirming ? '🔐' : '🔢',
                          style: const TextStyle(fontSize: 38),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      _isConfirming
                          ? 'Confirme ton code'
                          : 'Crée ton code secret',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      _isConfirming
                          ? 'Entre le même code une deuxième fois'
                          : 'Ce code protège ton application',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 24),

                    // Indicateur progression
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

              // ── Points PIN ─────────────────────────────────────────────────
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
                    // Points
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
                            color: filled
                                ? AppColors.primaryGreen
                                : Colors.grey[300],
                            boxShadow: filled
                                ? [
                                    BoxShadow(
                                      color: AppColors.primaryGreen
                                          .withOpacity(0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                        );
                      }),
                    ),

                    // Message erreur
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 40),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('⚠️', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 13,
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

              // ── Numpad ─────────────────────────────────────────────────────
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
                                color: _isConfirming
                                    ? Colors.orange.withOpacity(0.1)
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: _isConfirming
                                    ? const Text('↩️',
                                        style: TextStyle(fontSize: 28))
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
                              decoration: const BoxDecoration(
                                  shape: BoxShape.circle),
                              child: const Center(
                                child: Text('⌫',
                                    style: TextStyle(fontSize: 28)),
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

  Widget _buildStep(bool isActive, bool isDone, String number, String label) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isActive || isDone
                ? Colors.white
                : Colors.white.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isDone
                ? Icon(Icons.check,
                    color: AppColors.primaryGreen, size: 18)
                : Text(
                    number,
                    style: TextStyle(
                      color: isActive
                          ? AppColors.primaryGreen
                          : Colors.white60,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive
                ? Colors.white
                : Colors.white.withOpacity(0.5),
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
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
      decoration: BoxDecoration(
        color: active
            ? Colors.white
            : Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(1),
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
                color: Colors.black.withOpacity(0.07),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${widget.number}',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ),
        ),
      ),
    );
  }
}