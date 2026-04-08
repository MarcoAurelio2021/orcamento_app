import 'dart:convert';

enum ItemValueType { fixed, percentage }

enum WireChargeType { fixed, percentage }

class BudgetItem {
  BudgetItem({
    required this.id,
    required this.name,
    required this.valueType,
    required this.unitValue,
    required this.quantity,
    required this.createdAt,
    this.observation = '',
    this.hasWirePass = false,
    this.wireChargeType = WireChargeType.fixed,
    this.wireChargeValue = 0,
  });

  final String id;
  final String name;
  final ItemValueType valueType;
  final double unitValue;
  final int quantity;
  final DateTime createdAt;
  final String observation;
  final bool hasWirePass;
  final WireChargeType wireChargeType;
  final double wireChargeValue;

  double get adjustedUnitValue {
    if (!hasWirePass || valueType != ItemValueType.fixed) {
      return unitValue;
    }

    if (wireChargeType == WireChargeType.fixed) {
      return unitValue + wireChargeValue;
    }

    final percentageValue = (unitValue * (wireChargeValue / 100));
    return unitValue + percentageValue;
  }

  double get wireChargeAppliedPerUnit {
    if (!hasWirePass || valueType != ItemValueType.fixed) {
      return 0;
    }

    if (wireChargeType == WireChargeType.fixed) {
      return wireChargeValue;
    }

    return unitValue * (wireChargeValue / 100);
  }

  double totalForFixedBase(double fixedBase) {
    if (valueType == ItemValueType.fixed) {
      return adjustedUnitValue * quantity;
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
    String? observation,
    bool? hasWirePass,
    WireChargeType? wireChargeType,
    double? wireChargeValue,
  }) {
    return BudgetItem(
      id: id ?? this.id,
      name: name ?? this.name,
      valueType: valueType ?? this.valueType,
      unitValue: unitValue ?? this.unitValue,
      quantity: quantity ?? this.quantity,
      createdAt: createdAt ?? this.createdAt,
      observation: observation ?? this.observation,
      hasWirePass: hasWirePass ?? this.hasWirePass,
      wireChargeType: wireChargeType ?? this.wireChargeType,
      wireChargeValue: wireChargeValue ?? this.wireChargeValue,
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
      'observation': observation,
      'hasWirePass': hasWirePass,
      'wireChargeType': wireChargeType.name,
      'wireChargeValue': wireChargeValue,
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
      observation: map['observation'] as String? ?? '',
      hasWirePass: map['hasWirePass'] as bool? ?? false,
      wireChargeType: () {
        final rawType = map['wireChargeType'];
        if (rawType == 'discount') return WireChargeType.percentage;
        return WireChargeType.values.firstWhere(
          (e) => e.name == rawType,
          orElse: () => WireChargeType.fixed,
        );
      }(),
      wireChargeValue: (map['wireChargeValue'] as num?)?.toDouble() ?? 0,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory BudgetItem.fromJson(String source) =>
      BudgetItem.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
