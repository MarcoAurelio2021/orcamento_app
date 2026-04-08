import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/budget.dart';
import '../models/budget_item.dart';
import '../models/company_data.dart';
import '../models/service_type.dart';
import '../services/local_storage_service.dart';

class AppState extends ChangeNotifier {
  AppState();

  final LocalStorageService _storage = LocalStorageService();
  final Uuid _uuid = const Uuid();

  List<Budget> _budgets = [];
  List<ServiceType> _services = [];
  CompanyData _company = CompanyData.empty();
  bool _isReady = false;

  List<Budget> get budgets => List.unmodifiable(_budgets);
  List<ServiceType> get services => List.unmodifiable(_services);
  CompanyData get company => _company;
  bool get isReady => _isReady;

  List<String> get itemSuggestions {
    final values = <String>{
      ..._services.map((e) => e.name.trim()).where((e) => e.isNotEmpty),
      ..._budgets
          .expand((budget) => budget.items.map((item) => item.name.trim()))
          .where((e) => e.isNotEmpty),
    };
    final list = values.toList()..sort();
    return list;
  }

  Future<void> initialize() async {
    _budgets = await _storage.loadBudgets();
    _services = await _storage.loadServices();
    _company = await _storage.loadCompany();
    _isReady = true;
    notifyListeners();
  }

  Future<String> generateBudgetNumber() async {
    final next = await _storage.nextBudgetNumber();
    final year = DateTime.now().year;
    return 'ORC-$year-${next.toString().padLeft(4, '0')}';
  }

  Budget buildDraftBudget({
    required String clientName,
    required String technician,
    required String address,
    required String paymentMethod,
    required String notes,
    required DiscountType discountType,
    required double discountValue,
    required List<BudgetItem> items,
    String? id,
    String? number,
    BudgetStatus status = BudgetStatus.draft,
    DateTime? createdAt,
  }) {
    final now = DateTime.now();
    return Budget(
      id: id ?? _uuid.v4(),
      number: number ?? '',
      clientName: clientName,
      technician: technician,
      address: address,
      paymentMethod: paymentMethod,
      notes: notes,
      discountType: discountType,
      discountValue: discountValue,
      items: items,
      status: status,
      createdAt: createdAt ?? now,
      updatedAt: now,
    );
  }

  String _normalizeName(String value) => value.trim().toLowerCase();

  int _findServiceIndexByName(String name) {
    final normalized = _normalizeName(name);
    return _services.indexWhere(
      (service) => _normalizeName(service.name) == normalized,
    );
  }

  Future<void> _upsertServicesFromBudgetItems(List<BudgetItem> items) async {
    var changed = false;
    final now = DateTime.now();

    for (final item in items) {
      final name = item.name.trim();
      if (name.isEmpty) continue;

      final existingIndex = _findServiceIndexByName(name);

      if (existingIndex == -1) {
        final newService = ServiceType(
          id: _uuid.v4(),
          name: name,
          valueType: item.valueType,
          defaultValue: item.unitValue,
          active: true,
          createdAt: now,
        );

        _services = [newService, ..._services];
        changed = true;
      } else {
        final existing = _services[existingIndex];

        final shouldUpdate = existing.valueType != item.valueType ||
            existing.defaultValue != item.unitValue ||
            !existing.active;

        if (shouldUpdate) {
          final updated = existing.copyWith(
            name: name,
            valueType: item.valueType,
            defaultValue: item.unitValue,
            active: true,
          );

          _services[existingIndex] = updated;
          changed = true;
        }
      }
    }

    if (changed) {
      await _storage.saveServices(_services);
    }
  }

  Future<void> _addOnlyMissingServicesFromBudgetItems(
    List<BudgetItem> items,
  ) async {
    var changed = false;
    final now = DateTime.now();

    for (final item in items) {
      final name = item.name.trim();
      if (name.isEmpty) continue;

      final existingIndex = _findServiceIndexByName(name);

      if (existingIndex == -1) {
        final newService = ServiceType(
          id: _uuid.v4(),
          name: name,
          valueType: item.valueType,
          defaultValue: item.unitValue,
          active: true,
          createdAt: now,
        );

        _services = [newService, ..._services];
        changed = true;
      }
    }

    if (changed) {
      await _storage.saveServices(_services);
    }
  }

  Future<Budget> createBudget(Budget draft) async {
    final number =
        draft.number.isEmpty ? await generateBudgetNumber() : draft.number;

    final saved = draft.copyWith(
      number: number,
      status: BudgetStatus.saved,
      updatedAt: DateTime.now(),
    );

    _budgets = [saved, ..._budgets];
    await _storage.saveBudgets(_budgets);

    // Orçamento novo pode criar e também atualizar a base
    await _upsertServicesFromBudgetItems(saved.items);

    notifyListeners();
    return saved;
  }

  Future<void> updateBudget(Budget budget) async {
    final updatedBudget = budget.copyWith(updatedAt: DateTime.now());

    _budgets = _budgets
        .map((item) => item.id == updatedBudget.id ? updatedBudget : item)
        .toList();

    await _storage.saveBudgets(_budgets);

    // Em orçamento já criado:
    // adiciona à base apenas itens novos que ainda não existem
    // mas NÃO atualiza o valor dos serviços já existentes
    await _addOnlyMissingServicesFromBudgetItems(updatedBudget.items);

    notifyListeners();
  }

  Future<void> deleteBudget(String id) async {
    _budgets = _budgets.where((budget) => budget.id != id).toList();
    await _storage.saveBudgets(_budgets);
    notifyListeners();
  }

  Future<void> saveCompany(CompanyData company) async {
    _company = company;
    await _storage.saveCompany(company);
    notifyListeners();
  }

  Future<void> addService(ServiceType service) async {
    final existingIndex = _findServiceIndexByName(service.name);

    if (existingIndex == -1) {
      _services = [service, ..._services];
    } else {
      final existing = _services[existingIndex];
      _services[existingIndex] = existing.copyWith(
        name: service.name,
        valueType: service.valueType,
        defaultValue: service.defaultValue,
        active: service.active,
      );
    }

    await _storage.saveServices(_services);
    notifyListeners();
  }

  Future<void> updateService(ServiceType service) async {
    _services = _services
        .map((item) => item.id == service.id ? service : item)
        .toList();
    await _storage.saveServices(_services);
    notifyListeners();
  }

  Future<void> deleteService(String id) async {
    _services = _services.where((service) => service.id != id).toList();
    await _storage.saveServices(_services);
    notifyListeners();
  }

  BudgetItem createItem({
    required String name,
    required ItemValueType valueType,
    required double unitValue,
    required int quantity,
    String? id,
    String observation = '',
    bool hasWirePass = false,
    WireChargeType wireChargeType = WireChargeType.fixed,
    double wireChargeValue = 0,
  }) {
    return BudgetItem(
      id: id ?? _uuid.v4(),
      name: name,
      valueType: valueType,
      unitValue: unitValue,
      quantity: quantity,
      createdAt: DateTime.now(),
      observation: observation,
      hasWirePass: hasWirePass,
      wireChargeType: wireChargeType,
      wireChargeValue: wireChargeValue,
    );
  }

  ServiceType createService({
    required String name,
    required ItemValueType valueType,
    required double defaultValue,
    String? id,
  }) {
    return ServiceType(
      id: id ?? _uuid.v4(),
      name: name,
      valueType: valueType,
      defaultValue: defaultValue,
      active: true,
      createdAt: DateTime.now(),
    );
  }
}
