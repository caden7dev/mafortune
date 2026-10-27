import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import '../models/transaction_model.dart';
import '../models/utilisateur_model.dart';

class LocalDatabaseService {
  static final LocalDatabaseService _instance = LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  static Database? _database;
  
  // Nom de la base de données
  static const String _dbName = 'mafortune.db';
  static const int _dbVersion = 1;
  
  // Noms des tables
  static const String tableTransactions = 'transactions';
  static const String tableUtilisateurs = 'utilisateurs';
  static const String tableCategories = 'categories';
  static const String tableSyncQueue = 'sync_queue';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, _dbName);
    
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Table des transactions
    await db.execute('''
      CREATE TABLE $tableTransactions (
        id TEXT PRIMARY KEY,
        commercantId TEXT NOT NULL,
        type TEXT NOT NULL,
        montant REAL NOT NULL,
        categorie TEXT NOT NULL,
        categorieId TEXT NOT NULL,
        description TEXT,
        date TEXT NOT NULL,
        dateCreation TEXT NOT NULL,
        modePaiement TEXT,
        estSynchronise INTEGER DEFAULT 0,
        photoRecu TEXT
      )
    ''');
    
    // Table des utilisateurs
    await db.execute('''
      CREATE TABLE $tableUtilisateurs (
        id TEXT PRIMARY KEY,
        nom TEXT NOT NULL,
        prenom TEXT NOT NULL,
        email TEXT NOT NULL,
        telephone TEXT NOT NULL,
        typeUtilisateur TEXT NOT NULL,
        estActif INTEGER DEFAULT 1,
        dateCreation TEXT NOT NULL,
        soldeActuel REAL DEFAULT 0,
        typeActivite TEXT,
        adresse TEXT
      )
    ''');
    
    // Table des catégories
    await db.execute('''
      CREATE TABLE $tableCategories (
        id TEXT PRIMARY KEY,
        nom TEXT NOT NULL,
        type TEXT NOT NULL,
        icone TEXT,
        estParDefaut INTEGER DEFAULT 0
      )
    ''');
    
    // Table de file d'attente pour la synchronisation
    await db.execute('''
      CREATE TABLE $tableSyncQueue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operation TEXT NOT NULL,
        collection TEXT NOT NULL,
        data TEXT NOT NULL,
        dateCreation TEXT NOT NULL,
        tentatives INTEGER DEFAULT 0
      )
    ''');
    
    // Index pour améliorer les performances
    await db.execute('CREATE INDEX idx_transactions_date ON $tableTransactions(date)');
    await db.execute('CREATE INDEX idx_transactions_commercant ON $tableTransactions(commercantId)');
    await db.execute('CREATE INDEX idx_sync_queue_date ON $tableSyncQueue(dateCreation)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Gérer les migrations si nécessaire
    if (oldVersion < 2) {
      // Ajouter des colonnes si besoin
    }
  }

  // ==================== TRANSACTIONS ====================
  
  Future<void> insertTransaction(Map<String, dynamic> transaction) async {
    final db = await database;
    await db.insert(
      tableTransactions,
      transaction,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  Future<List<Map<String, dynamic>>> getTransactions(String commercantId) async {
    final db = await database;
    return await db.query(
      tableTransactions,
      where: 'commercantId = ?',
      whereArgs: [commercantId],
      orderBy: 'dateCreation DESC',
    );
  }
  
  Future<void> deleteTransaction(String id) async {
    final db = await database;
    await db.delete(
      tableTransactions,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  Future<void> updateTransaction(String id, Map<String, dynamic> data) async {
    final db = await database;
    await db.update(
      tableTransactions,
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  // ==================== UTILISATEURS ====================
  
  Future<void> insertUtilisateur(Map<String, dynamic> user) async {
    final db = await database;
    await db.insert(
      tableUtilisateurs,
      user,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  Future<Map<String, dynamic>?> getUtilisateur(String id) async {
    final db = await database;
    final result = await db.query(
      tableUtilisateurs,
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty ? result.first : null;
  }
  
  // ==================== FILE D'ATTENTE ====================
  
  Future<void> addToSyncQueue({
    required String operation,
    required String collection,
    required Map<String, dynamic> data,
  }) async {
    final db = await database;
    await db.insert(tableSyncQueue, {
      'operation': operation, // 'INSERT', 'UPDATE', 'DELETE'
      'collection': collection,
      'data': data.toString(),
      'dateCreation': DateTime.now().toIso8601String(),
      'tentatives': 0,
    });
  }
  
  Future<List<Map<String, dynamic>>> getPendingSyncItems() async {
    final db = await database;
    return await db.query(
      tableSyncQueue,
      orderBy: 'dateCreation ASC',
      limit: 100,
    );
  }
  
  Future<void> removeFromSyncQueue(int id) async {
    final db = await database;
    await db.delete(
      tableSyncQueue,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  Future<void> incrementSyncAttempts(int id) async {
    final db = await database;
    await db.update(
      tableSyncQueue,
      {'tentatives': db.rawUpdate('tentatives + 1')},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  // ==================== UTILITAIRES ====================
  
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete(tableTransactions);
    await db.delete(tableUtilisateurs);
    await db.delete(tableCategories);
    await db.delete(tableSyncQueue);
  }
  
  Future<int> getLocalTransactionsCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM $tableTransactions');
    return result.first['count'] as int;
  }
}