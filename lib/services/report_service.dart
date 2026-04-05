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

    buffer.writeln('ORÇAMENTO ${budget.number}');
    buffer.writeln('Cliente: ${budget.clientName}');
    if (budget.technician.isNotEmpty) {
      buffer.writeln('Técnico: ${budget.technician}');
    }
    if (budget.address.isNotEmpty) buffer.writeln('Endereço: ${budget.address}');
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

    if (options.showNotes && budget.notes.isNotEmpty) {
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
        build: (context) => [
          if (includeCompany && company != null && company.hasAnyData)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  company.name,
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (company.cnpj.isNotEmpty) pw.Text('CNPJ: ${company.cnpj}'),
                if (company.phone.isNotEmpty) pw.Text('Telefone: ${company.phone}'),
                if (company.email.isNotEmpty) pw.Text('E-mail: ${company.email}'),
                if (company.address.isNotEmpty) pw.Text('Endereço: ${company.address}'),
                pw.SizedBox(height: 16),
              ],
            ),
          pw.Text(
            'Orçamento ${budget.number}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Cliente: ${budget.clientName}'),
          if (budget.technician.isNotEmpty) pw.Text('Técnico: ${budget.technician}'),
          if (budget.address.isNotEmpty) pw.Text('Endereço: ${budget.address}'),
          if (budget.paymentMethod.isNotEmpty) pw.Text('Pagamento: ${budget.paymentMethod}'),
          pw.Text('Data: ${_date.format(budget.createdAt)}'),
          if (itemHeaders.isNotEmpty && itemRows.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headers: itemHeaders,
              data: itemRows,
            ),
          ],
          if (options.showSubtotal || options.showDiscount || options.showTotalFinal) ...[
            pw.SizedBox(height: 16),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  if (options.showSubtotal)
                    pw.Text('Subtotal: ${_currency.format(budget.subtotal)}'),
                  if (options.showDiscount)
                    pw.Text('Desconto: ${_currency.format(budget.discountApplied)}'),
                  if (options.showTotalFinal)
                    pw.Text(
                      'Total final: ${_currency.format(budget.totalFinal)}',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (options.showNotes && budget.notes.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text(
              'Observações',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(budget.notes),
          ],
        ],
      ),
    );

    return pdf.save();
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
