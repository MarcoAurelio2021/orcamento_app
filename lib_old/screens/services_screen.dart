import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app/app_state.dart';
import '../models/budget_item.dart';
import '../models/service_type.dart';
import 'widgets/app_section_card.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final _nameController = TextEditingController();
  final _valueController = TextEditingController();
  final _searchController = TextEditingController();

  ItemValueType _valueType = ItemValueType.fixed;

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _clearForm() {
    setState(() {
      _nameController.clear();
      _valueController.clear();
      _valueType = ItemValueType.fixed;
    });
  }

  Future<void> _createOrUpdateService(AppState appState) async {
    final messenger = ScaffoldMessenger.of(context);

    final name = _nameController.text.trim();
    final value = double.tryParse(_valueController.text.replaceAll(',', '.'));

    if (name.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Informe o tipo de serviço.')),
      );
      return;
    }

    if (value == null || value < 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Informe um valor válido.')),
      );
      return;
    }

    final existing = appState.services.where(
      (service) => service.name.trim().toLowerCase() == name.toLowerCase(),
    );

    if (existing.isNotEmpty) {
      final service = existing.first.copyWith(
        name: name,
        valueType: _valueType,
        defaultValue: value,
        active: true,
      );

      await appState.updateService(service);

      if (!mounted) return;

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Serviço já existia e foi atualizado.'),
        ),
      );
    } else {
      final service = appState.createService(
        name: name,
        valueType: _valueType,
        defaultValue: value,
      );

      await appState.addService(service);

      if (!mounted) return;

      messenger.showSnackBar(
        const SnackBar(content: Text('Serviço criado com sucesso.')),
      );
    }

    _clearForm();
  }

  Future<void> _editService(AppState appState, ServiceType service) async {
    final messenger = ScaffoldMessenger.of(context);

    final result = await showDialog<_EditServiceResult>(
      context: context,
      builder: (dialogContext) => EditServiceDialog(service: service),
    );

    if (result == null) return;

    final updated = service.copyWith(
      name: result.name,
      valueType: result.valueType,
      defaultValue: result.defaultValue,
      active: true,
    );

    await appState.updateService(updated);

    if (!mounted) return;

    messenger.showSnackBar(
      const SnackBar(content: Text('Serviço atualizado com sucesso.')),
    );
  }

  Future<void> _deleteService(AppState appState, ServiceType service) async {
    final messenger = ScaffoldMessenger.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir serviço'),
        content: Text('Deseja excluir "${service.name}"?'),
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
      await appState.deleteService(service.id);

      if (!mounted) return;

      messenger.showSnackBar(
        const SnackBar(content: Text('Serviço excluído.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    final query = _searchController.text.trim().toLowerCase();

    final services = appState.services.where((service) {
      if (query.isEmpty) return true;
      return service.name.toLowerCase().contains(query);
    }).toList();

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          AppSectionCard(
            title: 'Gerenciar tipos de serviço',
            subtitle: 'Crie serviços base para reutilizar em novos orçamentos.',
            child: Column(
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
                      label: Text('Percentual (%)'),
                    ),
                  ],
                  selected: {_valueType},
                  onSelectionChanged: (value) =>
                      setState(() => _valueType = value.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _valueController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: _valueType == ItemValueType.fixed
                        ? 'Valor'
                        : 'Percentual (%)',
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
                        onPressed: () => _createOrUpdateService(appState),
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Criar serviço'),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: OutlinedButton.icon(
                        onPressed: _clearForm,
                        icon: const Icon(Icons.cleaning_services_outlined),
                        label: const Text('Limpar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppSectionCard(
            title: 'Lista de serviços',
            subtitle:
                'Pesquise, edite ou exclua serviços sem afetar orçamentos antigos.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Pesquisar tipo de serviço',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(
                    minHeight: 120,
                    maxHeight: 420,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: services.isEmpty
                      ? const Align(
                          alignment: Alignment.topLeft,
                          child: Text('Nenhum serviço cadastrado.'),
                        )
                      : Scrollbar(
                          thumbVisibility: true,
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: services.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final service = services[index];

                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      service.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      service.valueType == ItemValueType.fixed
                                          ? 'Tipo: Valor fixo'
                                          : 'Tipo: Percentual',
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      service.valueType == ItemValueType.fixed
                                          ? 'Valor padrão: ${currency.format(service.defaultValue)}'
                                          : 'Percentual padrão: ${service.defaultValue.toStringAsFixed(2)}%',
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 8,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: () =>
                                              _editService(appState, service),
                                          icon: const Icon(Icons.edit_outlined),
                                          label: const Text('Editar'),
                                        ),
                                        TextButton.icon(
                                          onPressed: () =>
                                              _deleteService(appState, service),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EditServiceDialog extends StatefulWidget {
  const EditServiceDialog({
    super.key,
    required this.service,
  });

  final ServiceType service;

  @override
  State<EditServiceDialog> createState() => _EditServiceDialogState();
}

class _EditServiceDialogState extends State<EditServiceDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _valueController;
  late ItemValueType _valueType;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.service.name);
    _valueController = TextEditingController(
      text: widget.service.defaultValue.toStringAsFixed(2),
    );
    _valueType = widget.service.valueType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final value = double.tryParse(_valueController.text.replaceAll(',', '.'));

    if (name.isEmpty || value == null || value < 0) {
      return;
    }

    Navigator.of(context).pop(
      _EditServiceResult(
        name: name,
        valueType: _valueType,
        defaultValue: value,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: AlertDialog(
        title: const Text('Editar tipo de serviço'),
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
                    label: Text('Percentual (%)'),
                  ),
                ],
                selected: {_valueType},
                onSelectionChanged: (value) =>
                    setState(() => _valueType = value.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _valueController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: _valueType == ItemValueType.fixed
                      ? 'Valor'
                      : 'Percentual (%)',
                ),
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

class _EditServiceResult {
  const _EditServiceResult({
    required this.name,
    required this.valueType,
    required this.defaultValue,
  });

  final String name;
  final ItemValueType valueType;
  final double defaultValue;
}
