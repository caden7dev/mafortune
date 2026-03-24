import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primaryGreen,
        unselectedItemColor: Colors.grey.shade600,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home), 
            label: 'Accueil'
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart), 
            label: 'Bilans'
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.description), 
            label: 'Rapports'
          ),
          BottomNavigationBarItem(
            icon: Badge(
              label: Text('3', style: TextStyle(fontSize: 10)),
              backgroundColor: Colors.red,
              child: Icon(Icons.notifications),
            ),
            label: 'Alertes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person), 
            label: 'Profil'
          ),
        ],
      ),
    );
  }
}