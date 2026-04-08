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
  final _itemObservationController = TextEditingController();
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
    _itemObservationController.dispose();
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
    required String observation,
    required bool hasWirePass,
    required WireChargeType wireChargeType,
    required double wireChargeValue,
  }) {
    return existing.name.trim().toLowerCase() == name.trim().toLowerCase() &&
        existing.valueType == valueType &&
        existing.unitValue == unitValue &&
        existing.observation.trim() == observation.trim() &&
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
        observation: _itemObservationController.text.trim(),
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
          observation: _itemObservationController.text.trim(),
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
      _itemObservationController.clear();
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
    final theme = Theme.of(context);
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
                  'Preencha os dados iniciais para começar um novo atendimento.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF1E2A78),
                          Color(0xFF5F8DBB),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Inicie com os dados do cliente',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Depois você adiciona os serviços e acompanha os totais em tempo real.',
                          style: TextStyle(
                            color: Colors.white70,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Form(
                    key: _clientFormKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _clientController,
                          decoration: const InputDecoration(
                            labelText: 'Nome do cliente',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                                  ? 'Informe o cliente'
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _technicianController,
                          decoration: const InputDecoration(
                            labelText: 'Técnico responsável',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _addressController,
                          decoration: const InputDecoration(
                            labelText: 'Endereço',
                            prefixIcon: Icon(Icons.location_on_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _paymentController,
                          decoration: const InputDecoration(
                            labelText: 'Forma de pagamento',
                            prefixIcon: Icon(Icons.payments_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _notesController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Observações',
                            alignLabelWithHint: true,
                            prefixIcon: Icon(Icons.sticky_note_2_outlined),
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _startBudget,
                            icon: const Icon(Icons.flash_on_rounded),
                            label: const Text('Iniciar orçamento'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            AppSectionCard(
              title: 'Resumo do cliente',
              subtitle:
                  'Os dados principais continuam visíveis e fáceis de editar.',
              trailing: TextButton.icon(
                onPressed: () => setState(() => _started = false),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar'),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
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
                  if (_notesController.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFD),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFD8E0EF)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.notes_rounded,
                            color: Color(0xFF1E2A78),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _notesController.text.trim(),
                              style: const TextStyle(
                                color: Color(0xFF334155),
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 16),
          AppSectionCard(
            title: 'Itens e totais do orçamento',
            subtitle:
                'Adicione serviços, ajuste quantidades e acompanhe o fechamento.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _SummaryStatCard(
                      icon: Icons.inventory_2_outlined,
                      title: 'Itens',
                      value: '${_items.length}',
                    ),
                    _SummaryStatCard(
                      icon: Icons.receipt_long_outlined,
                      title: 'Subtotal',
                      value: currency.format(_subtotal),
                    ),
                    _SummaryStatCard(
                      icon: Icons.discount_outlined,
                      title: 'Desconto',
                      value: currency.format(_discountApplied),
                    ),
                    _SummaryStatCard(
                      icon: Icons.paid_outlined,
                      title: 'Total final',
                      value: currency.format(_totalFinal),
                      highlighted: true,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFD),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFD8E0EF)),
                  ),
                  child: Form(
                    key: _itemFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Adicionar item',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E2A78),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Use sugestões de serviços salvos e monte o orçamento com mais rapidez.',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 14),
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
                                prefixIcon: Icon(Icons.build_circle_outlined),
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
                                elevation: 10,
                                borderRadius: BorderRadius.circular(18),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 460,
                                    maxHeight: 260,
                                  ),
                                  child: ListView.separated(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    shrinkWrap: true,
                                    itemCount: list.length,
                                    separatorBuilder: (_, __) =>
                                        const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      final option = list[index];
                                      return ListTile(
                                        dense: true,
                                        leading: Container(
                                          height: 38,
                                          width: 38,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE8EEFF),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                            Icons.flash_on_rounded,
                                            color: Color(0xFF1E2A78),
                                            size: 20,
                                          ),
                                        ),
                                        title: Text(option.name),
                                        subtitle: Text(
                                          option.valueType ==
                                                  ItemValueType.fixed
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
                                  labelText:
                                      _itemValueType == ItemValueType.fixed
                                          ? 'Valor unitário'
                                          : 'Percentual (%)',
                                  prefixIcon: const Icon(Icons.sell_outlined),
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
                                  prefixIcon: Icon(Icons.numbers_rounded),
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
                                    labelText:
                                        _wireChargeType == WireChargeType.fixed
                                            ? 'Valor do passar fio'
                                            : 'Percentual do passar fio (%)',
                                    prefixIcon:
                                        const Icon(Icons.electrical_services),
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
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed:
                                _started ? () => _addItem(appState) : null,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Adicionar item'),
                          ),
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
                ),
                const SizedBox(height: 20),
                Text(
                  'Itens adicionados (${_items.length})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 12),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: double.infinity,
                  constraints: const BoxConstraints(
                    minHeight: 120,
                    maxHeight: 420,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFD),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFD8E0EF)),
                  ),
                  child: _items.isEmpty
                      ? const _EmptyItemsState()
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

                              return _BudgetItemCard(
                                item: item,
                                total: total,
                                currency: currency,
                                onEdit: () => _editItem(item),
                                onRemove: () => _removeItem(item.id),
                              );
                            },
                          ),
                        ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFD),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFD8E0EF)),
                  ),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
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
                          decoration: const InputDecoration(
                            labelText: 'Desconto',
                            prefixIcon: Icon(Icons.local_offer_outlined),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
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
                      width: 240,
                      child: ElevatedButton.icon(
                        onPressed:
                            _started ? () => _saveBudget(appState) : null,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Salvar orçamento'),
                      ),
                    ),
                    SizedBox(
                      width: 240,
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

class _SummaryStatCard extends StatelessWidget {
  const _SummaryStatCard({
    required this.icon,
    required this.title,
    required this.value,
    this.highlighted = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: highlighted
            ? const LinearGradient(
                colors: [
                  Color(0xFF1E2A78),
                  Color(0xFF5F8DBB),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: highlighted ? null : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: highlighted ? null : Border.all(color: const Color(0xFFD8E0EF)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 14,
            offset: Offset(0, 8),
            color: Color(0x12000000),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: highlighted
                  ? Colors.white.withOpacity(0.18)
                  : const Color(0xFFE8EEFF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: highlighted ? Colors.white : const Color(0xFF1E2A78),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color:
                        highlighted ? Colors.white70 : const Color(0xFF64748B),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: highlighted ? Colors.white : const Color(0xFF111827),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyItemsState extends StatelessWidget {
  const _EmptyItemsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 64,
              width: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFE8EEFF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                color: Color(0xFF1E2A78),
                size: 30,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Nenhum item adicionado ainda',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Adicione um serviço acima para começar a montar o orçamento.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF64748B),
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetItemCard extends StatelessWidget {
  const _BudgetItemCard({
    required this.item,
    required this.total,
    required this.currency,
    required this.onEdit,
    required this.onRemove,
  });

  final BudgetItem item;
  final double total;
  final NumberFormat currency;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tags = <String>[
      item.valueType == ItemValueType.fixed ? 'Valor fixo' : 'Percentual',
      'Qtd: ${item.quantity}',
      if (item.valueType == ItemValueType.fixed)
        item.hasWirePass ? 'Com passar fio' : 'Sem passar fio',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8E0EF)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 12,
            offset: Offset(0, 8),
            color: Color(0x0D000000),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 12,
            spacing: 12,
            children: [
              SizedBox(
                width: 420,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8EEFF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.flash_on_rounded,
                        color: Color(0xFF1E2A78),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          item.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  currency.format(total),
                  style: const TextStyle(
                    color: Color(0xFF1E2A78),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags
                .map(
                  (tag) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFD),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFD8E0EF)),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              Text(
                item.valueType == ItemValueType.fixed
                    ? 'Valor unitário: ${currency.format(item.unitValue)}'
                    : 'Percentual: ${item.unitValue.toStringAsFixed(2)}%',
                style: const TextStyle(
                  color: Color(0xFF334155),
                  height: 1.35,
                ),
              ),
              if (item.valueType == ItemValueType.fixed && item.hasWirePass)
                Text(
                  item.wireChargeType == WireChargeType.fixed
                      ? 'Passar fio: ${currency.format(item.wireChargeValue)}'
                      : 'Passar fio: ${item.wireChargeValue.toStringAsFixed(2)}%',
                  style: const TextStyle(
                    color: Color(0xFF334155),
                    height: 1.35,
                  ),
                ),
              if (item.valueType == ItemValueType.fixed && item.hasWirePass)
                Text(
                  'Valor final unitário: ${currency.format(item.adjustedUnitValue)}',
                  style: const TextStyle(
                    color: Color(0xFF334155),
                    height: 1.35,
                  ),
                ),
            ],
          ),
          if (item.observation.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Observação: ${item.observation}',
              style: const TextStyle(
                color: Color(0xFF334155),
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar'),
              ),
              TextButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Excluir'),
              ),
            ],
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
  late final TextEditingController _observationController;
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
    _observationController = TextEditingController(
      text: widget.item.observation,
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
    _observationController.dispose();
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
        observation: _observationController.text.trim(),
        hasWirePass: _type == ItemValueType.fixed ? _hasWirePass : false,
        wireChargeType: _wireChargeType,
        wireChargeValue: _type == ItemValueType.fixed && _hasWirePass
            ? (double.tryParse(
                    _wireChargeController.text.replaceAll(',', '.')) ??
                0)
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Text('Editar item'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _serviceController,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de serviço',
                    prefixIcon: Icon(Icons.build_circle_outlined),
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
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: _type == ItemValueType.fixed
                        ? 'Valor unitário'
                        : 'Percentual (%)',
                    prefixIcon: const Icon(Icons.sell_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantidade',
                    prefixIcon: Icon(Icons.numbers_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _observationController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Observação',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
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
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: _wireChargeType == WireChargeType.fixed
                          ? 'Valor do passar fio'
                          : 'Percentual do passar fio (%)',
                      prefixIcon: const Icon(Icons.electrical_services),
                    ),
                  ),
                ],
              ],
            ),
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
