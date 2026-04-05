import 'dart:convert';

import 'budget_item.dart';

class ServiceType {
  ServiceType({
    required this.id,
    required this.name,
    required this.valueType,
    required this.defaultValue,
    required this.active,
    required this.createdAt,
  });

  final String id;
  final String name;
  final ItemValueType valueType;
  final double defaultValue;
  final bool active;
  final DateTime createdAt;

  ServiceType copyWith({
    String? id,
    String? name,
    ItemValueType? valueType,
    double? defaultValue,
    bool? active,
    DateTime? createdAt,
  }) {
    return ServiceType(
      id: id ?? this.id,
      name: name ?? this.name,
      valueType: valueType ?? this.valueType,
      defaultValue: defaultValue ?? this.defaultValue,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'valueType': valueType.name,
      'defaultValue': defaultValue,
      'active': active,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ServiceType.fromMap(Map<String, dynamic> map) {
    return ServiceType(
      id: map['id'] as String,
      name: map['name'] as String,
      valueType: ItemValueType.values.firstWhere(
        (e) => e.name == map['valueType'],
        orElse: () => ItemValueType.fixed,
      ),
      defaultValue: (map['defaultValue'] as num).toDouble(),
      active: map['active'] as bool? ?? true,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory ServiceType.fromJson(String source) =>
      ServiceType.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
