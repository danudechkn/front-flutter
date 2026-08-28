import 'package:flutter/material.dart';
import '../nurse_queue/nurse_queue_page.dart';
import '../bed_qr/bed_qr_management_page.dart';
import 'admin_overview_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  static const Color _primaryTeal = Color(0xFF166568);
  static const Color _sidebarBg = Color(0xFFFFFFFF);
  static const Color _headerBg = Color(0xFF166568);
  static const double _sidebarWidth = 200;
  static const double _breakpoint = 720;

  int _selectedIndex = 0;

  final List<_NavItem> _navItems = [
    _NavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'ภาพรวม'),
    _NavItem(icon: Icons.notifications_outlined, activeIcon: Icons.notifications, label: 'คำขอผู้ป่วย'),
    _NavItem(icon: Icons.bed_outlined, activeIcon: Icons.bed, label: 'เตียงและ QR'),
  ];

  Widget _buildPage(int index) {
    switch (index) {
      case 0: return const AdminOverviewPage();
      case 1: return const NurseQueuePage(embedded: true);
      case 2: return const BedQrManagementPage(embedded: true);
      default: return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= _breakpoint;

    if (isWide) {
      return _buildWideLayout();
    } else {
      return _buildNarrowLayout();
    }
  }

  Widget _buildWideLayout() {
    return Scaffold(
      body: Row(
        children: [
          // ─── Sidebar ───────────────────────────────────────────
          Container(
            width: _sidebarWidth,
            color: _sidebarBg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Sidebar Header
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
                  color: _headerBg,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CareLink',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ระบบพยาบาล',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Nav Items
                ..._navItems.asMap().entries.map((e) {
                  final selected = e.key == _selectedIndex;
                  return _buildNavItem(e.key, e.value, selected);
                }),
                const Spacer(),
                const Divider(height: 1),
                const SizedBox(height: 8),
              ],
            ),
          ),
          // Vertical divider
          Container(width: 1, color: const Color(0xFFE2E8F0)),
          // ─── Content ───────────────────────────────────────────
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: List.generate(3, _buildPage),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNarrowLayout() {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: List.generate(3, _buildPage),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        selectedItemColor: _primaryTeal,
        unselectedItemColor: const Color(0xFF718096),
        type: BottomNavigationBarType.fixed,
        items: _navItems
            .map((n) => BottomNavigationBarItem(
                  icon: Icon(n.icon),
                  activeIcon: Icon(n.activeIcon),
                  label: n.label,
                ))
            .toList(),
      ),
    );
  }

  Widget _buildNavItem(int index, _NavItem item, bool selected) {
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? _primaryTeal.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              selected ? item.activeIcon : item.icon,
              size: 20,
              color: selected ? _primaryTeal : const Color(0xFF718096),
            ),
            const SizedBox(width: 12),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? _primaryTeal : const Color(0xFF4A5568),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({required this.icon, required this.activeIcon, required this.label});
}
