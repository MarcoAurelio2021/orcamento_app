import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/budget.dart';
import '../models/company_data.dart';
import '../models/service_type.dart';

class LocalStorageService {
  static const _budgetsKey = 'budgets';
  static const _servicesKey = 'services';
  static const _companyKey = 'company';
  static const _budgetCounterKey = 'budget_counter';

  Future<List<Budget>> loadBudgets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_budgetsKey) ?? [];
    return raw.map(Budget.fromJson).toList();
  }

  Future<void> saveBudgets(List<Budget> budgets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_budgetsKey, budgets.map((e) => e.toJson()).toList());
  }

  Future<List<ServiceType>> loadServices() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_servicesKey) ?? [];
    return raw.map(ServiceType.fromJson).toList();
  }

  Future<void> saveServices(List<ServiceType> services) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_servicesKey, services.map((e) => e.toJson()).toList());
  }

  Future<CompanyData> loadCompany() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_companyKey);
    if (raw == null || raw.isEmpty) return CompanyData.empty();
    return CompanyData.fromJson(raw);
  }

  Future<void> saveCompany(CompanyData company) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_companyKey, jsonEncode(company.toMap()));
  }

  Future<int> nextBudgetNumber() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_budgetCounterKey) ?? 0;
    final next = current + 1;
    await prefs.setInt(_budgetCounterKey, next);
    return next;
  }
}
