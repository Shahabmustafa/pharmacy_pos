import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/app_strings.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../services/sync_service.dart';
import '../../services/connectivity_service.dart';
import 'app_icon.dart';

class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _isSidebarCollapsed = false;
  bool _autoCollapsed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_autoCollapsed) {
      _autoCollapsed = true;
      _isSidebarCollapsed = MediaQuery.of(context).size.width < 1100;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final syncState = ref.watch(syncServiceProvider);
    final isOnline = ref.watch(isOnlineProvider).value ?? true;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          _Sidebar(
            collapsed: _isSidebarCollapsed,
            onToggle: () => setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
            currentUser: auth.user?.name ?? '',
            currentRole: auth.user?.role ?? '',
          ),
          Expanded(
            child: Column(
              children: [
                _TopBar(
                  isOnline: isOnline,
                  syncState: syncState,
                  onSync: () => ref.read(syncServiceProvider.notifier).syncNow(),
                  onLogout: () => ref.read(authProvider.notifier).logout(),
                ),
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final bool isOnline;
  final SyncState syncState;
  final VoidCallback onSync;
  final VoidCallback onLogout;

  const _TopBar({
    required this.isOnline,
    required this.syncState,
    required this.onSync,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizes.appBarHeight,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingMD),
      child: Row(
        children: [
          const Spacer(),
          // Sync status
          _SyncIndicator(isOnline: isOnline, syncState: syncState, onSync: onSync),
          const SizedBox(width: AppSizes.paddingMD),
          // Logout
          IconButton(
            icon: const AppIcon(AppIcons.logout, size: AppSizes.iconMD),
            tooltip: 'Logout',
            onPressed: onLogout,
          ),
        ],
      ),
    );
  }
}

class _SyncIndicator extends StatelessWidget {
  final bool isOnline;
  final SyncState syncState;
  final VoidCallback onSync;

  const _SyncIndicator({required this.isOnline, required this.syncState, required this.onSync});

  @override
  Widget build(BuildContext context) {
    if (!isOnline) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(AppIcons.wifiOff, color: AppColors.warning, size: AppSizes.iconMD),
          SizedBox(width: 4),
          Text(AppStrings.offline, style: TextStyle(color: AppColors.warning, fontSize: AppSizes.fontSM)),
        ],
      );
    }

    final isPending = syncState.pendingCount > 0;
    final isSyncing = syncState.status == SyncStatus.syncing;

    return InkWell(
      onTap: onSync,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSyncing)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              AppIcon(
                isPending ? AppIcons.syncProblem : AppIcons.sync,
                color: isPending ? AppColors.warning : AppColors.success,
                size: AppSizes.iconMD,
              ),
            const SizedBox(width: 4),
            Text(
              isSyncing
                  ? AppStrings.syncing
                  : isPending
                      ? '${syncState.pendingCount} pending'
                      : AppStrings.online,
              style: TextStyle(
                color: isSyncing
                    ? AppColors.primary
                    : isPending
                        ? AppColors.warning
                        : AppColors.success,
                fontSize: AppSizes.fontSM,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  final bool collapsed;
  final VoidCallback onToggle;
  final String currentUser;
  final String currentRole;

  const _Sidebar({
    required this.collapsed,
    required this.onToggle,
    required this.currentUser,
    required this.currentRole,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenW = MediaQuery.of(context).size.width;
    final expandedWidth = screenW < 1280 ? 200.0 : AppSizes.sidebarWidth;
    final width = collapsed ? AppSizes.sidebarCollapsedWidth : expandedWidth;
    final location = GoRouterState.of(context).matchedLocation;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: width,
      decoration: const BoxDecoration(
        color: AppColors.sidebarBg,
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(2, 0))],
      ),
      child: Column(
        children: [
          // Logo area
          Container(
            height: AppSizes.appBarHeight,
            padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 12),
            decoration: const BoxDecoration(
              color: AppColors.primaryDark,
              border: Border(bottom: BorderSide(color: Colors.white12)),
            ),
            child: collapsed
                ? Center(
                    child: IconButton(
                      icon: const AppIcon(AppIcons.menuOpen, color: Colors.white70, size: 20),
                      onPressed: onToggle,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  )
                : Row(
                    children: [
                      const AppIcon(AppIcons.localPharmacy, color: Colors.white, size: 28),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          AppStrings.appName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: AppSizes.fontLG,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const AppIcon(AppIcons.menu, color: Colors.white70, size: 20),
                        onPressed: onToggle,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
          ),

          // Nav items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _NavItem(icon: AppIcons.dashboard, label: AppStrings.dashboard, path: '/dashboard', location: location, collapsed: collapsed),
                _NavItem(icon: AppIcons.pointOfSale, label: AppStrings.pos, path: '/pos', location: location, collapsed: collapsed),
                _NavItem(icon: AppIcons.inventory2, label: AppStrings.inventory, path: '/inventory', location: location, collapsed: collapsed),
                _NavItem(icon: AppIcons.shoppingCart, label: AppStrings.purchases, path: '/purchases', location: location, collapsed: collapsed),
                _NavItem(icon: AppIcons.people, label: AppStrings.customers, path: '/customers', location: location, collapsed: collapsed),
                _NavItem(icon: AppIcons.localShipping, label: AppStrings.suppliers, path: '/suppliers', location: location, collapsed: collapsed),
                const Divider(color: Colors.white12, height: 16, indent: 12, endIndent: 12),
                _NavItem(icon: AppIcons.barChart, label: AppStrings.reports, path: '/reports', location: location, collapsed: collapsed),
                _NavItem(icon: AppIcons.receiptLong, label: AppStrings.expenses, path: '/expenses', location: location, collapsed: collapsed),
                _NavItem(icon: AppIcons.settings, label: AppStrings.settings, path: '/settings', location: location, collapsed: collapsed),
              ],
            ),
          ),

          // User info
          if (!collapsed)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppColors.primaryDark,
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.white24,
                    child: Text(
                      currentUser.isNotEmpty ? currentUser[0].toUpperCase() : 'U',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentUser,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          currentRole.toUpperCase(),
                          style: const TextStyle(color: Colors.white54, fontSize: 10),
                        ),
                      ],
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

class _NavItem extends StatelessWidget {
  final String icon;
  final String label;
  final String path;
  final String location;
  final bool collapsed;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.path,
    required this.location,
    required this.collapsed,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = location.startsWith(path);

    return Tooltip(
      message: collapsed ? label : '',
      preferBelow: false,
      child: InkWell(
        onTap: () => context.go(path),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: EdgeInsets.symmetric(
            horizontal: collapsed ? 0 : 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: isActive ? AppColors.sidebarItemActive : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              AppIcon(
                icon,
                color: isActive ? Colors.white : Colors.white60,
                size: AppSizes.iconMD,
              ),
              if (!collapsed) ...[
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.white70,
                    fontSize: AppSizes.fontMD,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
