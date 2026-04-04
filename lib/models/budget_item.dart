import 'dart:convert';

enum ItemValueType { fixed, percentage }

class BudgetItem {
  BudgetItem({
    required this.id,
    required this.name,
    required this.valueType,
    required this.unitValue,
    required this.quantity,
    required this.createdAt,
  });

  final String id;
  final String name;
  final ItemValueType valueType;
  final double unitValue;
  final int quantity;
  final DateTime createdAt;

  double totalForFixedBase(double fixedBase) {
    if (valueType == ItemValueType.fixed) {
      return unitValue * quantity;
    }
    return fixedBase * (unitValue / 100) * quantity;
  }

  BudgetItem copyWith({
    String? id,
    String? name,
    ItemValueType? valueType,
    double? unitValue,
    int? quantity,
    DateTime? createdAt,
  }) {
    return BudgetItem(
      id: id ?? this.id,
      name: name ?? this.name,
      valueType: valueType ?? this.valueType,
      unitValue: unitValue ?? this.unitValue,
      quantity: quantity ?? this.quantity,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'valueType': valueType.name,
      'unitValue': unitValue,
      'quantity': quantity,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory BudgetItem.fromMap(Map<String, dynamic> map) {
    return BudgetItem(
      id: map['id'] as String,
      name: map['name'] as String,
      valueType: ItemValueType.values.firstWhere(
        (e) => e.name == map['valueType'],
        orElse: () => ItemValueType.fixed,
      ),
      unitValue: (map['unitValue'] as num).toDouble(),
      quantity: (map['quantity'] as num).toInt(),
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory BudgetItem.fromJson(String source) =>
      BudgetItem.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
