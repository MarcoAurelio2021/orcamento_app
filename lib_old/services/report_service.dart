import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/budget.dart';
import '../models/company_data.dart';
import '../models/budget_item.dart';

class ReportService {
  static final _currency =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  static final _date = DateFormat('dd/MM/yyyy HH:mm');

  static String budgetAsText(Budget budget,
      {CompanyData? company, bool includeCompany = false}) {
    final buffer = StringBuffer();

    if (includeCompany && company != null && company.hasAnyData) {
      buffer.writeln(company.name);
      if (company.cnpj.isNotEmpty) buffer.writeln('CNPJ: ${company.cnpj}');
      if (company.phone.isNotEmpty)
        buffer.writeln('Telefone: ${company.phone}');
      if (company.email.isNotEmpty) buffer.writeln('E-mail: ${company.email}');
      if (company.address.isNotEmpty)
        buffer.writeln('Endereço: ${company.address}');
      buffer.writeln('');
    }

    buffer.writeln('ORÇAMENTO ${budget.number}');
    buffer.writeln('Cliente: ${budget.clientName}');
    if (budget.technician.isNotEmpty)
      buffer.writeln('Técnico: ${budget.technician}');
    if (budget.address.isNotEmpty)
      buffer.writeln('Endereço: ${budget.address}');
    if (budget.paymentMethod.isNotEmpty)
      buffer.writeln('Pagamento: ${budget.paymentMethod}');
    buffer.writeln('Data: ${_date.format(budget.createdAt)}');
    buffer.writeln('');

    for (final item in budget.items) {
      final typeLabel =
          item.valueType == ItemValueType.fixed ? 'Fixo' : 'Percentual';
      final valueLabel = item.valueType == ItemValueType.fixed
          ? _currency.format(item.unitValue)
          : '${item.unitValue.toStringAsFixed(2)}%';
      final total = item.totalForFixedBase(budget.fixedSubtotal);
      buffer.writeln(
        '- ${item.name} | $typeLabel | $valueLabel | Qtd: ${item.quantity} | Total: ${_currency.format(total)}',
      );
    }

    buffer.writeln('');
    buffer.writeln('Subtotal: ${_currency.format(budget.subtotal)}');
    buffer.writeln('Desconto: ${_currency.format(budget.discountApplied)}');
    buffer.writeln('Total final: ${_currency.format(budget.totalFinal)}');

    if (budget.notes.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('Observações: ${budget.notes}');
    }

    return buffer.toString();
  }

  static Future<List<int>> buildPdf(
    Budget budget, {
    CompanyData? company,
    bool includeCompany = false,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          if (includeCompany && company != null && company.hasAnyData)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(company.name,
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 16)),
                if (company.cnpj.isNotEmpty) pw.Text('CNPJ: ${company.cnpj}'),
                if (company.phone.isNotEmpty)
                  pw.Text('Telefone: ${company.phone}'),
                if (company.email.isNotEmpty)
                  pw.Text('E-mail: ${company.email}'),
                if (company.address.isNotEmpty)
                  pw.Text('Endereço: ${company.address}'),
                pw.SizedBox(height: 16),
              ],
            ),
          pw.Text('Orçamento ${budget.number}',
              style:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
          pw.SizedBox(height: 8),
          pw.Text('Cliente: ${budget.clientName}'),
          if (budget.technician.isNotEmpty)
            pw.Text('Técnico: ${budget.technician}'),
          if (budget.address.isNotEmpty) pw.Text('Endereço: ${budget.address}'),
          if (budget.paymentMethod.isNotEmpty)
            pw.Text('Pagamento: ${budget.paymentMethod}'),
          pw.Text('Data: ${_date.format(budget.createdAt)}'),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: const ['Serviço', 'Tipo', 'Valor', 'Qtd', 'Total'],
            data: budget.items.map((item) {
              final total = item.totalForFixedBase(budget.fixedSubtotal);
              return [
                item.name,
                item.valueType == ItemValueType.fixed ? 'Fixo' : 'Percentual',
                item.valueType == ItemValueType.fixed
                    ? _currency.format(item.unitValue)
                    : '${item.unitValue.toStringAsFixed(2)}%',
                '${item.quantity}',
                _currency.format(total),
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 16),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Subtotal: ${_currency.format(budget.subtotal)}'),
                pw.Text(
                    'Desconto: ${_currency.format(budget.discountApplied)}'),
                pw.Text(
                  'Total final: ${_currency.format(budget.totalFinal)}',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ),
          if (budget.notes.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text('Observações',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(budget.notes),
          ],
        ],
      ),
    );

    return pdf.save();
  }
}
