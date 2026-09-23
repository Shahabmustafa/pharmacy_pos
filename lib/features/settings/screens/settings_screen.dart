import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../data/local/database/app_database.dart' show User;
import '../../../data/repositories/settings_repository.dart';
import '../../../services/sync_service.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../data/repositories/sale_repository.dart';
import '../../../dev/demo_data_seeder.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  Map<String, String> _settings = {};
  bool _loading = true;
  bool _saving = false;

  final _shopNameCtrl = TextEditingController();
  final _shopAddressCtrl = TextEditingController();
  final _shopPhoneCtrl = TextEditingController();
  final _shopEmailCtrl = TextEditingController();
  final _headerCtrl = TextEditingController();
  final _footerCtrl = TextEditingController();
  final _supabaseUrlCtrl = TextEditingController();
  final _supabaseKeyCtrl = TextEditingController();
  final _invoicePrefixCtrl = TextEditingController();
  final _taxCtrl = TextEditingController();
  final _lowStockDaysCtrl = TextEditingController();
  final _expiryDaysCtrl = TextEditingController();
  final _printerIpCtrl = TextEditingController();
  final _printerPortCtrl = TextEditingController();
  final _printerUsbPathCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final s = await ref.read(settingsRepositoryProvider).getAll();
    setState(() {
      _settings = s;
      _shopNameCtrl.text = s['shop_name'] ?? '';
      _shopAddressCtrl.text = s['shop_address'] ?? '';
      _shopPhoneCtrl.text = s['shop_phone'] ?? '';
      _shopEmailCtrl.text = s['shop_email'] ?? '';
      _headerCtrl.text = s['receipt_header'] ?? '';
      _footerCtrl.text = s['receipt_footer'] ?? '';
      _supabaseUrlCtrl.text = s['supabase_url'] ?? '';
      _supabaseKeyCtrl.text = s['supabase_anon_key'] ?? '';
      _invoicePrefixCtrl.text = s['invoice_prefix'] ?? 'INV';
      _taxCtrl.text = s['tax_percent'] ?? '0';
      _lowStockDaysCtrl.text = s['low_stock_days'] ?? '30';
      _expiryDaysCtrl.text = s['expiry_warning_days'] ?? '90';
      _printerIpCtrl.text = s['printer_ip'] ?? '';
      _printerPortCtrl.text = s['printer_port'] ?? '9100';
      _printerUsbPathCtrl.text = s['printer_usb_path'] ?? '/dev/usb/lp0';
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(settingsRepositoryProvider).setMany({
        'shop_name': _shopNameCtrl.text,
        'shop_address': _shopAddressCtrl.text,
        'shop_phone': _shopPhoneCtrl.text,
        'shop_email': _shopEmailCtrl.text,
        'receipt_header': _headerCtrl.text,
        'receipt_footer': _footerCtrl.text,
        'supabase_url': _supabaseUrlCtrl.text,
        'supabase_anon_key': _supabaseKeyCtrl.text,
        'invoice_prefix': _invoicePrefixCtrl.text,
        'tax_percent': _taxCtrl.text,
        'low_stock_days': _lowStockDaysCtrl.text,
        'expiry_warning_days': _expiryDaysCtrl.text,
        'printer_ip': _printerIpCtrl.text,
        'printer_port': _printerPortCtrl.text,
        'printer_usb_path': _printerUsbPathCtrl.text,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully'), backgroundColor: AppColors.success),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _settingsTab(String icon, String label) {
    return Tab(
      height: 42,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, size: AppSizes.iconSM),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    for (final c in [_shopNameCtrl, _shopAddressCtrl, _shopPhoneCtrl, _shopEmailCtrl, _headerCtrl, _footerCtrl, _supabaseUrlCtrl, _supabaseKeyCtrl, _invoicePrefixCtrl, _taxCtrl, _lowStockDaysCtrl, _expiryDaysCtrl, _printerIpCtrl, _printerPortCtrl, _printerUsbPathCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingLG),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
                const Spacer(),
                ElevatedButton.icon(
                  icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const AppIcon(AppIcons.save),
                  label: const Text('Save Settings'),
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppSizes.buttonRadius + 4),
                border: Border.all(color: AppColors.divider),
              ),
              child: TabBar(
                controller: _tabCtrl,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                splashBorderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                  boxShadow: [
                    BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2)),
                  ],
                ),
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: AppSizes.fontSM),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: AppSizes.fontSM),
                tabs: [
                  _settingsTab(AppIcons.store, 'Shop Info'),
                  _settingsTab(AppIcons.receipt, 'Receipt'),
                  _settingsTab(AppIcons.cloudSync, 'Sync & Cloud'),
                  _settingsTab(AppIcons.people, 'Users'),
                  _settingsTab(AppIcons.science, 'Developer'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  // Shop Info
                  SingleChildScrollView(
                    child: Column(
                      children: [
                        _SettingsCard(title: 'Pharmacy Information', children: [
                          TextFormField(controller: _shopNameCtrl, decoration: const InputDecoration(labelText: 'Pharmacy / Shop Name')),
                          const SizedBox(height: 12),
                          TextFormField(controller: _shopAddressCtrl, decoration: const InputDecoration(labelText: 'Address'), maxLines: 2),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(child: TextFormField(controller: _shopPhoneCtrl, decoration: const InputDecoration(labelText: 'Phone'))),
                            const SizedBox(width: 12),
                            Expanded(child: TextFormField(controller: _shopEmailCtrl, decoration: const InputDecoration(labelText: 'Email'))),
                          ]),
                        ]),
                        const SizedBox(height: 16),
                        _SettingsCard(title: 'Invoice Settings', children: [
                          Row(children: [
                            Expanded(child: TextFormField(controller: _invoicePrefixCtrl, decoration: const InputDecoration(labelText: 'Invoice Prefix (e.g. INV)'))),
                            const SizedBox(width: 12),
                            Expanded(child: TextFormField(controller: _taxCtrl, decoration: const InputDecoration(labelText: 'Default Tax %', suffixText: '%'))),
                          ]),
                        ]),
                        const SizedBox(height: 16),
                        _SettingsCard(title: 'Alert Thresholds', children: [
                          Row(children: [
                            Expanded(child: TextFormField(controller: _lowStockDaysCtrl, decoration: const InputDecoration(labelText: 'Low Stock Alert (quantity)'))),
                            const SizedBox(width: 12),
                            Expanded(child: TextFormField(controller: _expiryDaysCtrl, decoration: const InputDecoration(labelText: 'Expiry Warning (days before)'))),
                          ]),
                        ]),
                      ],
                    ),
                  ),

                  // Receipt
                  SingleChildScrollView(
                    child: Column(
                      children: [
                        _SettingsCard(title: 'Receipt Customization', children: [
                          TextFormField(controller: _headerCtrl, decoration: const InputDecoration(labelText: 'Header Message (shown below shop name)'), maxLines: 2),
                          const SizedBox(height: 12),
                          TextFormField(controller: _footerCtrl, decoration: const InputDecoration(labelText: 'Footer Message (shown at bottom)'), maxLines: 2),
                        ]),
                        const SizedBox(height: 16),
                        _SettingsCard(title: 'Printer Settings', children: [
                          DropdownButtonFormField<String>(
                            value: _settings['printer_type'] ?? 'pdf',
                            decoration: const InputDecoration(labelText: 'Printer Type'),
                            items: const [
                              DropdownMenuItem(value: 'pdf', child: Text('PDF / System Printer')),
                              DropdownMenuItem(value: 'usb', child: Text('USB Thermal Printer')),
                              DropdownMenuItem(value: 'network', child: Text('Network / WiFi Printer')),
                              DropdownMenuItem(value: 'bluetooth', child: Text('Bluetooth Printer')),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => _settings['printer_type'] = v);
                              ref.read(settingsRepositoryProvider).set('printer_type', v ?? 'pdf');
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _settings['receipt_width'] ?? '80',
                            decoration: const InputDecoration(labelText: 'Paper Width'),
                            items: const [
                              DropdownMenuItem(value: '58', child: Text('58mm')),
                              DropdownMenuItem(value: '80', child: Text('80mm')),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => _settings['receipt_width'] = v);
                              ref.read(settingsRepositoryProvider).set('receipt_width', v ?? '80');
                            },
                          ),
                          if ((_settings['printer_type'] ?? 'pdf') == 'network') ...[
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _printerIpCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Printer IP Address',
                                    hintText: '192.168.1.100',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _printerPortCtrl,
                                  decoration: const InputDecoration(labelText: 'Port', hintText: '9100'),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ]),
                          ],
                          if ((_settings['printer_type'] ?? 'pdf') == 'usb') ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _printerUsbPathCtrl,
                              decoration: const InputDecoration(
                                labelText: 'USB Printer Path',
                                hintText: '/dev/usb/lp0',
                              ),
                            ),
                          ],
                        ]),
                      ],
                    ),
                  ),

                  // Sync & Cloud
                  SingleChildScrollView(
                    child: Column(
                      children: [
                        _SettingsCard(title: 'Supabase Cloud Sync', children: [
                          const Text(
                            'Enter your Supabase project URL and anon key to enable online sync. Create a free account at supabase.com',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(controller: _supabaseUrlCtrl, decoration: const InputDecoration(labelText: 'Supabase Project URL', hintText: 'https://xxxx.supabase.co')),
                          const SizedBox(height: 12),
                          TextFormField(controller: _supabaseKeyCtrl, decoration: const InputDecoration(labelText: 'Supabase Anon Key'), obscureText: true),
                          const SizedBox(height: 16),
                          Row(children: [
                            ElevatedButton.icon(
                              icon: const AppIcon(AppIcons.sync),
                              label: const Text('Sync Now'),
                              onPressed: () => ref.read(syncServiceProvider.notifier).syncNow(),
                            ),
                          ]),
                        ]),
                        const SizedBox(height: 16),
                        Consumer(
                          builder: (_, ref, __) {
                            final syncState = ref.watch(syncServiceProvider);
                            return Card(
                              child: ListTile(
                                leading: const AppIcon(AppIcons.cloudSync, color: AppColors.primary),
                                title: const Text('Sync Status'),
                                subtitle: Text(syncState.message.isEmpty ? 'Ready to sync' : syncState.message),
                                trailing: syncState.pendingCount > 0
                                    ? Chip(label: Text('${syncState.pendingCount} pending'), backgroundColor: AppColors.warning.withValues(alpha: 0.1))
                                    : const AppIcon(AppIcons.checkCircle, color: AppColors.success),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // Users (admin only)
                  if (!auth.isAdmin)
                    const Center(child: Text('Access denied. Admin only.', style: TextStyle(color: AppColors.textHint)))
                  else
                    _UsersTab(),

                  // Developer tools (admin only)
                  if (!auth.isAdmin)
                    const Center(child: Text('Access denied. Admin only.', style: TextStyle(color: AppColors.textHint)))
                  else
                    const _DeveloperTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SettingsCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _UsersTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton.icon(
              icon: const AppIcon(AppIcons.personAdd),
              label: const Text('Add User'),
              onPressed: () => _showAddUserDialog(context, ref),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: FutureBuilder<List<User>>(
            future: ref.watch(authProvider.notifier).getAllUsers(),
            builder: (_, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final users = snap.data!;
              return Card(
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(AppColors.background),
                  columns: const [
                    DataColumn(label: Text('#')),
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Username')),
                    DataColumn(label: Text('Role')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: users.asMap().entries.map((e) {
                    final u = e.value;
                    return DataRow(cells: [
                      DataCell(Text('${e.key + 1}')),
                      DataCell(Text(u.name, style: const TextStyle(fontWeight: FontWeight.w500))),
                      DataCell(Text(u.username)),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (u.role == 'admin' ? AppColors.primary : AppColors.accent).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(u.role.toUpperCase(), style: TextStyle(fontSize: 11, color: u.role == 'admin' ? AppColors.primary : AppColors.accent, fontWeight: FontWeight.w600)),
                      )),
                      DataCell(Switch(
                        value: u.isActive,
                        onChanged: u.id == auth.user?.id ? null : (v) => ref.read(authProvider.notifier).updateUser(u.id, isActive: v),
                      )),
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const AppIcon(AppIcons.editOutlined, size: 18),
                            onPressed: u.id == auth.user?.id ? null : () => _showEditUserDialog(context, ref, u),
                          ),
                        ],
                      )),
                    ]);
                  }).toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showAddUserDialog(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    String role = 'cashier';
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Add User'),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name *'), validator: (v) => v!.isEmpty ? 'Required' : null),
                  const SizedBox(height: 12),
                  TextFormField(controller: usernameCtrl, decoration: const InputDecoration(labelText: 'Username *'), validator: (v) => v!.isEmpty ? 'Required' : null),
                  const SizedBox(height: 12),
                  TextFormField(controller: passwordCtrl, decoration: const InputDecoration(labelText: 'Password *'), obscureText: true, validator: (v) => v!.isEmpty ? 'Required' : null),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: const [
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      DropdownMenuItem(value: 'manager', child: Text('Manager')),
                      DropdownMenuItem(value: 'cashier', child: Text('Cashier')),
                      DropdownMenuItem(value: 'pharmacist', child: Text('Pharmacist')),
                    ],
                    onChanged: (v) => setS(() => role = v ?? 'cashier'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                await ref.read(authProvider.notifier).addUser(
                  name: nameCtrl.text,
                  username: usernameCtrl.text,
                  password: passwordCtrl.text,
                  role: role,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Add User'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditUserDialog(BuildContext context, WidgetRef ref, User user) async {
    final nameCtrl = TextEditingController(text: user.name);
    String role = user.role;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Edit User'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    DropdownMenuItem(value: 'manager', child: Text('Manager')),
                    DropdownMenuItem(value: 'cashier', child: Text('Cashier')),
                    DropdownMenuItem(value: 'pharmacist', child: Text('Pharmacist')),
                  ],
                  onChanged: (v) => setS(() => role = v ?? 'cashier'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                await ref.read(authProvider.notifier).updateUser(user.id, name: nameCtrl.text, role: role);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeveloperTab extends ConsumerStatefulWidget {
  const _DeveloperTab();

  @override
  ConsumerState<_DeveloperTab> createState() => _DeveloperTabState();
}

class _DeveloperTabState extends ConsumerState<_DeveloperTab> {
  bool _seeding = false;
  String? _result;

  Future<void> _seed() async {
    setState(() {
      _seeding = true;
      _result = null;
    });
    try {
      final db = ref.read(databaseProvider);
      final saleRepo = ref.read(saleRepositoryProvider);
      final userId = ref.read(authProvider).user?.id ?? 1;
      final summary = await seedDemoData(db, saleRepo, userId: userId);
      if (mounted) setState(() => _result = summary);
    } catch (e) {
      if (mounted) setState(() => _result = 'Failed: $e');
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SettingsCard(title: 'Demo Data', children: [
            const Text(
              'Populates suppliers, customers, medicines, purchases (with stock batches), '
              'a week of sales and a few expenses — so every screen (Dashboard, Inventory, '
              'POS, Reports) has real data to check. Safe to run again: existing suppliers, '
              'customers and medicines are reused, and a fresh round of sales/purchases is added.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: _seeding
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const AppIcon(AppIcons.science),
              label: Text(_seeding ? 'Seeding...' : 'Seed Demo Data'),
              onPressed: _seeding ? null : _seed,
            ),
            if (_result != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (_result!.startsWith('Failed') ? AppColors.error : AppColors.success).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                  border: Border.all(color: (_result!.startsWith('Failed') ? AppColors.error : AppColors.success).withValues(alpha: 0.25)),
                ),
                child: Text(
                  _result!,
                  style: TextStyle(color: _result!.startsWith('Failed') ? AppColors.error : AppColors.success, fontSize: 13),
                ),
              ),
            ],
          ]),
        ],
      ),
    );
  }
}
