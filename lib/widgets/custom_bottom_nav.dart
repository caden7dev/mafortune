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
    // ✅ Récupère la hauteur de la barre système (barre de gestes Android)
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      // ✅ Ajoute le padding bas pour ne pas être caché par la barre système
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
            
            // ✅ MODIFICATION : Force la couleur de l'item actif en Vert Émeraude Sombre
            selectedItemColor: const Color(0xFF0B4F36), 
            
            unselectedItemColor: Colors.grey.shade600,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            
            // ✅ Supprime le padding interne par défaut du BottomNavigationBar
            // pour éviter le double espacement
            elevation: 0,
            backgroundColor: Colors.transparent,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded), // J'ai ajouté _rounded pour un look plus moderne
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
                        backgroundColor: const Color(0xFFD96B43), // ✅ Badge en Terre Cuite pour l'harmonie
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