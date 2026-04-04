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
  bool _showUnitValues = true;

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

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        children: [
          AppSectionCard(
            title: 'Gerar relatório',
            subtitle:
                'Pesquise apenas orçamentos já criados e escolha como visualizar ou compartilhar.',
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Pesquisar relatório por nome, número ou data',
                    prefixIcon: Icon(Icons.search),
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
                    TextButton(
                      onPressed: () => setState(() => _period = null),
                      child: const Text('Limpar período'),
                    ),
                    FilterChip(
                      label: const Text('Com dados da empresa'),
                      selected: _includeCompany,
                      onSelected: (value) =>
                          setState(() => _includeCompany = value),
                    ),
                    FilterChip(
                      label: const Text('Mostrar valor unitário'),
                      selected: _showUnitValues,
                      onSelected: (value) =>
                          setState(() => _showUnitValues = value),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: budgets.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child:
                            Text('Nenhum orçamento encontrado para relatório.'),
                      ),
                    )
                  : Scrollbar(
                      thumbVisibility: true,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: budgets.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final budget = budgets[index];
                          final selected = _selectedBudget?.id == budget.id;

                          return Container(
                            decoration: BoxDecoration(
                              color: selected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .secondary
                                      .withValues(alpha: 0.08)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: selected
                                    ? Theme.of(context).colorScheme.secondary
                                    : Colors.grey.shade300,
                                width: selected ? 1.4 : 1.0,
                              ),
                            ),
                            child: Column(
                              children: [
                                InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () {
                                    setState(() {
                                      _selectedBudget =
                                          selected ? null : budget;
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                budget.number,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                '${budget.clientName} • ${date.format(budget.createdAt)}',
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          currency.format(budget.totalFinal),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (selected)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      16,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        const Divider(height: 20),
                                        const Text(
                                          'Ações do orçamento',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(budget.clientName),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Total: ${currency.format(budget.totalFinal)}',
                                        ),
                                        const SizedBox(height: 16),
                                        ElevatedButton.icon(
                                          onPressed: () => _openPdf(budget),
                                          icon: const Icon(
                                            Icons.picture_as_pdf_outlined,
                                          ),
                                          label: Text(
                                            'Ver PDF - ${_includeCompany ? 'Com' : 'Sem'} dados da empresa',
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        OutlinedButton.icon(
                                          onPressed: () => _sharePdf(budget),
                                          icon:
                                              const Icon(Icons.share_outlined),
                                          label: Text(
                                            'Compartilhar PDF - ${_includeCompany ? 'Com' : 'Sem'} dados',
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        OutlinedButton.icon(
                                          onPressed: () => _shareText(budget),
                                          icon: const Icon(
                                            Icons.text_snippet_outlined,
                                          ),
                                          label: Text(
                                            'Compartilhar texto - ${_includeCompany ? 'Com' : 'Sem'} dados',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
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
              showUnitValues: _showUnitValues,
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
      showUnitValues: _showUnitValues,
    );

    if (!mounted) return;

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

  Future<void> _shareText(Budget budget) async {
    final appState = context.read<AppState>();

    final text = ReportService.budgetAsText(
      budget,
      company: appState.company,
      includeCompany: _includeCompany,
      showUnitValues: _showUnitValues,
    );

    if (!mounted) return;

    await Share.share(text);
  }
}
