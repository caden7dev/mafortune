import 'package:flutter/material.dart';

// Contrôleur global pour garder en mémoire l'onglet actif dans toute l'application
final ValueNotifier<int> globalNavIndex = ValueNotifier<int>(0);