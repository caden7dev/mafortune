/// Base de données locale des produits suggérés par type d'activité.
/// Utilisée lors de l'inscription pour pré-remplir la liste de produits.
class ProduitsParActivite {
  static const Map<String, List<Map<String, dynamic>>> produits = {
    'Commerce général': [
      {'nom': 'Sucre (1kg)', 'emoji': '🍚', 'prix': null},
      {'nom': 'Huile (1L)', 'emoji': '🫙', 'prix': null},
      {'nom': 'Riz (1kg)', 'emoji': '🍚', 'prix': null},
      {'nom': 'Farine (1kg)', 'emoji': '🌾', 'prix': null},
      {'nom': 'Savon', 'emoji': '🧼', 'prix': null},
      {'nom': 'Sel (1kg)', 'emoji': '🧂', 'prix': null},
      {'nom': 'Tomates (tas)', 'emoji': '🍅', 'prix': null},
      {'nom': 'Oignons (tas)', 'emoji': '🧅', 'prix': null},
    ],
    'Restauration': [
      {'nom': 'Repas du jour', 'emoji': '🍽️', 'prix': null},
      {'nom': 'Jus naturel', 'emoji': '🥤', 'prix': null},
      {'nom': 'Eau minérale', 'emoji': '💧', 'prix': null},
      {'nom': 'Café', 'emoji': '☕', 'prix': null},
      {'nom': 'Brochette', 'emoji': '🍢', 'prix': null},
      {'nom': 'Alloco', 'emoji': '🍌', 'prix': null},
      {'nom': 'Poulet braisé', 'emoji': '🍗', 'prix': null},
      {'nom': 'Boisson sucrée', 'emoji': '🥫', 'prix': null},
    ],
    'Vêtements': [
      {'nom': 'Pagne wax 6 yards', 'emoji': '🧣', 'prix': null},
      {'nom': 'Pagne bazin', 'emoji': '🧣', 'prix': null},
      {'nom': 'Pagne super', 'emoji': '🧣', 'prix': null},
      {'nom': 'Robe', 'emoji': '👗', 'prix': null},
      {'nom': 'Chemise', 'emoji': '👔', 'prix': null},
      {'nom': 'Pantalon', 'emoji': '👖', 'prix': null},
      {'nom': 'Chaussures', 'emoji': '👟', 'prix': null},
      {'nom': 'Sac', 'emoji': '👜', 'prix': null},
    ],
    'Pharmacie': [
      {'nom': 'Paracétamol', 'emoji': '💊', 'prix': null},
      {'nom': 'Amoxicilline', 'emoji': '💊', 'prix': null},
      {'nom': 'Sérum physiologique', 'emoji': '💉', 'prix': null},
      {'nom': 'Pansement', 'emoji': '🩹', 'prix': null},
      {'nom': 'Préservatif', 'emoji': '🔵', 'prix': null},
      {'nom': 'Vitamine C', 'emoji': '🍊', 'prix': null},
      {'nom': 'Sirop', 'emoji': '🧴', 'prix': null},
      {'nom': 'Coton', 'emoji': '🌿', 'prix': null},
    ],
    'Coiffure / Beauté': [
      {'nom': 'Coupe homme', 'emoji': '✂️', 'prix': null},
      {'nom': 'Tresse simple', 'emoji': '💆', 'prix': null},
      {'nom': 'Tresse avec extension', 'emoji': '💆', 'prix': null},
      {'nom': 'Défrisage', 'emoji': '💇', 'prix': null},
      {'nom': 'Coloration', 'emoji': '🎨', 'prix': null},
      {'nom': 'Manucure', 'emoji': '💅', 'prix': null},
      {'nom': 'Rasage', 'emoji': '🪒', 'prix': null},
      {'nom': 'Soin cheveux', 'emoji': '🧴', 'prix': null},
    ],
    'Agriculture': [
      {'nom': 'Tomates (kg)', 'emoji': '🍅', 'prix': null},
      {'nom': 'Oignons (kg)', 'emoji': '🧅', 'prix': null},
      {'nom': 'Piment (tas)', 'emoji': '🌶️', 'prix': null},
      {'nom': 'Gombo (tas)', 'emoji': '🥬', 'prix': null},
      {'nom': 'Manioc (kg)', 'emoji': '🌿', 'prix': null},
      {'nom': 'Maïs (kg)', 'emoji': '🌽', 'prix': null},
      {'nom': 'Igname (kg)', 'emoji': '🍠', 'prix': null},
      {'nom': 'Plantain (régime)', 'emoji': '🍌', 'prix': null},
    ],
    'Téléphonie': [
      {'nom': 'Crédit Togocel', 'emoji': '📱', 'prix': null},
      {'nom': 'Crédit Moov', 'emoji': '📱', 'prix': null},
      {'nom': 'Data internet', 'emoji': '📶', 'prix': null},
      {'nom': 'Coque téléphone', 'emoji': '📲', 'prix': null},
      {'nom': 'Écouteurs', 'emoji': '🎧', 'prix': null},
      {'nom': 'Chargeur', 'emoji': '🔌', 'prix': null},
      {'nom': 'Réparation écran', 'emoji': '🔧', 'prix': null},
      {'nom': 'Carte SIM', 'emoji': '💳', 'prix': null},
    ],
    'Artisanat': [
      {'nom': 'Main d\'œuvre', 'emoji': '🔨', 'prix': null},
      {'nom': 'Réparation', 'emoji': '🔧', 'prix': null},
      {'nom': 'Matériel', 'emoji': '🛠️', 'prix': null},
      {'nom': 'Sculpture', 'emoji': '🎭', 'prix': null},
      {'nom': 'Tissu', 'emoji': '🧵', 'prix': null},
      {'nom': 'Couture', 'emoji': '🪡', 'prix': null},
      {'nom': 'Poterie', 'emoji': '🏺', 'prix': null},
      {'nom': 'Vannerie', 'emoji': '🧺', 'prix': null},
    ],
    'Autre': [
      {'nom': 'Produit 1', 'emoji': '📦', 'prix': null},
      {'nom': 'Produit 2', 'emoji': '📦', 'prix': null},
      {'nom': 'Service', 'emoji': '🔧', 'prix': null},
    ],
  };

  /// Retourne les produits suggérés pour une activité donnée.
  /// Fait une correspondance partielle (insensible à la casse).
  static List<Map<String, dynamic>> getPourActivite(String typeActivite) {
    // Correspondance exacte
    if (produits.containsKey(typeActivite)) {
      return List<Map<String, dynamic>>.from(produits[typeActivite]!);
    }

    // Correspondance partielle
    for (final key in produits.keys) {
      if (typeActivite.toLowerCase().contains(key.toLowerCase()) ||
          key.toLowerCase().contains(typeActivite.toLowerCase())) {
        return List<Map<String, dynamic>>.from(produits[key]!);
      }
    }

    // Par défaut → Commerce général
    return List<Map<String, dynamic>>.from(produits['Commerce général']!);
  }
}