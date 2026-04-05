import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app/app_state.dart';
import '../models/budget.dart';
import '../models/budget_item.dart';
import '../models/service_type.dart';
import 'widgets/app_section_card.dart';
import 'widgets/totals_card.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filter = 'Todos';

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
          budget.number.toLowerCase().contains(query) ||
          budget.clientName.toLowerCase().contains(query) ||
          date.format(budget.createdAt).contains(query);

      if (!matchesText) return false;

      final now = DateTime.now();
      if (_filter == 'Hoje') {
        return budget.createdAt.year == now.year &&
            budget.createdAt.month == now.month &&
            budget.createdAt.day == now.day;
      }
      if (_filter == 'Semana') {
        return budget.createdAt.isAfter(now.subtract(const Duration(days: 7)));
      }
      if (_filter == 'Mês') {
        return budget.createdAt.month == now.month &&
            budget.createdAt.year == now.year;
      }
      return true;
    }).toList();

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        children: [
          AppSectionCard(
            title: 'Orçamentos criados',
            subtitle:
                'Pesquise por número, cliente ou data e role a lista sem perder o campo de busca.',
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Pesquisar por número, cliente ou data',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Wrap(
                    spacing: 8,
                    children: ['Todos', 'Hoje', 'Semana', 'Mês']
                        .map(
                          (label) => ChoiceChip(
                            label: Text(label),
                            selected: _filter == label,
                            onSelected: (_) => setState(() => _filter = label),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: budgets.isEmpty
                ? const Center(child: Text('Nenhum orçamento encontrado.'))
                : ListView.separated(
                    itemCount: budgets.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final budget = budgets[index];
                      return InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _openBudgetDetails(context, budget),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
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
                                      Text(budget.clientName),
                                      const SizedBox(height: 4),
                                      Text(
                                        date.format(budget.createdAt),
                                        style: const TextStyle(
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      currency.format(budget.totalFinal),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    IconButton(
                                      onPressed: () =>
                                          _confirmDelete(context, budget.id),
                                      icon: const Icon(Icons.delete_outline),
                                      tooltip: 'Excluir',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String id) async {
    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir orçamento'),
        content: const Text(
          'Tem certeza que deseja excluir este orçamento?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await appState.deleteBudget(id);

      if (!mounted) return;

      messenger.showSnackBar(
        const SnackBar(content: Text('Orçamento excluído.')),
      );
    }
  }

  Future<void> _openBudgetDetails(BuildContext context, Budget budget) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BudgetDetailsScreen(initialBudget: budget),
      ),
    );
  }
}

class BudgetDetailsScreen extends StatefulWidget {
  const BudgetDetailsScreen({super.key, required this.initialBudget});

  final Budget initialBudget;

  @override
  State<BudgetDetailsScreen> createState() => _BudgetDetailsScreenState();
}

class _BudgetDetailsScreenState extends State<BudgetDetailsScreen> {
  late final TextEditingController _clientController;
  late final TextEditingController _technicianController;
  late final TextEditingController _addressController;
  late final TextEditingController _paymentController;
  late final TextEditingController _notesController;
  late final TextEditingController _discountController;

  late DiscountType _discountType;
  late List<BudgetItem> _items;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    final budget = widget.initialBudget;
    _clientController = TextEditingController(text: budget.clientName);
    _technicianController = TextEditingController(text: budget.technician);
    _addressController = TextEditingController(text: budget.address);
    _paymentController = TextEditingController(text: budget.paymentMethod);
    _notesController = TextEditingController(text: budget.notes);
    _discountController = TextEditingController(
      text: budget.discountValue.toStringAsFixed(2),
    );
    _discountType = budget.discountType;
    _items = budget.items.map((e) => e.copyWith()).toList();
  }

  @override
  void dispose() {
    _clientController.dispose();
    _technicianController.dispose();
    _addressController.dispose();
    _paymentController.dispose();
    _notesController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  double get _discountValue =>
      double.tryParse(_discountController.text.replaceAll(',', '.')) ?? 0;

  Budget _currentBudget() {
    return widget.initialBudget.copyWith(
      clientName: _clientController.text.trim(),
      technician: _technicianController.text.trim(),
      address: _addressController.text.trim(),
      paymentMethod: _paymentController.text.trim(),
      notes: _notesController.text.trim(),
      discountType: _discountType,
      discountValue: _discountValue,
      items: _items,
    );
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

  Future<void> _editItem(BudgetItem item) async {
    final result = await showDialog<_EditBudgetItemResult>(
      context: context,
      builder: (dialogContext) => EditBudgetItemDialog(item: item),
    );

    if (result == null) return;

    setState(() {
      _items = _items.map((element) {
        if (element.id != item.id) return element;

        return element.copyWith(
          name: result.name,
          valueType: result.valueType,
          unitValue: result.unitValue,
          quantity: result.quantity,
        );
      }).toList();
    });
  }

  Future<void> _addNewItem() async {
    final appState = context.read<AppState>();

    final result = await showDialog<_AddBudgetItemResult>(
      context: context,
      builder: (dialogContext) => AddBudgetItemDialog(
        services: appState.services,
      ),
    );

    if (result == null) return;

    setState(() {
      final existingIndex = _items.indexWhere(
        (item) => _sameBusinessItem(
          existing: item,
          name: result.name,
          valueType: result.valueType,
          unitValue: result.unitValue,
        ),
      );

      if (existingIndex >= 0) {
        final existing = _items[existingIndex];
        _items[existingIndex] = existing.copyWith(
          quantity: existing.quantity + result.quantity,
        );
      } else {
        _items = [
          ..._items,
          appState.createItem(
            name: result.name,
            valueType: result.valueType,
            unitValue: result.unitValue,
            quantity: result.quantity,
          ),
        ];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final budget = _currentBudget();
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final date = DateFormat('dd/MM/yyyy HH:mm');

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(title: Text(budget.number)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppSectionCard(
              title: 'Dados do orçamento',
              subtitle:
                  'Visualize ou edite as informações do cliente e do orçamento.',
              trailing: TextButton.icon(
                onPressed: () => setState(() => _isEditing = !_isEditing),
                icon: Icon(
                  _isEditing ? Icons.visibility_outlined : Icons.edit_outlined,
                ),
                label: Text(_isEditing ? 'Modo visualização' : 'Editar'),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _clientController,
                    enabled: _isEditing,
                    decoration: const InputDecoration(
                      labelText: 'Nome do cliente',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _technicianController,
                    enabled: _isEditing,
                    decoration: const InputDecoration(labelText: 'Técnico'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _addressController,
                    enabled: _isEditing,
                    decoration: const InputDecoration(labelText: 'Endereço'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _paymentController,
                    enabled: _isEditing,
                    decoration: const InputDecoration(
                      labelText: 'Forma de pagamento',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    enabled: _isEditing,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Observações'),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 300,
                        child: SegmentedButton<DiscountType>(
                          segments: const [
                            ButtonSegment(
                              value: DiscountType.fixed,
                              label: Text('Valor fixo'),
                            ),
                            ButtonSegment(
                              value: DiscountType.percentage,
                              label: Text('Percentual (%)'),
                            ),
                          ],
                          selected: {_discountType},
                          onSelectionChanged: _isEditing
                              ? (value) =>
                                  setState(() => _discountType = value.first)
                              : null,
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: TextField(
                          controller: _discountController,
                          enabled: _isEditing,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Desconto',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Criado em ${date.format(widget.initialBudget.createdAt)}',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppSectionCard(
              title: 'Itens do orçamento',
              subtitle:
                  'Edite quantidade, valor unitário e remova itens já existentes.',
              trailing: _isEditing
                  ? TextButton.icon(
                      onPressed: _addNewItem,
                      icon: const Icon(Icons.add),
                      label: const Text('Adicionar item'),
                    )
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(
                      minHeight: 120,
                      maxHeight: 360,
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
                            child: Text('Nenhum item neste orçamento.'),
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
                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            currency.format(
                                              item.totalForFixedBase(
                                                budget.fixedSubtotal,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        item.valueType == ItemValueType.fixed
                                            ? 'Qtd ${item.quantity} • ${currency.format(item.unitValue)}'
                                            : 'Qtd ${item.quantity} • ${item.unitValue.toStringAsFixed(2)}%',
                                      ),
                                      if (_isEditing) ...[
                                        const SizedBox(height: 12),
                                        Wrap(
                                          spacing: 12,
                                          children: [
                                            OutlinedButton.icon(
                                              onPressed: () => _editItem(item),
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                              ),
                                              label: const Text('Editar item'),
                                            ),
                                            TextButton.icon(
                                              onPressed: () => setState(
                                                () => _items.removeWhere(
                                                  (element) =>
                                                      element.id == item.id,
                                                ),
                                              ),
                                              icon: const Icon(
                                                Icons.delete_outline,
                                              ),
                                              label: const Text('Excluir'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  TotalsCard(
                    subtotal: budget.subtotal,
                    discount: budget.discountApplied,
                    total: budget.totalFinal,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 220,
                  child: ElevatedButton.icon(
                    onPressed: _isEditing
                        ? () async {
                            final messenger = ScaffoldMessenger.of(context);

                            await context.read<AppState>().updateBudget(budget);

                            if (!mounted) return;

                            setState(() => _isEditing = false);

                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Edição salva com sucesso.'),
                              ),
                            );
                          }
                        : null,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Salvar edição'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: OutlinedButton.icon(
                    onPressed:
                        _isEditing ? () => Navigator.of(context).pop() : null,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancelar edição'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextButton.icon(
                    onPressed: () async {
                      await context
                          .read<AppState>()
                          .deleteBudget(widget.initialBudget.id);

                      if (!mounted) return;

                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Excluir'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AddBudgetItemDialog extends StatefulWidget {
  const AddBudgetItemDialog({
    super.key,
    required this.services,
  });

  final List<ServiceType> services;

  @override
  State<AddBudgetItemDialog> createState() => _AddBudgetItemDialogState();
}

class _AddBudgetItemDialogState extends State<AddBudgetItemDialog> {
  final TextEditingController _serviceController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();
  final TextEditingController _quantityController =
      TextEditingController(text: '1');

  ItemValueType _type = ItemValueType.fixed;

  List<ServiceType> _filteredServices(String query) {
    final normalized = query.trim().toLowerCase();

    if (normalized.isEmpty) {
      return widget.services.take(12).toList();
    }

    return widget.services
        .where((service) => service.name.toLowerCase().contains(normalized))
        .take(12)
        .toList();
  }

  void _applySuggestion(ServiceType service) {
    setState(() {
      _serviceController.text = service.name;
      _type = service.valueType;
      _valueController.text = service.defaultValue.toStringAsFixed(2);
    });
  }

  void _submit() {
    final name = _serviceController.text.trim();
    final value = double.tryParse(_valueController.text.replaceAll(',', '.'));
    final quantity = int.tryParse(_quantityController.text);

    if (name.isEmpty || value == null || quantity == null || quantity <= 0) {
      return;
    }

    Navigator.of(context).pop(
      _AddBudgetItemResult(
        name: name,
        valueType: _type,
        unitValue: value,
        quantity: quantity,
      ),
    );
  }

  @override
  void dispose() {
    _serviceController.dispose();
    _valueController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Adicionar item',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Autocomplete<ServiceType>(
                    optionsBuilder: (textEditingValue) {
                      return _filteredServices(textEditingValue.text);
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
                        textEditingController.text = _serviceController.text;
                        textEditingController.selection =
                            TextSelection.fromPosition(
                          TextPosition(
                            offset: textEditingController.text.length,
                          ),
                        );
                      }

                      textEditingController.addListener(() {
                        _serviceController.value = textEditingController.value;
                      });

                      return TextField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Serviço',
                        ),
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
                              padding: const EdgeInsets.symmetric(vertical: 8),
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
                                        ? 'Valor: ${NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(option.defaultValue)}'
                                        : 'Percentual: ${option.defaultValue.toStringAsFixed(2)}%',
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
                    onSelectionChanged: (value) =>
                        setState(() => _type = value.first),
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
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quantidade'),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _submit,
                        child: const Text('Adicionar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class EditBudgetItemDialog extends StatefulWidget {
  const EditBudgetItemDialog({
    super.key,
    required this.item,
  });

  final BudgetItem item;

  @override
  State<EditBudgetItemDialog> createState() => _EditBudgetItemDialogState();
}

class _EditBudgetItemDialogState extends State<EditBudgetItemDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _valueController;
  late final TextEditingController _quantityController;
  late ItemValueType _type;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    _valueController = TextEditingController(
      text: widget.item.unitValue.toStringAsFixed(2),
    );
    _quantityController = TextEditingController(
      text: widget.item.quantity.toString(),
    );
    _type = widget.item.valueType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final value = double.tryParse(_valueController.text.replaceAll(',', '.'));
    final quantity = int.tryParse(_quantityController.text);

    if (name.isEmpty || value == null || quantity == null || quantity <= 0) {
      return;
    }

    Navigator.of(context).pop(
      _EditBudgetItemResult(
        name: name,
        valueType: _type,
        unitValue: value,
        quantity: quantity,
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
                controller: _nameController,
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
                selected: {_type},
                onSelectionChanged: (value) =>
                    setState(() => _type = value.first),
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
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantidade'),
              ),
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

class _AddBudgetItemResult {
  const _AddBudgetItemResult({
    required this.name,
    required this.valueType,
    required this.unitValue,
    required this.quantity,
  });

  final String name;
  final ItemValueType valueType;
  final double unitValue;
  final int quantity;
}

class _EditBudgetItemResult {
  const _EditBudgetItemResult({
    required this.name,
    required this.valueType,
    required this.unitValue,
    required this.quantity,
  });

  final String name;
  final ItemValueType valueType;
  final double unitValue;
  final int quantity;
}
