import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
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

  /// Icons only; the captions are resolved per language in [build].
  static const List<_Destination> _destinations = [
    _Destination(Icons.home_rounded, Icons.home_outlined),
    _Destination(Icons.calendar_month_rounded, Icons.calendar_month_outlined),
    _Destination(Icons.person_rounded, Icons.person_outline),
  ];

  /// Lets child screens jump to another tab (e.g. Home -> Appointments).
  void _goToTab(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = [l10n.navHome, l10n.navAppointments, l10n.navProfile];

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
              for (var i = 0; i < _destinations.length; i++)
                BottomNavigationBarItem(
                  icon: Icon(_destinations[i].outlined),
                  activeIcon: Icon(_destinations[i].filled),
                  label: labels[i],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination(this.filled, this.outlined);

  final IconData filled;
  final IconData outlined;
}
