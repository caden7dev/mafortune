import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/commercant/notifications_screen.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ Détecte dynamiquement si on est en mode sombre
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // ✅ Couleurs adaptatives selon le thème
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final shadowColor = isDark ? Colors.black.withOpacity(0.5) : Colors.black.withOpacity(0.05);
    final selectedColor = const Color(0xFF0B4F36); // Vert Émeraude (identique dans les deux modes)
    final unselectedColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: bgColor, // ✅ Couleur dynamique
        boxShadow: [
          BoxShadow(
            color: shadowColor, // ✅ Ombre adaptative
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('audience', whereIn: ['Tous', 'Commerçants'])
            .where('lu', isEqualTo: false)
            .snapshots(),
        builder: (context, snapshot) {
          int unreadCount = 0;
          if (snapshot.hasData && snapshot.data != null) {
            unreadCount = snapshot.data!.docs.length;
          }

          return BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: (index) {
              if (index == 3) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationsScreen(),
                  ),
                );
              } else {
                onTap(index);
              }
            },
            type: BottomNavigationBarType.fixed,
            selectedItemColor: selectedColor,
            unselectedItemColor: unselectedColor, // ✅ Couleur dynamique
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