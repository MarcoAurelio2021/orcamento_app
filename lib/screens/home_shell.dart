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
            title: const Text('Speed Orçamento'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            foregroundColor: const Color(0xFF1E2A78),
            iconTheme: const IconThemeData(
              color: Color(0xFF1E2A78),
            ),
          ),
          drawer: isWide ? null : Drawer(child: drawerContent),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFF5F7FB),
                  Color(0xFFEAF1FF),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  if (isWide)
                    SizedBox(
                      width: 300,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: drawerContent,
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        children: [
                          _TopBanner(selectedIndex: _selectedIndex),
                          const SizedBox(height: 16),
                          Expanded(
                            child: screens[_selectedIndex],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TopBanner extends StatelessWidget {
  const _TopBanner({required this.selectedIndex});

  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    const titles = [
      'Novo orçamento',
      'Orçamentos criados',
      'Pesquisar relatórios',
      'Gerenciar tipos de serviço',
      'Dados da empresa',
    ];

    const subtitles = [
      'Monte propostas com rapidez e apresentação profissional.',
      'Visualize e acompanhe os orçamentos já cadastrados.',
      'Pesquise relatórios e consulte documentos com facilidade.',
      'Organize os tipos de serviço de forma prática.',
      'Mantenha as informações da sua empresa sempre prontas.',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E2A78),
            Color(0xFF5F8DBB),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            blurRadius: 24,
            offset: Offset(0, 12),
            color: Color(0x22000000),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 58,
            width: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.flash_on_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titles[selectedIndex],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitles[selectedIndex],
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.35,
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
      (icon: Icons.note_add_rounded, label: 'Novo orçamento'),
      (icon: Icons.receipt_long_rounded, label: 'Orçamentos criados'),
      (icon: Icons.search_rounded, label: 'Pesquisar relatórios'),
      (icon: Icons.build_rounded, label: 'Gerenciar tipos de serviço'),
      (icon: Icons.business_rounded, label: 'Dados da empresa'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            blurRadius: 24,
            offset: Offset(0, 10),
            color: Color(0x12000000),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF1E2A78),
                  Color(0xFF5F8DBB),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white24,
                  child: Icon(
                    Icons.flash_on_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                SizedBox(height: 14),
                Text(
                  'Speed Orçamento',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Rápido, organizado e com visual profissional.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = index == selectedIndex;

                return Material(
                  color:
                      isSelected ? const Color(0xFFE8EEFF) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    selected: isSelected,
                    leading: Icon(
                      item.icon,
                      color: isSelected
                          ? const Color(0xFF1E2A78)
                          : const Color(0xFF5B6475),
                    ),
                    title: Text(
                      item.label,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? const Color(0xFF1E2A78)
                            : const Color(0xFF283142),
                      ),
                    ),
                    onTap: () => onSelected(index),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FB),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.verified_rounded,
                    color: Color(0xFF1E2A78),
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Seu app está ganhando uma identidade mais forte e mais confiável para apresentar ao cliente.',
                      style: TextStyle(
                        fontSize: 12.8,
                        height: 1.35,
                        color: Color(0xFF4B5563),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
