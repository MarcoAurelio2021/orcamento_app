import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/budget.dart';
import '../models/budget_item.dart';
import '../models/company_data.dart';

class ReportPdfOptions {
  const ReportPdfOptions({
    this.showService = true,
    this.showType = true,
    this.showItemValue = false,
    this.showWirePass = false,
    this.showQuantity = true,
    this.showItemsTotal = false,
    this.showSubtotal = true,
    this.showDiscount = true,
    this.showTotalFinal = true,
    this.showNotes = true,
  });

  final bool showService;
  final bool showType;
  final bool showItemValue;
  final bool showWirePass;
  final bool showQuantity;
  final bool showItemsTotal;
  final bool showSubtotal;
  final bool showDiscount;
  final bool showTotalFinal;
  final bool showNotes;

  ReportPdfOptions copyWith({
    bool? showService,
    bool? showType,
    bool? showItemValue,
    bool? showWirePass,
    bool? showQuantity,
    bool? showItemsTotal,
    bool? showSubtotal,
    bool? showDiscount,
    bool? showTotalFinal,
    bool? showNotes,
  }) {
    return ReportPdfOptions(
      showService: showService ?? this.showService,
      showType: showType ?? this.showType,
      showItemValue: showItemValue ?? this.showItemValue,
      showWirePass: showWirePass ?? this.showWirePass,
      showQuantity: showQuantity ?? this.showQuantity,
      showItemsTotal: showItemsTotal ?? this.showItemsTotal,
      showSubtotal: showSubtotal ?? this.showSubtotal,
      showDiscount: showDiscount ?? this.showDiscount,
      showTotalFinal: showTotalFinal ?? this.showTotalFinal,
      showNotes: showNotes ?? this.showNotes,
    );
  }

  bool get hasAnyItemColumn =>
      showService ||
      showType ||
      showItemValue ||
      showWirePass ||
      showQuantity ||
      showItemsTotal;

  List<String> selectedLabels() {
    final labels = <String>[];

    if (showService) labels.add('Serviço');
    if (showType) labels.add('Tipo');
    if (showItemValue) labels.add('Valor do item');
    if (showWirePass) labels.add('Passar fio');
    if (showQuantity) labels.add('Qtd');
    if (showItemsTotal) labels.add('Total dos itens');
    if (showSubtotal) labels.add('Subtotal');
    if (showDiscount) labels.add('Desconto');
    if (showTotalFinal) labels.add('Total final');
    if (showNotes) labels.add('Observações');

    return labels;
  }
}

class ReportService {
  static final _currency =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  static final _date = DateFormat('dd/MM/yyyy HH:mm');

  static const PdfColor _brandPrimary = PdfColor.fromInt(0xFF1E2A78);
  static const PdfColor _brandSecondary = PdfColor.fromInt(0xFF5F8DBB);
  static const PdfColor _softBlue = PdfColor.fromInt(0xFFEAF1FF);
  static const PdfColor _pageBackground = PdfColor.fromInt(0xFFF8FAFD);
  static const PdfColor _textDark = PdfColor.fromInt(0xFF1F2937);
  static const PdfColor _textMuted = PdfColor.fromInt(0xFF6B7280);
  static const PdfColor _lineColor = PdfColor.fromInt(0xFFD7DEEA);
  static const PdfColor _successTint = PdfColor.fromInt(0xFFE8F1FF);

  static String filtersLabel(ReportPdfOptions options) {
    final labels = options.selectedLabels();
    if (labels.isEmpty) {
      return 'Nenhum campo selecionado';
    }
    return labels.join(' | ');
  }

  static String budgetAsText(
    Budget budget, {
    CompanyData? company,
    bool includeCompany = false,
    ReportPdfOptions options = const ReportPdfOptions(),
  }) {
    final buffer = StringBuffer();

    if (includeCompany && company != null && company.hasAnyData) {
      buffer.writeln(company.name);
      if (company.cnpj.isNotEmpty) buffer.writeln('CNPJ: ${company.cnpj}');
      if (company.phone.isNotEmpty) {
        buffer.writeln('Telefone: ${company.phone}');
      }
      if (company.email.isNotEmpty) buffer.writeln('E-mail: ${company.email}');
      if (company.address.isNotEmpty) {
        buffer.writeln('Endereço: ${company.address}');
      }
      buffer.writeln('');
    }

    buffer.writeln('Cliente: ${budget.clientName}');
    if (budget.technician.isNotEmpty) {
      buffer.writeln('Técnico: ${budget.technician}');
    }
    if (budget.address.isNotEmpty) {
      buffer.writeln('Endereço: ${budget.address}');
    }
    if (budget.paymentMethod.isNotEmpty) {
      buffer.writeln('Pagamento: ${budget.paymentMethod}');
    }
    buffer.writeln('Data: ${_date.format(budget.createdAt)}');
    buffer.writeln('');

    if (options.hasAnyItemColumn) {
      for (final item in budget.items) {
        final row = _rowForItem(item, budget.fixedSubtotal, options);
        if (row.isNotEmpty) {
          buffer.writeln('- ${row.join(' | ')}');
        }
      }
      buffer.writeln('');
    }

    if (options.showSubtotal) {
      buffer.writeln('Subtotal: ${_currency.format(budget.subtotal)}');
    }
    if (options.showDiscount) {
      buffer.writeln('Desconto: ${_currency.format(budget.discountApplied)}');
    }
    if (options.showTotalFinal) {
      buffer.writeln('Total final: ${_currency.format(budget.totalFinal)}');
    }

    if (options.showNotes && budget.notes.trim().isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('Observações: ${budget.notes}');
    }

    return buffer.toString();
  }

  static Future<List<int>> buildPdf(
    Budget budget, {
    CompanyData? company,
    bool includeCompany = false,
    ReportPdfOptions options = const ReportPdfOptions(),
  }) async {
    final pdf = pw.Document();

    final itemHeaders = _headersForOptions(options);
    final itemRows = budget.items
        .map((item) => _rowForItem(item, budget.fixedSubtotal, options))
        .where((row) => row.isNotEmpty)
        .toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 32),
        build: (context) => [
          _buildHeader(budget, company, includeCompany),
          pw.SizedBox(height: 18),
          _buildClientSection(budget),
          if (itemHeaders.isNotEmpty && itemRows.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            _buildItemsSection(itemHeaders, itemRows),
          ],
          if (options.showSubtotal ||
              options.showDiscount ||
              options.showTotalFinal) ...[
            pw.SizedBox(height: 18),
            _buildTotalsSection(budget, options),
          ],
          if (options.showNotes && budget.notes.trim().isNotEmpty) ...[
            pw.SizedBox(height: 18),
            _buildNotesSection(budget.notes),
          ],
        ],
        footer: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 12),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Speed Orçamento',
                style: const pw.TextStyle(
                  color: _textMuted,
                  fontSize: 9,
                ),
              ),
              pw.Text(
                'Página ${context.pageNumber} de ${context.pagesCount}',
                style: const pw.TextStyle(
                  color: _textMuted,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(
    Budget budget,
    CompanyData? company,
    bool includeCompany,
  ) {
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(
        gradient: const pw.LinearGradient(
          colors: [_brandPrimary, _brandSecondary],
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
        ),
        borderRadius: pw.BorderRadius.circular(18),
      ),
      padding: const pw.EdgeInsets.all(20),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 46,
            height: 46,
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(12),
            ),
            alignment: pw.Alignment.center,
            child: pw.Text(
              '⚡',
              style: const pw.TextStyle(fontSize: 22),
            ),
          ),
          pw.SizedBox(width: 14),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'ORÇAMENTO',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 20,
                    letterSpacing: 1.1,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Documento gerado em ${_date.format(budget.createdAt)}',
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 10.5,
                  ),
                ),
                if (includeCompany &&
                    company != null &&
                    company.hasAnyData) ...[
                  pw.SizedBox(height: 10),
                  pw.Text(
                    company.name,
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      if (company.cnpj.isNotEmpty)
                        _headerInfoChip('CNPJ: ${company.cnpj}'),
                      if (company.phone.isNotEmpty)
                        _headerInfoChip('Telefone: ${company.phone}'),
                      if (company.email.isNotEmpty)
                        _headerInfoChip('E-mail: ${company.email}'),
                    ],
                  ),
                  if (company.address.isNotEmpty) ...[
                    pw.SizedBox(height: 6),
                    pw.Text(
                      company.address,
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _headerInfoChip(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(20),
        border: pw.Border.all(
          color: PdfColor.fromInt(0xFFD7DEEA),
          width: 0.6,
        ),
      ),
      child: pw.Text(
        text,
        style: const pw.TextStyle(
          color: _brandPrimary,
          fontSize: 9.5,
        ),
      ),
    );
  }

  static pw.Widget _buildClientSection(Budget budget) {
    return _sectionCard(
      title: 'Dados do cliente',
      child: pw.Column(
        children: [
          _infoRow('Cliente', budget.clientName),
          if (budget.technician.isNotEmpty)
            _infoRow('Técnico', budget.technician),
          if (budget.address.isNotEmpty) _infoRow('Endereço', budget.address),
          if (budget.paymentMethod.isNotEmpty)
            _infoRow('Pagamento', budget.paymentMethod),
          _infoRow('Data', _date.format(budget.createdAt), isLast: true),
        ],
      ),
    );
  }

  static pw.Widget _buildItemsSection(
    List<String> headers,
    List<List<String>> rows,
  ) {
    return _sectionCard(
      title: 'Itens do orçamento',
      child: pw.TableHelper.fromTextArray(
        headers: headers,
        data: rows,
        headerStyle: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
          fontSize: 10,
        ),
        headerDecoration: const pw.BoxDecoration(
          color: _brandPrimary,
        ),
        cellStyle: const pw.TextStyle(
          color: _textDark,
          fontSize: 9.5,
        ),
        oddRowDecoration: const pw.BoxDecoration(
          color: _pageBackground,
        ),
        rowDecoration: const pw.BoxDecoration(
          color: PdfColors.white,
        ),
        cellPadding: const pw.EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 8,
        ),
        border: pw.TableBorder(
          horizontalInside: pw.BorderSide(color: _lineColor, width: 0.5),
          verticalInside: pw.BorderSide(color: _lineColor, width: 0.5),
          top: pw.BorderSide(color: _lineColor, width: 0.8),
          bottom: pw.BorderSide(color: _lineColor, width: 0.8),
          left: pw.BorderSide(color: _lineColor, width: 0.8),
          right: pw.BorderSide(color: _lineColor, width: 0.8),
        ),
      ),
    );
  }

  static pw.Widget _buildTotalsSection(
    Budget budget,
    ReportPdfOptions options,
  ) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 220,
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(16),
          border: pw.Border.all(color: _lineColor),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              'Resumo financeiro',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 11.5,
                color: _textDark,
              ),
            ),
            pw.SizedBox(height: 10),
            if (options.showSubtotal)
              _totalLine('Subtotal', _currency.format(budget.subtotal)),
            if (options.showDiscount)
              _totalLine('Desconto', _currency.format(budget.discountApplied)),
            if (options.showTotalFinal) ...[
              pw.SizedBox(height: 8),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                decoration: pw.BoxDecoration(
                  color: _successTint,
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Total final',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: _brandPrimary,
                        fontSize: 11.5,
                      ),
                    ),
                    pw.Text(
                      _currency.format(budget.totalFinal),
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: _brandPrimary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildNotesSection(String notes) {
    return _sectionCard(
      title: 'Observações',
      child: pw.Text(
        notes,
        style: const pw.TextStyle(
          fontSize: 10,
          color: _textDark,
          lineSpacing: 2,
        ),
      ),
    );
  }

  static pw.Widget _sectionCard({
    required String title,
    required pw.Widget child,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(16),
        border: pw.Border.all(color: _lineColor),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 12.5,
              color: _brandPrimary,
            ),
          ),
          pw.SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  static pw.Widget _infoRow(
    String label,
    String value, {
    bool isLast = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 7),
      decoration: pw.BoxDecoration(
        border: isLast
            ? null
            : const pw.Border(
                bottom: pw.BorderSide(
                  color: _lineColor,
                  width: 0.5,
                ),
              ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 72,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: _textMuted,
                fontSize: 10,
              ),
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(
                color: _textDark,
                fontSize: 10.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _totalLine(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(
              color: _textMuted,
              fontSize: 10.5,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              color: _textDark,
              fontWeight: pw.FontWeight.bold,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }

  static List<String> _headersForOptions(ReportPdfOptions options) {
    final headers = <String>[];
    if (options.showService) headers.add('Serviço');
    if (options.showType) headers.add('Tipo');
    if (options.showItemValue) headers.add('Valor do item');
    if (options.showWirePass) headers.add('Passar fio');
    if (options.showQuantity) headers.add('Qtd');
    if (options.showItemsTotal) headers.add('Total dos itens');
    return headers;
  }

  static List<String> _rowForItem(
    BudgetItem item,
    double fixedSubtotal,
    ReportPdfOptions options,
  ) {
    final total = item.totalForFixedBase(fixedSubtotal);
    final row = <String>[];

    if (options.showService) row.add(item.name);
    if (options.showType) {
      row.add(item.valueType == ItemValueType.fixed ? 'Fixo' : 'Percentual');
    }
    if (options.showItemValue) {
      row.add(
        item.valueType == ItemValueType.fixed
            ? _currency.format(item.adjustedUnitValue)
            : '${item.unitValue.toStringAsFixed(2)}%',
      );
    }
    if (options.showWirePass) {
      row.add(_wirePassLabel(item));
    }
    if (options.showQuantity) row.add('${item.quantity}');
    if (options.showItemsTotal) row.add(_currency.format(total));

    return row;
  }

  static String _wirePassLabel(BudgetItem item) {
    if (item.valueType != ItemValueType.fixed) {
      return 'Sem';
    }

    if (!item.hasWirePass) {
      return 'Sem';
    }

    if (item.wireChargeType == WireChargeType.fixed) {
      return 'Com (+${_currency.format(item.wireChargeValue)})';
    }

    return 'Com (+${item.wireChargeValue.toStringAsFixed(2)}%)';
  }
}
