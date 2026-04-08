import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app/app_state.dart';
import '../models/budget.dart';
import '../services/report_service.dart';
import 'widgets/app_section_card.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _searchController = TextEditingController();
  DateTimeRange? _period;
  Budget? _selectedBudget;
  bool _includeCompany = true;
  ReportPdfOptions _reportOptions = const ReportPdfOptions();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final date = DateFormat('dd/MM/yyyy');

    final budgets = appState.budgets.where((budget) {
      final query = _searchController.text.trim().toLowerCase();
      final matchesText = query.isEmpty ||
          budget.clientName.toLowerCase().contains(query) ||
          budget.number.toLowerCase().contains(query) ||
          date.format(budget.createdAt).contains(query);

      final matchesPeriod = _period == null ||
          (budget.createdAt.isAfter(
                _period!.start.subtract(const Duration(days: 1)),
              ) &&
              budget.createdAt.isBefore(
                _period!.end.add(const Duration(days: 1)),
              ));

      return matchesText && matchesPeriod;
    }).toList();

    if (_selectedBudget != null &&
        !budgets.any((budget) => budget.id == _selectedBudget!.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _selectedBudget = null);
        }
      });
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        final reportsListCard = AppSectionCard(
          title: 'Escolher relatório',
          subtitle:
              'Selecione um orçamento da lista para visualizar ou compartilhar.',
          child: SizedBox(
            width: double.infinity,
            child: budgets.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('Nenhum orçamento encontrado para relatório.'),
                    ),
                  )
                : ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: 180,
                      maxHeight: isWide ? 520 : 320,
                    ),
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: budgets.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final budget = budgets[index];
                          final selected = _selectedBudget?.id == budget.id;

                          return Material(
                            color: selected
                                ? Theme.of(context)
                                    .colorScheme
                                    .secondary
                                    .withValues(alpha: 0.08)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              title: Text(budget.number),
                              subtitle: Text(
                                '${budget.clientName} • ${date.format(budget.createdAt)}',
                              ),
                              trailing: Text(currency.format(budget.totalFinal)),
                              onTap: () =>
                                  setState(() => _selectedBudget = budget),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
          ),
        );

        final detailsCard = AppSectionCard(
          title: 'Filtros do PDF',
          subtitle:
              'Marque exatamente o que deve aparecer no PDF antes de visualizar ou compartilhar.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Dados da empresa',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Com dados da empresa'),
                    selected: _includeCompany,
                    showCheckmark: true,
                    onSelected: (_) => setState(() => _includeCompany = true),
                  ),
                  FilterChip(
                    label: const Text('Sem dados da empresa'),
                    selected: !_includeCompany,
                    showCheckmark: true,
                    onSelected: (_) => setState(() => _includeCompany = false),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Campos dos itens',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildItemChip('Serviço', _reportOptions.showService,
                      (v) => _updateOptions(showService: v)),
                  _buildItemChip('Tipo', _reportOptions.showType,
                      (v) => _updateOptions(showType: v)),
                  _buildItemChip('Valor do item', _reportOptions.showItemValue,
                      (v) => _updateOptions(showItemValue: v)),
                  _buildItemChip('Passar fio', _reportOptions.showWirePass,
                      (v) => _updateOptions(showWirePass: v)),
                  _buildItemChip('Qtd', _reportOptions.showQuantity,
                      (v) => _updateOptions(showQuantity: v)),
                  _buildItemChip('Total dos itens', _reportOptions.showItemsTotal,
                      (v) => _updateOptions(showItemsTotal: v)),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Totais do orçamento',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildItemChip('Subtotal', _reportOptions.showSubtotal,
                      (v) => _updateOptions(showSubtotal: v)),
                  _buildItemChip('Desconto', _reportOptions.showDiscount,
                      (v) => _updateOptions(showDiscount: v)),
                  _buildItemChip('Total final', _reportOptions.showTotalFinal,
                      (v) => _updateOptions(showTotalFinal: v)),
                  _buildItemChip('Observações', _reportOptions.showNotes,
                      (v) => _updateOptions(showNotes: v)),
                ],
              ),
              const SizedBox(height: 20),
              if (_selectedBudget == null)
                const Text('Selecione um orçamento na lista para liberar as ações.')
              else ...[
                Text(_selectedBudget!.clientName),
                const SizedBox(height: 6),
                Text('Total: ${currency.format(_selectedBudget!.totalFinal)}'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Prévia do relatório',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_includeCompany ? 'Com dados da empresa' : 'Sem dados da empresa'}',
                      ),
                      const SizedBox(height: 4),
                      Text(ReportService.filtersLabel(_reportOptions)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => _openPdf(_selectedBudget!),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Visualizar relatório'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _sharePdf(_selectedBudget!),
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Compartilhar PDF'),
                ),
              ],
            ],
          ),
        );

        return ListView(
          padding: EdgeInsets.zero,
          children: [
            AppSectionCard(
              title: 'Gerar relatório',
              subtitle:
                  'Pesquise apenas orçamentos já criados e escolha como visualizar ou compartilhar.',
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Pesquisar relatório por nome, número ou data',
                      hintText: 'Buscar orçamento...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final now = DateTime.now();
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(now.year - 3),
                            lastDate: DateTime(now.year + 1),
                            initialDateRange: _period,
                          );

                          if (picked != null) {
                            setState(() => _period = picked);
                          }
                        },
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Text(
                          _period == null
                              ? 'Escolher período'
                              : '${date.format(_period!.start)} - ${date.format(_period!.end)}',
                        ),
                      ),
                      if (_period != null)
                        TextButton.icon(
                          onPressed: () => setState(() => _period = null),
                          icon: const Icon(Icons.close),
                          label: const Text('Limpar período'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: reportsListCard),
                  const SizedBox(width: 16),
                  Expanded(flex: 4, child: detailsCard),
                ],
              )
            else
              Column(
                children: [
                  reportsListCard,
                  const SizedBox(height: 16),
                  detailsCard,
                ],
              ),
          ],
        );
      },
    );
  }

  Widget _buildItemChip(
    String label,
    bool selected,
    ValueChanged<bool> onSelected,
  ) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: true,
      onSelected: onSelected,
    );
  }

  void _updateOptions({
    bool? showService,
    bool? showType,
    bool? showItemValue,
    bool? showWirePass,
    bool? showQuantity,
    bool? showItemObservation,
    bool? showItemsTotal,
    bool? showSubtotal,
    bool? showDiscount,
    bool? showTotalFinal,
    bool? showNotes,
  }) {
    setState(() {
      _reportOptions = _reportOptions.copyWith(
        showService: showService,
        showType: showType,
        showItemValue: showItemValue,
        showWirePass: showWirePass,
        showQuantity: showQuantity,
        showItemObservation: showItemObservation,
        showItemsTotal: showItemsTotal,
        showSubtotal: showSubtotal,
        showDiscount: showDiscount,
        showTotalFinal: showTotalFinal,
        showNotes: showNotes,
      );
    });
  }

  Future<void> _openPdf(Budget budget) async {
    final appState = context.read<AppState>();

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfPreview(
          build: (_) async => Uint8List.fromList(
            await ReportService.buildPdf(
              budget,
              company: appState.company,
              includeCompany: _includeCompany,
              options: _reportOptions,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sharePdf(Budget budget) async {
    final appState = context.read<AppState>();

    final bytes = await ReportService.buildPdf(
      budget,
      company: appState.company,
      includeCompany: _includeCompany,
      options: _reportOptions,
    );

    if (!context.mounted) return;

    final file = XFile.fromData(
      Uint8List.fromList(bytes),
      mimeType: 'application/pdf',
      name: '${budget.number}.pdf',
    );

    await Share.shareXFiles(
      [file],
      text: 'Segue o orçamento ${budget.number}.',
    );
  }
}
