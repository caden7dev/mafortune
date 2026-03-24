import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload une photo de reçu
  Future<String> uploadReceiptPhoto({
    required File file,
    required String userId,
    required String transactionId,
  }) async {
    try {
      // Créer un nom de fichier unique
      String fileName = '${DateTime.now().millisecondsSinceEpoch}_$transactionId.jpg';
      String path = 'recus/$userId/$fileName';

      // Upload le fichier
      Reference ref = _storage.ref().child(path);
      UploadTask uploadTask = ref.putFile(file);

      // Attendre la fin de l'upload
      TaskSnapshot snapshot = await uploadTask;

      // Récupérer l'URL de téléchargement
      String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      throw 'Erreur lors de l\'upload de la photo: ${e.toString()}';
    }
  }

  // Upload une photo de profil
  Future<String> uploadProfilePhoto({
    required File file,
    required String userId,
  }) async {
    try {
      String fileName = 'profile_$userId.jpg';
      String path = 'profils/$fileName';

      Reference ref = _storage.ref().child(path);
      UploadTask uploadTask = ref.putFile(file);

      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      throw 'Erreur lors de l\'upload de la photo de profil: ${e.toString()}';
    }
  }

  // Supprimer un fichier
  Future<void> deleteFile(String fileUrl) async {
    try {
      Reference ref = _storage.refFromURL(fileUrl);
      await ref.delete();
    } catch (e) {
      throw 'Erreur lors de la suppression du fichier';
    }
  }

  // Upload avec progression
  Stream<double> uploadFileWithProgress({
    required File file,
    required String path,
  }) {
    Reference ref = _storage.ref().child(path);
    UploadTask uploadTask = ref.putFile(file);

    return uploadTask.snapshotEvents.map((TaskSnapshot snapshot) {
      return snapshot.bytesTransferred / snapshot.totalBytes;
    });
  }

  // Télécharger un fichier
  Future<File> downloadFile({
    required String fileUrl,
    required String localPath,
  }) async {
    try {
      Reference ref = _storage.refFromURL(fileUrl);
      File file = File(localPath);
      await ref.writeToFile(file);
      return file;
    } catch (e) {
      throw 'Erreur lors du téléchargement du fichier';
    }
  }

  // Lister les fichiers d'un utilisateur
  Future<List<String>> listUserFiles(String userId, String folder) async {
    try {
      String path = '$folder/$userId';
      Reference ref = _storage.ref().child(path);
      ListResult result = await ref.listAll();

      List<String> urls = [];
      for (Reference item in result.items) {
        String url = await item.getDownloadURL();
        urls.add(url);
      }

      return urls;
    } catch (e) {
      return [];
    }
  }

  // Obtenir les métadonnées d'un fichier
  Future<FullMetadata?> getFileMetadata(String fileUrl) async {
    try {
      Reference ref = _storage.refFromURL(fileUrl);
      return await ref.getMetadata();
    } catch (e) {
      return null;
    }
  }

  // Obtenir la taille d'un fichier
  Future<int?> getFileSize(String fileUrl) async {
    try {
      FullMetadata? metadata = await getFileMetadata(fileUrl);
      return metadata?.size;
    } catch (e) {
      return null;
    }
  }

  // Supprimer tous les fichiers d'un dossier
  Future<void> deleteFolder(String folderPath) async {
    try {
      Reference ref = _storage.ref().child(folderPath);
      ListResult result = await ref.listAll();

      // Supprimer tous les fichiers
      for (Reference item in result.items) {
        await item.delete();
      }

      // Supprimer les sous-dossiers récursivement
      for (Reference prefix in result.prefixes) {
        await deleteFolder(prefix.fullPath);
      }
    } catch (e) {
      throw 'Erreur lors de la suppression du dossier';
    }
  }

  // Vérifier si un fichier existe
  Future<bool> fileExists(String fileUrl) async {
    try {
      Reference ref = _storage.refFromURL(fileUrl);
      await ref.getMetadata();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Obtenir l'URL d'un fichier par son chemin
  Future<String?> getDownloadUrl(String path) async {
    try {
      Reference ref = _storage.ref().child(path);
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }
}