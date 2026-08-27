import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'appointments_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

/// Holds the three top-level destinations behind the bottom navigation bar.
///
/// Tabs are kept alive by an [IndexedStack] so switching away and back does not
/// rebuild or lose scroll position.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index = widget.initialIndex;

  static const List<_Destination> _destinations = [
    _Destination(Icons.home_rounded, Icons.home_outlined, 'Home'),
    _Destination(
      Icons.calendar_month_rounded,
      Icons.calendar_month_outlined,
      'Appointments',
    ),
    _Destination(Icons.person_rounded, Icons.person_outline, 'Profile'),
  ];

  /// Lets child screens jump to another tab (e.g. Home -> Appointments).
  void _goToTab(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(onSeeAllAppointments: () => _goToTab(1)),
          const AppointmentsScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: _index,
            onTap: _goToTab,
            items: [
              for (final d in _destinations)
                BottomNavigationBarItem(
                  icon: Icon(d.outlined),
                  activeIcon: Icon(d.filled),
                  label: d.label,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination(this.filled, this.outlined, this.label);

  final IconData filled;
  final IconData outlined;
  final String label;
}
