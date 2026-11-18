import 'package:flutter/material.dart';
import '../screens/commercant/notifications_screen.dart';
import '../core/utils/global_nav.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

class CustomBottomNav extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<CustomBottomNav> createState() => _CustomBottomNavState();
}

class _CustomBottomNavState extends State<CustomBottomNav> {
  // Nombre de notifications non lues POUR CET UTILISATEUR (créé une seule fois)
  Stream<int>? _unreadStream;

  @override
  void initState() {
    super.initState();
    _initUnreadStream();
  }

  Future<void> _initUnreadStream() async {
    final user = await AuthService().getCurrentUserData();
    if (user == null || !mounted) return;

    final since = NotificationService.sinceFor(user.dateCreation);
    setState(() {
      _unreadStream = NotificationService.streamBroadcast().map(
        (snap) => NotificationService.unreadCount(snap, user.id, since),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Détecte dynamiquement si on est en mode sombre
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Couleurs adaptatives selon le thème
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final shadowColor = isDark ? Colors.black.withOpacity(0.5) : Colors.black.withOpacity(0.05);
    final selectedColor = const Color(0xFF0B4F36); // Vert Émeraude (identique dans les deux modes)
    final unselectedColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: StreamBuilder<int>(
        stream: _unreadStream ?? const Stream<int>.empty(),
        builder: (context, snapshot) {
          final unreadCount = snapshot.data ?? 0;

          return BottomNavigationBar(
            currentIndex: widget.currentIndex,
            onTap: (index) {
              if (index == 3) {
                // L'onglet Notifications reste une page poussée (avec sa propre flèche retour)
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationsScreen(),
                  ),
                );
              } else {
                // On met à jour l'index global ET on revient au Dashboard existant
                globalNavIndex.value = index;
                Navigator.popUntil(context, ModalRoute.withName('/dashboard'));
              }
            },
            type: BottomNavigationBarType.fixed,
            selectedItemColor: selectedColor,
            unselectedItemColor: unselectedColor,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            elevation: 0,
            backgroundColor: Colors.transparent, // Le fond est géré par le Container parent
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded),
                label: 'Accueil',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart_rounded),
                label: 'Bilans',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.description_rounded),
                label: 'Rapports',
              ),
              BottomNavigationBarItem(
                icon: unreadCount > 0
                    ? Badge(
                        label: Text(
                          '$unreadCount',
                          style: const TextStyle(
                              fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: const Color(0xFFD96B43),
                        child: const Icon(Icons.notifications_rounded),
                      )
                    : const Icon(Icons.notifications_rounded),
                label: 'Alertes',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person_rounded),
                label: 'Profil',
              ),
            ],
          );
        },
      ),
    );
  }
}