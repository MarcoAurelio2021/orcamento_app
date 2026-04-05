import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app_state.dart';
import '../models/company_data.dart';
import 'widgets/app_section_card.dart';

class CompanyScreen extends StatefulWidget {
  const CompanyScreen({super.key});

  @override
  State<CompanyScreen> createState() => _CompanyScreenState();
}

class _CompanyScreenState extends State<CompanyScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _cnpjController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    final company = context.read<AppState>().company;
    _nameController = TextEditingController(text: company.name);
    _cnpjController = TextEditingController(text: company.cnpj);
    _phoneController = TextEditingController(text: company.phone);
    _emailController = TextEditingController(text: company.email);
    _addressController = TextEditingController(text: company.address);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cnpjController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final company = CompanyData(
      name: _nameController.text.trim(),
      cnpj: _cnpjController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      address: _addressController.text.trim(),
    );
    await context.read<AppState>().saveCompany(company);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dados da empresa salvos.')));
  }

  void _clear() {
    _nameController.clear();
    _cnpjController.clear();
    _phoneController.clear();
    _emailController.clear();
    _addressController.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        AppSectionCard(
          title: 'Dados da empresa',
          subtitle: 'Essas informações podem aparecer no PDF e no compartilhamento de texto.',
          child: Column(
            children: [
              TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nome da empresa')),
              const SizedBox(height: 12),
              TextField(controller: _cnpjController, decoration: const InputDecoration(labelText: 'CNPJ')),
              const SizedBox(height: 12),
              TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Telefone')),
              const SizedBox(height: 12),
              TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'E-mail')),
              const SizedBox(height: 12),
              TextField(controller: _addressController, decoration: const InputDecoration(labelText: 'Endereço')),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(width: 220, child: ElevatedButton(onPressed: _save, child: const Text('Salvar dados'))),
                  SizedBox(width: 220, child: OutlinedButton(onPressed: _clear, child: const Text('Limpar dados'))),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
