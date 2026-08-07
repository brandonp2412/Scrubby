import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/app_state.dart';
import '../theme.dart';
import 'home_page.dart';
import 'rooms_page.dart';
import 'schedules_page.dart';
import 'settings_page.dart';

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key, required this.state});
  final AppState state;

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int index = 0;

  void _selectPage(int value) {
    setState(() => index = value);
    if (value == 1) widget.state.refreshSchedules();
  }

  void _openVacuumSettings() {
    widget.state.refreshVacuumSettings();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(widget.state.vacuum.name)),
          body: SettingsPage(state: widget.state),
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'You’ll need to reconnect to Home Assistant to use Scrubby again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (shouldLogout == true && mounted) await widget.state.logout();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(state: widget.state, onOpenSettings: _openVacuumSettings),
      SchedulesPage(state: widget.state),
      RoomsPage(state: widget.state),
    ];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: Row(
          children: [
            if (MediaQuery.sizeOf(context).width >= 900)
              _SideRail(
                index: index,
                onSelected: _selectPage,
                onLogout: _confirmLogout,
              ),
            Expanded(
              child: Column(
                children: [
                  _TopBar(state: widget.state, onLogout: _confirmLogout),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      child: KeyedSubtree(
                        key: ValueKey(index),
                        child: pages[index],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: MediaQuery.sizeOf(context).width < 900
            ? NavigationBar(
                selectedIndex: index,
                onDestinationSelected: _selectPage,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.space_dashboard_outlined),
                    selectedIcon: Icon(Icons.space_dashboard),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.calendar_month_outlined),
                    selectedIcon: Icon(Icons.calendar_month),
                    label: 'Schedule',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.door_front_door_outlined),
                    selectedIcon: Icon(Icons.door_front_door),
                    label: 'Rooms',
                  ),
                ],
              )
            : null,
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.state, required this.onLogout});
  final AppState state;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Container(
      height: 76 + topInset,
      padding: EdgeInsets.fromLTRB(24, topInset, 24, 0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE5F1E6), cream],
        ),
        border: Border(bottom: BorderSide(color: ink.withValues(alpha: .07))),
      ),
      child: Row(
        children: [
          if (MediaQuery.sizeOf(context).width < 900) ...[
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Symbols.vacuum_2,
                color: Colors.white,
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.homeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
                Text(
                  state.isDemo ? 'Demo home' : 'Home Assistant connected',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (state.vacuums.length > 1)
            PopupMenuButton<int>(
              initialValue: state.selectedVacuum,
              onSelected: state.selectVacuum,
              itemBuilder: (_) => [
                for (var i = 0; i < state.vacuums.length; i++)
                  PopupMenuItem(value: i, child: Text(state.vacuums[i].name)),
              ],
              child: _RobotPill(state: state),
            )
          else
            const SizedBox.shrink(),
          if (MediaQuery.sizeOf(context).width < 900) ...[
            const SizedBox(width: 4),
            IconButton(
              onPressed: onLogout,
              tooltip: 'Disconnect',
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ],
      ),
    );
  }
}

class _RobotPill extends StatelessWidget {
  const _RobotPill({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 6, 12, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: mint,
            child: Icon(Icons.circle_outlined, color: fern, size: 20),
          ),
          if (state.vacuums.length > 1)
            const Icon(Icons.expand_more_rounded, size: 18),
        ],
      ),
    );
  }
}

class _SideRail extends StatelessWidget {
  const _SideRail({
    required this.index,
    required this.onSelected,
    required this.onLogout,
  });
  final int index;
  final ValueChanged<int> onSelected;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Container(
      width: 230,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [fern, ink],
          stops: [0, .34],
        ),
      ),
      padding: EdgeInsets.fromLTRB(18, topInset + 24, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: fern,
                  child: Icon(Icons.cleaning_services_rounded, color: mint),
                ),
                SizedBox(width: 12),
                Text(
                  'SCRUBBY',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          _RailItem(
            icon: Icons.space_dashboard_rounded,
            label: 'Overview',
            selected: index == 0,
            onTap: () => onSelected(0),
          ),
          _RailItem(
            icon: Icons.calendar_month_rounded,
            label: 'Schedules',
            selected: index == 1,
            onTap: () => onSelected(1),
          ),
          _RailItem(
            icon: Icons.door_front_door_rounded,
            label: 'Rooms',
            selected: index == 2,
            onTap: () => onSelected(2),
          ),
          const Spacer(),
          _RailItem(
            icon: Icons.logout_rounded,
            label: 'Disconnect',
            selected: false,
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? mint : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(icon, size: 20, color: selected ? fern : Colors.white60),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? fern : Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
