import 'dart:convert';

import 'budget_item.dart';

enum BudgetStatus { draft, saved, canceled }

enum DiscountType { fixed, percentage }

class Budget {
  Budget({
    required this.id,
    required this.number,
    required this.clientName,
    required this.technician,
    required this.address,
    required this.paymentMethod,
    required this.notes,
    required this.discountType,
    required this.discountValue,
    required this.items,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String number;
  final String clientName;
  final String technician;
  final String address;
  final String paymentMethod;
  final String notes;
  final DiscountType discountType;
  final double discountValue;
  final List<BudgetItem> items;
  final BudgetStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get fixedSubtotal => items
      .where((item) => item.valueType == ItemValueType.fixed)
      .fold<double>(0, (sum, item) => sum + item.totalForFixedBase(0));

  double get percentageSubtotal => items
      .where((item) => item.valueType == ItemValueType.percentage)
      .fold<double>(0, (sum, item) => sum + item.totalForFixedBase(fixedSubtotal));

  double get subtotal => fixedSubtotal + percentageSubtotal;

  double get discountApplied {
    if (discountValue <= 0) return 0;
    if (discountType == DiscountType.fixed) {
      return discountValue.clamp(0, subtotal);
    }
    return (subtotal * (discountValue / 100)).clamp(0, subtotal);
  }

  double get totalFinal => (subtotal - discountApplied).clamp(0, double.infinity);

  Budget copyWith({
    String? id,
    String? number,
    String? clientName,
    String? technician,
    String? address,
    String? paymentMethod,
    String? notes,
    DiscountType? discountType,
    double? discountValue,
    List<BudgetItem>? items,
    BudgetStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Budget(
      id: id ?? this.id,
      number: number ?? this.number,
      clientName: clientName ?? this.clientName,
      technician: technician ?? this.technician,
      address: address ?? this.address,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      items: items ?? this.items,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'number': number,
      'clientName': clientName,
      'technician': technician,
      'address': address,
      'paymentMethod': paymentMethod,
      'notes': notes,
      'discountType': discountType.name,
      'discountValue': discountValue,
      'items': items.map((x) => x.toMap()).toList(),
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'] as String,
      number: map['number'] as String,
      clientName: map['clientName'] as String? ?? '',
      technician: map['technician'] as String? ?? '',
      address: map['address'] as String? ?? '',
      paymentMethod: map['paymentMethod'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      discountType: DiscountType.values.firstWhere(
        (e) => e.name == map['discountType'],
        orElse: () => DiscountType.fixed,
      ),
      discountValue: (map['discountValue'] as num?)?.toDouble() ?? 0,
      items: List<BudgetItem>.from(
        (map['items'] as List<dynamic>? ?? []).map(
          (x) => BudgetItem.fromMap(x as Map<String, dynamic>),
        ),
      ),
      status: BudgetStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => BudgetStatus.saved,
      ),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory Budget.fromJson(String source) => Budget.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
