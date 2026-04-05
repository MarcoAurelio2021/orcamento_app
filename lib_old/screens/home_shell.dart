import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app_state.dart';
import 'budgets_screen.dart';
import 'company_screen.dart';
import 'new_budget_screen.dart';
import 'reports_screen.dart';
import 'services_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    final List<Widget> screens = [
      const NewBudgetScreen(),
      const BudgetsScreen(),
      const ReportsScreen(),
      const ServicesScreen(),
      const CompanyScreen(),
    ];

    if (!appState.isReady) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 960;

        final drawerContent = _NavigationRailContent(
          selectedIndex: _selectedIndex,
          onSelected: (index) {
            setState(() => _selectedIndex = index);
            if (!isWide) {
              Navigator.of(context).pop();
            }
          },
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text('Sistema de Orçamentos'),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          drawer: isWide ? null : Drawer(child: drawerContent),
          body: SafeArea(
            child: Row(
              children: [
                if (isWide)
                  SizedBox(
                    width: 280,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: drawerContent,
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: screens[_selectedIndex],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NavigationRailContent extends StatelessWidget {
  const _NavigationRailContent({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, String label})>[
      (icon: Icons.note_add_outlined, label: 'Novo orçamento'),
      (icon: Icons.receipt_long_outlined, label: 'Orçamentos criados'),
      (icon: Icons.search_outlined, label: 'Pesquisar relatórios'),
      (icon: Icons.build_outlined, label: 'Gerenciar tipos de serviço'),
      (icon: Icons.business_outlined, label: 'Dados da empresa'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Menu',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text('Navegue pelas áreas principais do app.'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ...items.indexed.map(
              (entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  selected: entry.$1 == selectedIndex,
                  leading: Icon(entry.$2.icon),
                  title: Text(entry.$2.label),
                  onTap: () => onSelected(entry.$1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
