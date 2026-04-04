import 'dart:convert';

class CompanyData {
  CompanyData({
    required this.name,
    required this.cnpj,
    required this.phone,
    required this.email,
    required this.address,
  });

  final String name;
  final String cnpj;
  final String phone;
  final String email;
  final String address;

  factory CompanyData.empty() {
    return CompanyData(name: '', cnpj: '', phone: '', email: '', address: '');
  }

  bool get hasAnyData =>
      name.isNotEmpty || cnpj.isNotEmpty || phone.isNotEmpty || email.isNotEmpty || address.isNotEmpty;

  CompanyData copyWith({
    String? name,
    String? cnpj,
    String? phone,
    String? email,
    String? address,
  }) {
    return CompanyData(
      name: name ?? this.name,
      cnpj: cnpj ?? this.cnpj,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'cnpj': cnpj,
      'phone': phone,
      'email': email,
      'address': address,
    };
  }

  factory CompanyData.fromMap(Map<String, dynamic> map) {
    return CompanyData(
      name: map['name'] as String? ?? '',
      cnpj: map['cnpj'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      email: map['email'] as String? ?? '',
      address: map['address'] as String? ?? '',
    );
  }

  String toJson() => jsonEncode(toMap());

  factory CompanyData.fromJson(String source) =>
      CompanyData.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
