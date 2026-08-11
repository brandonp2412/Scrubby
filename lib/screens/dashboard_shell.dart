import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/app_state.dart';
import '../core/home_assistant.dart';
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

class _DashboardShellState extends State<DashboardShell>
    with SingleTickerProviderStateMixin {
  HomeAssistantConnectionStatus? _lastConnectionStatus;
  late final TabController _tabController;
  late final Animation<double> _tabAnimation;
  int _lastCommittedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(_handleTabChanged);
    _tabAnimation = _tabController.animation!;
    _lastConnectionStatus = widget.state.connectionStatus;
    widget.state.addListener(_handleStateChanged);
  }

  @override
  void didUpdateWidget(covariant DashboardShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      oldWidget.state.removeListener(_handleStateChanged);
      _lastConnectionStatus = widget.state.connectionStatus;
      widget.state.addListener(_handleStateChanged);
    }
  }

  @override
  void dispose() {
    widget.state.removeListener(_handleStateChanged);
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    super.dispose();
  }

  void _handleStateChanged() {
    final status = widget.state.connectionStatus;
    final wasConnected =
        _lastConnectionStatus == HomeAssistantConnectionStatus.connected;
    _lastConnectionStatus = status;
    if (wasConnected &&
        status == HomeAssistantConnectionStatus.reconnecting &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection error. Trying to reconnect.')),
      );
    }
  }

  void _selectPage(int value) {
    if (value != _tabController.index) _tabController.animateTo(value);
  }

  void _handleTabChanged() {
    final selectedIndex = _tabController.index;
    final didCommitNewPage = selectedIndex != _lastCommittedTabIndex;
    _lastCommittedTabIndex = selectedIndex;
    if (didCommitNewPage && selectedIndex == 1) {
      widget.state.refreshSchedules();
    }
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
              AnimatedBuilder(
                animation: _tabAnimation,
                builder: (context, _) => _SideRail(
                  index: _tabAnimation.value.round(),
                  onSelected: _selectPage,
                  onLogout: _confirmLogout,
                  offline: widget.state.isOffline,
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  _TopBar(state: widget.state, onLogout: _confirmLogout),
                  Expanded(
                    child: TabBarView(
                      key: const ValueKey('dashboard-page-content'),
                      controller: _tabController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: pages,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: MediaQuery.sizeOf(context).width < 900
            ? AnimatedBuilder(
                animation: _tabAnimation,
                builder: (context, _) => NavigationBar(
                  selectedIndex: _tabAnimation.value.round(),
                  onDestinationSelected: _selectPage,
                  destinations: const [
                    NavigationDestination(
                      key: ValueKey('dashboard-tab-0'),
                      icon: Icon(Icons.space_dashboard_outlined),
                      selectedIcon: Icon(Icons.space_dashboard),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      key: ValueKey('dashboard-tab-1'),
                      icon: Icon(Icons.calendar_month_outlined),
                      selectedIcon: Icon(Icons.calendar_month),
                      label: 'Schedule',
                    ),
                    NavigationDestination(
                      key: ValueKey('dashboard-tab-2'),
                      icon: Icon(Icons.door_front_door_outlined),
                      selectedIcon: Icon(Icons.door_front_door),
                      label: 'Rooms',
                    ),
                  ],
                ),
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
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Symbols.vacuum_2,
                color: Colors.white,
                size: 35,
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
            if (state.isOffline)
              const _OfflineIndicator()
            else
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

class _OfflineIndicator extends StatelessWidget {
  const _OfflineIndicator();

  @override
  Widget build(BuildContext context) => const Tooltip(
    message: 'Offline — reconnecting periodically',
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, color: coral),
          SizedBox(width: 5),
          Text('Offline', style: TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    ),
  );
}

class _SideRail extends StatelessWidget {
  const _SideRail({
    required this.index,
    required this.onSelected,
    required this.onLogout,
    required this.offline,
  });
  final int index;
  final ValueChanged<int> onSelected;
  final VoidCallback onLogout;
  final bool offline;

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
                  radius: 25,
                  backgroundColor: fern,
                  child: Icon(
                    Icons.cleaning_services_rounded,
                    color: mint,
                    size: 28,
                  ),
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
            key: const ValueKey('dashboard-tab-0'),
            icon: Icons.space_dashboard_rounded,
            label: 'Overview',
            selected: index == 0,
            onTap: () => onSelected(0),
          ),
          _RailItem(
            key: const ValueKey('dashboard-tab-1'),
            icon: Icons.calendar_month_rounded,
            label: 'Schedules',
            selected: index == 1,
            onTap: () => onSelected(1),
          ),
          _RailItem(
            key: const ValueKey('dashboard-tab-2'),
            icon: Icons.door_front_door_rounded,
            label: 'Rooms',
            selected: index == 2,
            onTap: () => onSelected(2),
          ),
          const Spacer(),
          _RailItem(
            icon: offline ? Icons.cloud_off_rounded : Icons.logout_rounded,
            label: offline ? 'Offline' : 'Disconnect',
            selected: false,
            onTap: offline ? null : onLogout,
          ),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

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
