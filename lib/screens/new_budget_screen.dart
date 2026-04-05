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
  final _wireChargeController = TextEditingController(text: '0');

  final _clientFormKey = GlobalKey<FormState>();
  final _itemFormKey = GlobalKey<FormState>();
  final _serviceFieldKey = GlobalKey();

  bool _started = false;
  DiscountType _discountType = DiscountType.fixed;
  ItemValueType _itemValueType = ItemValueType.fixed;
  bool _hasWirePass = false;
  WireChargeType _wireChargeType = WireChargeType.fixed;
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
    _wireChargeController.dispose();
    super.dispose();
  }

  double get _discountValue =>
      double.tryParse(_discountController.text.replaceAll(',', '.')) ?? 0;

  double get _wireChargeValue =>
      double.tryParse(_wireChargeController.text.replaceAll(',', '.')) ?? 0;

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
    required bool hasWirePass,
    required WireChargeType wireChargeType,
    required double wireChargeValue,
  }) {
    return existing.name.trim().toLowerCase() == name.trim().toLowerCase() &&
        existing.valueType == valueType &&
        existing.unitValue == unitValue &&
        existing.hasWirePass == hasWirePass &&
        existing.wireChargeType == wireChargeType &&
        existing.wireChargeValue == wireChargeValue;
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
        hasWirePass: _hasWirePass,
        wireChargeType: _wireChargeType,
        wireChargeValue: _wireChargeValue,
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
          hasWirePass: _itemValueType == ItemValueType.fixed && _hasWirePass,
          wireChargeType: _wireChargeType,
          wireChargeValue: _itemValueType == ItemValueType.fixed && _hasWirePass
              ? _wireChargeValue
              : 0,
        );
        _items = [..._items, item];
      }

      _serviceController.clear();
      _valueController.clear();
      _quantityController.text = '1';
      _wireChargeController.text = '0';
      _itemValueType = ItemValueType.fixed;
      _hasWirePass = false;
      _wireChargeType = WireChargeType.fixed;
    });

    final message = existingIndex >= 0
        ? 'Quantidade do item atualizada.'
        : 'Item "$name" adicionado.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _editItem(BudgetItem item) async {
    final updated = await showDialog<BudgetItem>(
      context: context,
      builder: (dialogContext) => _EditBudgetItemDialog(item: item),
    );

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
      _wireChargeController.text = '0';
      _hasWirePass = false;
      _wireChargeType = WireChargeType.fixed;
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

                          return TextFormField(
                            key: _serviceFieldKey,
                            controller: textEditingController,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: 'Tipo de serviço',
                            ),
                            onChanged: (value) {
                              _serviceController.text = value;
                            },
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
                              onSelectionChanged: (value) => setState(() {
                                _itemValueType = value.first;
                                if (_itemValueType != ItemValueType.fixed) {
                                  _hasWirePass = false;
                                  _wireChargeType = WireChargeType.fixed;
                                  _wireChargeController.text = '0';
                                }
                              }),
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
                      if (_itemValueType == ItemValueType.fixed) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: 420,
                          child: SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                value: false,
                                label: Text('Sem passar fio'),
                              ),
                              ButtonSegment(
                                value: true,
                                label: Text('Com passar fio'),
                              ),
                            ],
                            selected: {_hasWirePass},
                            onSelectionChanged: (value) => setState(
                              () => _hasWirePass = value.first,
                            ),
                          ),
                        ),
                      ],
                      if (_itemValueType == ItemValueType.fixed &&
                          _hasWirePass) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: 320,
                              child: SegmentedButton<WireChargeType>(
                                segments: const [
                                  ButtonSegment(
                                    value: WireChargeType.fixed,
                                    label: Text('Preço fixo'),
                                  ),
                                  ButtonSegment(
                                    value: WireChargeType.percentage,
                                    label: Text('Percentual'),
                                  ),
                                ],
                                selected: {_wireChargeType},
                                onSelectionChanged: (value) => setState(
                                  () => _wireChargeType = value.first,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 220,
                              child: TextFormField(
                                controller: _wireChargeController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: InputDecoration(
                                  labelText: _wireChargeType ==
                                          WireChargeType.fixed
                                      ? 'Valor fixo para passar fio'
                                      : 'Percentual para passar fio (%)',
                                ),
                                validator: (value) {
                                  if (!_hasWirePass ||
                                      _itemValueType != ItemValueType.fixed) {
                                    return null;
                                  }

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
                          ],
                        ),
                      ],
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
                                    if (item.valueType == ItemValueType.fixed) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        item.hasWirePass
                                            ? 'Com passar fio'
                                            : 'Sem passar fio',
                                        style: const TextStyle(
                                          color: Colors.black87,
                                        ),
                                      ),
                                      if (item.hasWirePass) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          item.wireChargeType == WireChargeType.fixed
                                              ? 'Passar fio valor fixo: ${currency.format(item.wireChargeValue)}'
                                              : 'Passar fio percentual: ${item.wireChargeValue.toStringAsFixed(2)}%',
                                          style: const TextStyle(
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Valor unitário final: ${currency.format(item.adjustedUnitValue)}',
                                          style: const TextStyle(
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ],
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


class _EditBudgetItemDialog extends StatefulWidget {
  const _EditBudgetItemDialog({required this.item});

  final BudgetItem item;

  @override
  State<_EditBudgetItemDialog> createState() => _EditBudgetItemDialogState();
}

class _EditBudgetItemDialogState extends State<_EditBudgetItemDialog> {
  late final TextEditingController _serviceController;
  late final TextEditingController _valueController;
  late final TextEditingController _quantityController;
  late final TextEditingController _wireChargeController;
  late ItemValueType _type;
  late bool _hasWirePass;
  late WireChargeType _wireChargeType;

  @override
  void initState() {
    super.initState();
    _serviceController = TextEditingController(text: widget.item.name);
    _valueController = TextEditingController(
      text: widget.item.unitValue.toStringAsFixed(2),
    );
    _quantityController = TextEditingController(
      text: widget.item.quantity.toString(),
    );
    _wireChargeController = TextEditingController(
      text: widget.item.wireChargeValue.toStringAsFixed(2),
    );
    _type = widget.item.valueType;
    _hasWirePass = widget.item.hasWirePass;
    _wireChargeType = widget.item.wireChargeType;
  }

  @override
  void dispose() {
    _serviceController.dispose();
    _valueController.dispose();
    _quantityController.dispose();
    _wireChargeController.dispose();
    super.dispose();
  }

  void _submit() {
    final value = double.tryParse(_valueController.text.replaceAll(',', '.'));
    final quantity = int.tryParse(_quantityController.text);

    if (_serviceController.text.trim().isEmpty ||
        value == null ||
        quantity == null ||
        quantity <= 0) {
      return;
    }

    Navigator.of(context).pop(
      widget.item.copyWith(
        name: _serviceController.text.trim(),
        valueType: _type,
        unitValue: value,
        quantity: quantity,
        hasWirePass: _type == ItemValueType.fixed ? _hasWirePass : false,
        wireChargeType: _wireChargeType,
        wireChargeValue: _type == ItemValueType.fixed && _hasWirePass
            ? (double.tryParse(_wireChargeController.text.replaceAll(',', '.')) ?? 0)
            : 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: AlertDialog(
        title: const Text('Editar item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _serviceController,
                decoration: const InputDecoration(labelText: 'Tipo de serviço'),
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
                selected: {_type},
                onSelectionChanged: (value) => setState(() {
                  _type = value.first;
                  if (_type != ItemValueType.fixed) {
                    _hasWirePass = false;
                    _wireChargeType = WireChargeType.fixed;
                    _wireChargeController.text = '0';
                  }
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _valueController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: _type == ItemValueType.fixed
                      ? 'Valor unitário'
                      : 'Percentual (%)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantidade'),
              ),
              if (_type == ItemValueType.fixed) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: 420,
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('Sem passar fio'),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('Com passar fio'),
                      ),
                    ],
                    selected: {_hasWirePass},
                    onSelectionChanged: (value) => setState(
                      () => _hasWirePass = value.first,
                    ),
                  ),
                ),
              ],
              if (_type == ItemValueType.fixed && _hasWirePass) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: 320,
                  child: SegmentedButton<WireChargeType>(
                    segments: const [
                      ButtonSegment(
                        value: WireChargeType.fixed,
                        label: Text('Preço fixo'),
                      ),
                      ButtonSegment(
                        value: WireChargeType.percentage,
                        label: Text('Percentual'),
                      ),
                    ],
                    selected: {_wireChargeType},
                    onSelectionChanged: (value) => setState(
                      () => _wireChargeType = value.first,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _wireChargeController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: _wireChargeType == WireChargeType.fixed
                        ? 'Valor fixo para passar fio'
                        : 'Percentual para passar fio (%)',
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: _submit,
            child: const Text('Salvar'),
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
