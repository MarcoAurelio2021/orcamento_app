import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app/app_state.dart';
import '../models/budget.dart';
import '../models/budget_item.dart';
import 'widgets/app_section_card.dart';
import 'widgets/info_chip.dart';
import 'widgets/totals_card.dart';

class NewBudgetScreen extends StatefulWidget {
  const NewBudgetScreen({super.key});

  @override
  State<NewBudgetScreen> createState() => _NewBudgetScreenState();
}

class _NewBudgetScreenState extends State<NewBudgetScreen> {
  final _clientController = TextEditingController();
  final _technicianController = TextEditingController();
  final _addressController = TextEditingController();
  final _paymentController = TextEditingController();
  final _notesController = TextEditingController();
  final _serviceController = TextEditingController();
  final _valueController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _discountController = TextEditingController(text: '0');

  final _clientFormKey = GlobalKey<FormState>();
  final _itemFormKey = GlobalKey<FormState>();
  final _serviceFieldKey = GlobalKey();

  bool _started = false;
  DiscountType _discountType = DiscountType.fixed;
  ItemValueType _itemValueType = ItemValueType.fixed;
  List<BudgetItem> _items = [];

  @override
  void dispose() {
    _clientController.dispose();
    _technicianController.dispose();
    _addressController.dispose();
    _paymentController.dispose();
    _notesController.dispose();
    _serviceController.dispose();
    _valueController.dispose();
    _quantityController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  double get _discountValue =>
      double.tryParse(_discountController.text.replaceAll(',', '.')) ?? 0;

  double get _fixedSubtotal => _items
      .where((item) => item.valueType == ItemValueType.fixed)
      .fold<double>(0, (sum, item) => sum + item.totalForFixedBase(0));

  double get _percentageSubtotal => _items
      .where((item) => item.valueType == ItemValueType.percentage)
      .fold<double>(
        0,
        (sum, item) => sum + item.totalForFixedBase(_fixedSubtotal),
      );

  double get _subtotal => _fixedSubtotal + _percentageSubtotal;

  double get _discountApplied {
    if (_discountType == DiscountType.fixed) {
      return _discountValue.clamp(0, _subtotal);
    }
    return (_subtotal * (_discountValue / 100)).clamp(0, _subtotal);
  }

  double get _totalFinal =>
      (_subtotal - _discountApplied).clamp(0, double.infinity);

  void _startBudget() {
    if (_clientFormKey.currentState?.validate() ?? false) {
      setState(() => _started = true);
    }
  }

  List<_ItemSuggestion> _buildSuggestions(AppState appState, String query) {
    final map = <String, _ItemSuggestion>{};

    for (final service in appState.services) {
      final key = service.name.trim().toLowerCase();
      if (key.isEmpty) continue;

      map[key] = _ItemSuggestion(
        name: service.name.trim(),
        valueType: service.valueType,
        unitValue: service.defaultValue,
        source: 'service',
      );
    }

    for (final budget in appState.budgets) {
      for (final item in budget.items) {
        final key = item.name.trim().toLowerCase();
        if (key.isEmpty) continue;

        map[key] ??= _ItemSuggestion(
          name: item.name.trim(),
          valueType: item.valueType,
          unitValue: item.unitValue,
          source: 'budget_item',
        );
      }
    }

    for (final item in _items) {
      final key = item.name.trim().toLowerCase();
      if (key.isEmpty) continue;

      map[key] = _ItemSuggestion(
        name: item.name.trim(),
        valueType: item.valueType,
        unitValue: item.unitValue,
        source: 'current_item',
      );
    }

    final normalizedQuery = query.trim().toLowerCase();
    final all = map.values.toList()..sort((a, b) => a.name.compareTo(b.name));

    if (normalizedQuery.isEmpty) {
      return all.take(12).toList();
    }

    return all
        .where((item) => item.name.toLowerCase().contains(normalizedQuery))
        .take(12)
        .toList();
  }

  void _applySuggestion(_ItemSuggestion suggestion) {
    setState(() {
      _serviceController.text = suggestion.name;
      _itemValueType = suggestion.valueType;
      _valueController.text = suggestion.unitValue.toStringAsFixed(2);
    });
  }

  bool _sameBusinessItem({
    required BudgetItem existing,
    required String name,
    required ItemValueType valueType,
    required double unitValue,
  }) {
    return existing.name.trim().toLowerCase() == name.trim().toLowerCase() &&
        existing.valueType == valueType &&
        existing.unitValue == unitValue;
  }

  void _addItem(AppState appState) {
    final isValid = _itemFormKey.currentState?.validate() ?? false;
    if (!isValid) return;

    final name = _serviceController.text.trim();
    final value = double.tryParse(_valueController.text.replaceAll(',', '.'));
    final quantity = int.tryParse(_quantityController.text);

    if (name.isEmpty || value == null || quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha serviço, valor e quantidade corretamente.'),
        ),
      );
      return;
    }

    final existingIndex = _items.indexWhere(
      (item) => _sameBusinessItem(
        existing: item,
        name: name,
        valueType: _itemValueType,
        unitValue: value,
      ),
    );

    setState(() {
      if (existingIndex >= 0) {
        final existing = _items[existingIndex];
        _items[existingIndex] = existing.copyWith(
          quantity: existing.quantity + quantity,
        );
      } else {
        final item = appState.createItem(
          name: name,
          valueType: _itemValueType,
          unitValue: value,
          quantity: quantity,
        );
        _items = [..._items, item];
      }

      _serviceController.clear();
      _valueController.clear();
      _quantityController.text = '1';
      _itemValueType = ItemValueType.fixed;
    });

    final message = existingIndex >= 0
        ? 'Quantidade do item atualizada.'
        : 'Item "$name" adicionado.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _editItem(BudgetItem item) async {
    final serviceController = TextEditingController(text: item.name);
    final valueController = TextEditingController(
      text: item.unitValue.toStringAsFixed(2),
    );
    final quantityController = TextEditingController(
      text: item.quantity.toString(),
    );
    var type = item.valueType;

    final updated = await showDialog<BudgetItem>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Editar item'),
        content: StatefulBuilder(
          builder: (context, setLocalState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: serviceController,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de serviço',
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<ItemValueType>(
                  segments: const [
                    ButtonSegment(
                      value: ItemValueType.fixed,
                      label: Text('Valor fixo'),
                    ),
                    ButtonSegment(
                      value: ItemValueType.percentage,
                      label: Text('Percentual'),
                    ),
                  ],
                  selected: {type},
                  onSelectionChanged: (value) =>
                      setLocalState(() => type = value.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: valueController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: type == ItemValueType.fixed
                        ? 'Valor unitário'
                        : 'Percentual (%)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantidade'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final value =
                  double.tryParse(valueController.text.replaceAll(',', '.'));
              final quantity = int.tryParse(quantityController.text);

              if (serviceController.text.trim().isEmpty ||
                  value == null ||
                  quantity == null ||
                  quantity <= 0) {
                return;
              }

              Navigator.pop(
                dialogContext,
                item.copyWith(
                  name: serviceController.text.trim(),
                  valueType: type,
                  unitValue: value,
                  quantity: quantity,
                ),
              );
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    serviceController.dispose();
    valueController.dispose();
    quantityController.dispose();

    if (updated != null) {
      setState(() {
        _items = _items
            .map((element) => element.id == item.id ? updated : element)
            .toList();
      });
    }
  }

  void _removeItem(String id) {
    setState(() {
      _items = _items.where((item) => item.id != id).toList();
    });
  }

  void _clearAll() {
    setState(() {
      _started = false;
      _items = [];
      _discountType = DiscountType.fixed;
      _itemValueType = ItemValueType.fixed;
      _clientController.clear();
      _technicianController.clear();
      _addressController.clear();
      _paymentController.clear();
      _notesController.clear();
      _serviceController.clear();
      _valueController.clear();
      _quantityController.text = '1';
      _discountController.text = '0';
    });
  }

  Future<void> _saveBudget(AppState appState) async {
    if (_clientController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o nome do cliente.')),
      );
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione pelo menos um item.')),
      );
      return;
    }

    final draft = appState.buildDraftBudget(
      clientName: _clientController.text.trim(),
      technician: _technicianController.text.trim(),
      address: _addressController.text.trim(),
      paymentMethod: _paymentController.text.trim(),
      notes: _notesController.text.trim(),
      discountType: _discountType,
      discountValue: _discountValue,
      items: _items,
    );

    final saved = await appState.createBudget(draft);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Orçamento ${saved.number} salvo com sucesso.')),
    );

    _clearAll();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          if (!_started)
            AppSectionCard(
              title: 'Cadastro de orçamento',
              subtitle:
                  'Preencha os dados iniciais e comece um novo orçamento.',
              child: Form(
                key: _clientFormKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _clientController,
                      decoration: const InputDecoration(
                        labelText: 'Nome do cliente',
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'Informe o cliente'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _technicianController,
                      decoration: const InputDecoration(labelText: 'Técnico'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(labelText: 'Endereço'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _paymentController,
                      decoration: const InputDecoration(
                        labelText: 'Forma de pagamento',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesController,
                      minLines: 2,
                      maxLines: 4,
                      decoration:
                          const InputDecoration(labelText: 'Observações'),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _startBudget,
                      child: const Text('Iniciar orçamento'),
                    ),
                  ],
                ),
              ),
            )
          else
            AppSectionCard(
              title: 'Resumo do cliente',
              subtitle:
                  'Os dados continuam acessíveis para edição sem poluir a tela.',
              trailing: TextButton.icon(
                onPressed: () => setState(() => _started = false),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar'),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 220,
                    child: InfoChip(
                      label: 'Cliente',
                      value: _clientController.text.trim(),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: InfoChip(
                      label: 'Técnico',
                      value: _technicianController.text.trim(),
                    ),
                  ),
                  SizedBox(
                    width: 280,
                    child: InfoChip(
                      label: 'Endereço',
                      value: _addressController.text.trim(),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: InfoChip(
                      label: 'Pagamento',
                      value: _paymentController.text.trim(),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          AppSectionCard(
            title: 'Relatório do orçamento',
            subtitle:
                'Adicione itens, gerencie quantidades e acompanhe os totais em tempo real.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Form(
                  key: _itemFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Autocomplete<_ItemSuggestion>(
                        optionsBuilder: (textEditingValue) {
                          return _buildSuggestions(
                            appState,
                            textEditingValue.text,
                          );
                        },
                        displayStringForOption: (option) => option.name,
                        onSelected: _applySuggestion,
                        fieldViewBuilder: (
                          context,
                          textEditingController,
                          focusNode,
                          onFieldSubmitted,
                        ) {
                          if (_serviceController.text !=
                              textEditingController.text) {
                            textEditingController.text =
                                _serviceController.text;
                            textEditingController.selection =
                                TextSelection.fromPosition(
                              TextPosition(
                                offset: textEditingController.text.length,
                              ),
                            );
                          }

                          textEditingController.addListener(() {
                            _serviceController.value =
                                textEditingController.value;
                          });

                          return TextFormField(
                            key: _serviceFieldKey,
                            controller: textEditingController,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: 'Tipo de serviço',
                            ),
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                    ? 'Informe o serviço'
                                    : null,
                          );
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          final list = options.toList();
                          if (list.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4,
                              borderRadius: BorderRadius.circular(12),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 420,
                                  maxHeight: 240,
                                ),
                                child: ListView.separated(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  shrinkWrap: true,
                                  itemCount: list.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final option = list[index];
                                    return ListTile(
                                      dense: true,
                                      title: Text(option.name),
                                      subtitle: Text(
                                        option.valueType == ItemValueType.fixed
                                            ? 'Valor: ${NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(option.unitValue)}'
                                            : 'Percentual: ${option.unitValue.toStringAsFixed(2)}%',
                                      ),
                                      onTap: () => onSelected(option),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: 320,
                            child: SegmentedButton<ItemValueType>(
                              segments: const [
                                ButtonSegment(
                                  value: ItemValueType.fixed,
                                  label: Text('Valor fixo'),
                                ),
                                ButtonSegment(
                                  value: ItemValueType.percentage,
                                  label: Text('Percentual (%)'),
                                ),
                              ],
                              selected: {_itemValueType},
                              onSelectionChanged: (value) => setState(
                                () => _itemValueType = value.first,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 220,
                            child: TextFormField(
                              controller: _valueController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                labelText: _itemValueType == ItemValueType.fixed
                                    ? 'Valor unitário'
                                    : 'Percentual (%)',
                              ),
                              validator: (value) {
                                final parsed = double.tryParse(
                                  (value ?? '').replaceAll(',', '.'),
                                );
                                if (parsed == null || parsed < 0) {
                                  return 'Valor inválido';
                                }
                                return null;
                              },
                            ),
                          ),
                          SizedBox(
                            width: 160,
                            child: TextFormField(
                              controller: _quantityController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Quantidade',
                              ),
                              validator: (value) {
                                final parsed = int.tryParse(value ?? '');
                                if (parsed == null || parsed <= 0) {
                                  return 'Qtd inválida';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _started ? () => _addItem(appState) : null,
                        icon: const Icon(Icons.add),
                        label: const Text('Adicionar item'),
                      ),
                      if (!_started) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'Comece o orçamento antes de adicionar itens.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Itens adicionados (${_items.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(
                    minHeight: 100,
                    maxHeight: 320,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: _items.isEmpty
                      ? const Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            'Nenhum item adicionado ainda.',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                        )
                      : Scrollbar(
                          thumbVisibility: true,
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              final total =
                                  item.totalForFixedBase(_fixedSubtotal);

                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                    width: 1.2,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      item.valueType == ItemValueType.fixed
                                          ? 'Tipo: Valor fixo'
                                          : 'Tipo: Percentual',
                                      style: const TextStyle(
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.valueType == ItemValueType.fixed
                                          ? 'Valor unitário: ${currency.format(item.unitValue)}'
                                          : 'Percentual: ${item.unitValue.toStringAsFixed(2)}%',
                                      style: const TextStyle(
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Quantidade: ${item.quantity}',
                                      style: const TextStyle(
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Subtotal: ${currency.format(total)}',
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 8,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: () => _editItem(item),
                                          icon: const Icon(Icons.edit_outlined),
                                          label: const Text('Editar'),
                                        ),
                                        TextButton.icon(
                                          onPressed: () => _removeItem(item.id),
                                          icon:
                                              const Icon(Icons.delete_outline),
                                          label: const Text('Excluir'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 320,
                      child: SegmentedButton<DiscountType>(
                        segments: const [
                          ButtonSegment(
                            value: DiscountType.fixed,
                            label: Text('Desconto fixo'),
                          ),
                          ButtonSegment(
                            value: DiscountType.percentage,
                            label: Text('Desconto %'),
                          ),
                        ],
                        selected: {_discountType},
                        onSelectionChanged: (value) =>
                            setState(() => _discountType = value.first),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: _discountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration:
                            const InputDecoration(labelText: 'Desconto'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TotalsCard(
                  subtotal: _subtotal,
                  discount: _discountApplied,
                  total: _totalFinal,
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 220,
                      child: ElevatedButton.icon(
                        onPressed:
                            _started ? () => _saveBudget(appState) : null,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Salvar orçamento'),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: OutlinedButton.icon(
                        onPressed: _clearAll,
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Cancelar orçamento'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemSuggestion {
  const _ItemSuggestion({
    required this.name,
    required this.valueType,
    required this.unitValue,
    required this.source,
  });

  final String name;
  final ItemValueType valueType;
  final double unitValue;
  final String source;
}
