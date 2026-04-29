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

  static const PdfColor _green = PdfColor.fromInt(0xFF2E7D32);
  static const PdfColor _lightGreen = PdfColor.fromInt(0xFFE8F5E9);
  static const PdfColor _red = PdfColor.fromInt(0xFFC62828);
  static const PdfColor _lightRed = PdfColor.fromInt(0xFFFFEBEE);
  static const PdfColor _grey = PdfColor.fromInt(0xFF757575);
  static const PdfColor _lightGrey = PdfColor.fromInt(0xFFF5F5F5);
  static const PdfColor _darkText = PdfColor.fromInt(0xFF1A1A1A);

  String _fmt(double v) => '${_currencyFormat.format(v)} FCFA';

  Future<void> exportRapportTransactions({
    required List<TransactionModel> transactions,
    required UtilisateurModel user,
    required DateTime dateDebut,
    required DateTime dateFin,
  }) async {
    final pdf = pw.Document();

    final totalRecettes = transactions
        .where((t) => t.estRecette)
        .fold(0.0, (s, t) => s + t.montant);
    final totalDepenses = transactions
        .where((t) => !t.estRecette)
        .fold(0.0, (s, t) => s + t.montant);
    final benefice = totalRecettes - totalDepenses;

    final Map<String, double> parCategorie = {};
    for (var t in transactions.where((t) => !t.estRecette)) {
      parCategorie[t.categorie] = (parCategorie[t.categorie] ?? 0) + t.montant;
    }
    final topCategories = parCategorie.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(user, dateDebut, dateFin),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          pw.SizedBox(height: 20),
          _sectionTitle('SYNTHÈSE FINANCIÈRE'),
          pw.SizedBox(height: 12),
          pw.Row(
            children: [
              pw.Expanded(child: _summaryCard('Total Recettes', _fmt(totalRecettes), _green, _lightGreen, '+')),
              pw.SizedBox(width: 10),
              pw.Expanded(child: _summaryCard('Total Dépenses', _fmt(totalDepenses), _red, _lightRed, '-')),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: _summaryCard(
                  'Bénéfice Net',
                  _fmt(benefice.abs()),
                  benefice >= 0 ? _green : _red,
                  benefice >= 0 ? _lightGreen : _lightRed,
                  benefice >= 0 ? '+' : '-',
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          if (topCategories.isNotEmpty) ...[
            _sectionTitle('TOP CATÉGORIES DE DÉPENSES'),
            pw.SizedBox(height: 10),
            ...topCategories.take(5).map((e) {
              final pct = totalDepenses > 0 ? (e.value / totalDepenses) : 0.0;
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(e.key, style: const pw.TextStyle(fontSize: 10)),
                        pw.Text(
                          '${_fmt(e.value)}  (${(pct * 100).toStringAsFixed(1)}%)',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Stack(
                      children: [
                        pw.Container(
                          height: 6,
                          decoration: pw.BoxDecoration(
                            color: _lightGrey,
                            borderRadius: pw.BorderRadius.circular(3),
                          ),
                        ),
                        pw.Container(
                          height: 6,
                          width: 400 * pct,
                          decoration: pw.BoxDecoration(
                            color: _red,
                            borderRadius: pw.BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            pw.SizedBox(height: 20),
          ],
          _sectionTitle('DÉTAIL DES TRANSACTIONS (${transactions.length})'),
          pw.SizedBox(height: 10),
          pw.Container(
            decoration: pw.BoxDecoration(
              color: _green,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: pw.Row(children: [
              _th('Date', flex: 2),
              _th('Type', flex: 1),
              _th('Catégorie', flex: 2),
              _th('Description', flex: 3),
              _th('Montant', flex: 2, align: pw.TextAlign.right),
            ]),
          ),
          ...transactions.asMap().entries.map((entry) {
            final i = entry.key;
            final t = entry.value;
            final bg = i % 2 == 0 ? PdfColors.white : _lightGrey;
            return pw.Container(
              color: bg,
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: pw.Row(children: [
                _td(_dateFormat.format(t.date), flex: 2),
                _td(
                  t.estRecette ? 'Recette' : 'Dépense',
                  flex: 1,
                  color: t.estRecette ? _green : _red,
                  bold: true,
                ),
                _td(t.categorie, flex: 2),
                _td(t.description ?? '-', flex: 3),
                _td(
                  '${t.estRecette ? '+' : '-'} ${_fmt(t.montant)}',
                  flex: 2,
                  align: pw.TextAlign.right,
                  color: t.estRecette ? _green : _red,
                  bold: true,
                ),
              ]),
            );
          }),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'rapport_mafortune_${_dateFormat.format(DateTime.now())}.pdf',
    );
  }

  Future<void> exportBilanBudget({
    required UtilisateurModel user,
    required double budgetMensuel,
    required double depensesActuelles,
    required DateTime mois,
    required Map<String, double> depensesParCategorie,
  }) async {
    final pdf = pw.Document();
    final reste = budgetMensuel - depensesActuelles;
    final pct = budgetMensuel > 0 ? depensesActuelles / budgetMensuel : 0.0;

    // ✅ Tri fait ici, en dehors du build
    final sortedCategories = depensesParCategorie.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(
          user,
          DateTime(mois.year, mois.month, 1),
          DateTime(mois.year, mois.month + 1, 0),
        ),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          pw.SizedBox(height: 20),
          _sectionTitle(
            'BILAN BUDGET — ${DateFormat('MMMM yyyy', 'fr_FR').format(mois).toUpperCase()}',
          ),
          pw.SizedBox(height: 16),
          pw.Row(children: [
            pw.Expanded(
              child: _summaryCard('Budget prévu', _fmt(budgetMensuel), _green, _lightGreen, ''),
            ),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: _summaryCard('Dépenses', _fmt(depensesActuelles), _red, _lightRed, '-'),
            ),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: _summaryCard(
                reste >= 0 ? 'Reste disponible' : 'Dépassement',
                _fmt(reste.abs()),
                reste >= 0 ? _green : _red,
                reste >= 0 ? _lightGreen : _lightRed,
                reste >= 0 ? '' : '!',
              ),
            ),
          ]),
          pw.SizedBox(height: 20),
          _sectionTitle('PROGRESSION DU BUDGET'),
          pw.SizedBox(height: 10),
          pw.Stack(children: [
            pw.Container(
              height: 20,
              decoration: pw.BoxDecoration(
                color: _lightGrey,
                borderRadius: pw.BorderRadius.circular(10),
              ),
            ),
            pw.Container(
              height: 20,
              width: 530 * pct.clamp(0.0, 1.0),
              decoration: pw.BoxDecoration(
                color: pct >= 1
                    ? _red
                    : pct >= 0.75
                        ? PdfColor.fromInt(0xFFFF9800)
                        : _green,
                borderRadius: pw.BorderRadius.circular(10),
              ),
            ),
            pw.Positioned(
              right: 8,
              top: 3,
              child: pw.Text(
                '${(pct * 100).toStringAsFixed(1)}%',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ),
          ]),
          pw.SizedBox(height: 20),

          // ✅ SECTION CORRIGÉE
          if (sortedCategories.isNotEmpty) ...[
            _sectionTitle('DÉPENSES PAR CATÉGORIE'),
            pw.SizedBox(height: 10),
            pw.Container(
              decoration: pw.BoxDecoration(
                color: _green,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: pw.Row(children: [
                _th('Catégorie', flex: 3),
                _th('Montant', flex: 2, align: pw.TextAlign.right),
                _th('% du budget', flex: 2, align: pw.TextAlign.right),
              ]),
            ),
            ...sortedCategories.asMap().entries.map((entry) {
              final i = entry.key;
              final e = entry.value;
              final catPct =
                  budgetMensuel > 0 ? (e.value / budgetMensuel * 100) : 0.0;
              return pw.Container(
                color: i % 2 == 0 ? PdfColors.white : _lightGrey,
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                child: pw.Row(children: [
                  _td(e.key, flex: 3),
                  _td(_fmt(e.value), flex: 2, align: pw.TextAlign.right, bold: true),
                  _td(
                    '${catPct.toStringAsFixed(1)}%',
                    flex: 2,
                    align: pw.TextAlign.right,
                    color: catPct > 30 ? _red : _grey,
                  ),
                ]),
              );
            }),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'budget_mafortune_${DateFormat('MM_yyyy').format(mois)}.pdf',
    );
  }

  pw.Widget _buildHeader(
      UtilisateurModel user, DateTime dateDebut, DateTime dateFin) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _green, width: 2)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('MaFortune',
                style: pw.TextStyle(
                    fontSize: 20, fontWeight: pw.FontWeight.bold, color: _green)),
            pw.Text('Gestion financière des commerçants du Togo',
                style: const pw.TextStyle(fontSize: 9, color: _grey)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text(user.nomComplet,
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.Text(user.email,
                style: const pw.TextStyle(fontSize: 9, color: _grey)),
            pw.Text(
              '${_dateFormat.format(dateDebut)} → ${_dateFormat.format(dateFin)}',
              style: const pw.TextStyle(fontSize: 9, color: _grey),
            ),
          ]),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _lightGrey, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Généré le ${_dateFormat.format(DateTime.now())} à ${_timeFormat.format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 8, color: _grey),
          ),
          pw.Text(
            'Page ${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: _grey),
          ),
        ],
      ),
    );
  }

  pw.Widget _sectionTitle(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: pw.BoxDecoration(
        color: _lightGreen,
        borderRadius: pw.BorderRadius.circular(6),
        border: const pw.Border(left: pw.BorderSide(color: _green, width: 3)),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
            fontSize: 12, fontWeight: pw.FontWeight.bold, color: _darkText),
      ),
    );
  }

  pw.Widget _summaryCard(
      String title, String value, PdfColor color, PdfColor bg, String prefix) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: color, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: const pw.TextStyle(fontSize: 9, color: _grey)),
          pw.SizedBox(height: 6),
          pw.Text(
            '$prefix $value',
            style: pw.TextStyle(
                fontSize: 12, fontWeight: pw.FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  pw.Widget _th(String text,
      {int flex = 1, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Text(text,
          style: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 9),
          textAlign: align),
    );
  }

  pw.Widget _td(String text,
      {int flex = 1,
      pw.TextAlign align = pw.TextAlign.left,
      PdfColor? color,
      bool bold = false}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Text(text,
          style: pw.TextStyle(
              color: color ?? _darkText,
              fontSize: 9,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
          textAlign: align),
    );
  }
}