import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../models/utilisateur_model.dart';

class PdfExportService {
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'fr_FR');
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy', 'fr_FR');
  final DateFormat _timeFormat = DateFormat('HH:mm', 'fr_FR');

  // ✅ Fonction utilitaire pour créer une couleur avec transparence
  PdfColor _colorWithOpacity(PdfColor color, double opacity) {
    return PdfColor(
      color.red,
      color.green,
      color.blue,
      opacity,
    );
  }

  Future<void> exportRapportTransactions({
    required List<TransactionModel> transactions,
    required UtilisateurModel user,
    required DateTime dateDebut,
    required DateTime dateFin,
  }) async {
    final pdf = pw.Document();

    final totalRecettes = transactions.where((t) => t.estRecette).fold(0.0, (sum, t) => sum + t.montant);
    final totalDepenses = transactions.where((t) => !t.estRecette).fold(0.0, (sum, t) => sum + t.montant);
    final beneficeNet = totalRecettes - totalDepenses;

    // Page 1 : En-tête et synthèse
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Center(
            child: pw.Column(
              children: [
                pw.SizedBox(height: 20),
                pw.Text(
                  'RAPPORT FINANCIER',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'MaFortune - Gestion financière',
                  style: pw.TextStyle(fontSize: 12, color: PdfColors.grey),
                ),
                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.SizedBox(height: 20),
                
                _buildInfoRow('Commerçant', '${user.prenom} ${user.nom}'),
                _buildInfoRow('Email', user.email),
                _buildInfoRow('Téléphone', user.telephone),
                _buildInfoRow('Activité', user.typeActivite ?? 'Non renseigné'),
                _buildInfoRow('Période', '${_dateFormat.format(dateDebut)} - ${_dateFormat.format(dateFin)}'),
                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.SizedBox(height: 20),
                
                pw.Text(
                  'SYNTHÈSE',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                _buildSummaryCard('Total Recettes', _formatAmount(totalRecettes), PdfColors.green),
                _buildSummaryCard('Total Dépenses', _formatAmount(totalDepenses), PdfColors.red),
                _buildSummaryCard('Bénéfice Net', _formatAmount(beneficeNet), 
                  beneficeNet >= 0 ? PdfColors.green : PdfColors.red),
                pw.SizedBox(height: 20),
                pw.Divider(),
              ],
            ),
          ),
        ],
      ),
    );

    // Page 2 : Liste des transactions
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(
            'DÉTAIL DES TRANSACTIONS',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 15),
          
          // En-tête du tableau
          pw.Container(
            decoration: pw.BoxDecoration(
              color: PdfColors.green,
              borderRadius: pw.BorderRadius.circular(5),
            ),
            padding: const pw.EdgeInsets.all(8),
            child: pw.Row(
              children: [
                _buildHeaderCell('Date', flex: 2),
                _buildHeaderCell('Type', flex: 1),
                _buildHeaderCell('Catégorie', flex: 2),
                _buildHeaderCell('Description', flex: 3),
                _buildHeaderCell('Montant', flex: 2, align: pw.TextAlign.right),
              ],
            ),
          ),
          
          pw.SizedBox(height: 5),
          
          ...transactions.map((t) => pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
            ),
            child: pw.Row(
              children: [
                _buildCell(_dateFormat.format(t.date), flex: 2),
                _buildCell(t.estRecette ? 'Recette' : 'Dépense', flex: 1,
                  color: t.estRecette ? PdfColors.green : PdfColors.red),
                _buildCell(t.categorie, flex: 2),
                _buildCell(t.description ?? '-', flex: 3),
                _buildCell('${t.estRecette ? '+' : '-'} ${_formatAmount(t.montant)}', flex: 2,
                  align: pw.TextAlign.right,
                  color: t.estRecette ? PdfColors.green : PdfColors.red),
              ],
            ),
          )).toList(),
          
          pw.SizedBox(height: 20),
          
          pw.Divider(),
          pw.SizedBox(height: 10),
          pw.Text(
            'Document généré le ${_dateFormat.format(DateTime.now())} à ${_timeFormat.format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'rapport_${_dateFormat.format(DateTime.now())}.pdf',
    );
  }

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Text(': '),
          pw.Text(value),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryCard(String title, String value, PdfColor color) {
    // ✅ Correction : utiliser _colorWithOpacity au lieu de withOpacity
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 5),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _colorWithOpacity(color, 0.1),
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _colorWithOpacity(color, 0.3)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildHeaderCell(String text, {int flex = 1, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Text(
        text,
        style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
        textAlign: align,
      ),
    );
  }

  pw.Widget _buildCell(String text, {int flex = 1, pw.TextAlign align = pw.TextAlign.left, PdfColor? color}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Text(
        text,
        style: pw.TextStyle(color: color ?? PdfColors.black, fontSize: 10),
        textAlign: align,
      ),
    );
  }

  String _formatAmount(double amount) {
    return '${_currencyFormat.format(amount)} FCFA';
  }
}