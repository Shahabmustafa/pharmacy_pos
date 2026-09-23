import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../data/local/database/app_database.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../core/widgets/app_icon.dart';

class CategoriesUnitsScreen extends ConsumerStatefulWidget {
  const CategoriesUnitsScreen({super.key});

  @override
  ConsumerState<CategoriesUnitsScreen> createState() => _CategoriesUnitsScreenState();
}

class _CategoriesUnitsScreenState extends ConsumerState<CategoriesUnitsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingLG),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const AppIcon(AppIcons.arrowBack),
                  onPressed: () => context.canPop() ? context.pop() : context.go('/inventory'),
                ),
                const SizedBox(width: 4),
                Text('Categories & Units', style: Theme.of(context).textTheme.headlineMedium),
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
                  _tab(AppIcons.inventory2, 'Categories'),
                  _tab(AppIcons.straighten, 'Units'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _CategoriesTab(db: db),
                  _UnitsTab(db: db),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tab(String icon, String label) {
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
}

// ─── Categories ──────────────────────────────────────────────────────────────

class _CategoriesTab extends StatelessWidget {
  final AppDatabase db;
  const _CategoriesTab({required this.db});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Spacer(),
                ElevatedButton.icon(
                  icon: const AppIcon(AppIcons.add, size: 18),
                  label: const Text('Add Category'),
                  onPressed: () => showCategoryDialog(context, db),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<MedicineCategory>>(
              stream: (db.select(db.medicineCategories)
                    ..orderBy([(c) => OrderingTerm.asc(c.sortOrder), (c) => OrderingTerm.asc(c.name)]))
                  .watch(),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final cats = snap.data!;
                if (cats.isEmpty) {
                  return const Center(child: Text('No categories yet', style: TextStyle(color: AppColors.textHint)));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: cats.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final c = cats[i];
                    return ListTile(
                      leading: const AppIcon(AppIcons.inventory2, size: 20, color: AppColors.primary),
                      title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: (c.description ?? '').isNotEmpty ? Text(c.description!) : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const AppIcon(AppIcons.editOutlined, size: 18),
                            tooltip: 'Edit',
                            onPressed: () => showCategoryDialog(context, db, category: c),
                          ),
                          IconButton(
                            icon: const AppIcon(AppIcons.deleteOutline, size: 18, color: AppColors.error),
                            tooltip: 'Delete',
                            onPressed: () => _deleteCategory(context, db, c),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCategory(BuildContext context, AppDatabase db, MedicineCategory c) async {
    final usedBy = (await (db.select(db.medicines)..where((m) => m.categoryId.equals(c.id))).get()).length;
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text(
          usedBy > 0
              ? 'Delete "${c.name}"? $usedBy medicine(s) use this category and will be left without one.'
              : 'Delete "${c.name}"?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await (db.update(db.medicines)..where((m) => m.categoryId.equals(c.id)))
          .write(const MedicinesCompanion(categoryId: Value(null)));
      await (db.delete(db.medicineCategories)..where((x) => x.id.equals(c.id))).go();
    }
  }
}

Future<void> showCategoryDialog(BuildContext context, AppDatabase db, {MedicineCategory? category}) async {
  final nameCtrl = TextEditingController(text: category?.name ?? '');
  final descCtrl = TextEditingController(text: category?.description ?? '');
  final sortCtrl = TextEditingController(text: (category?.sortOrder ?? 0).toString());
  final formKey = GlobalKey<FormState>();

  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(category != null ? 'Edit Category' : 'Add Category'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description (optional)'), maxLines: 2),
              const SizedBox(height: 12),
              TextFormField(
                controller: sortCtrl,
                decoration: const InputDecoration(labelText: 'Sort Order'),
                keyboardType: TextInputType.number,
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
            final name = nameCtrl.text.trim();
            final desc = descCtrl.text.trim();
            final sort = int.tryParse(sortCtrl.text.trim()) ?? 0;
            if (category != null) {
              await (db.update(db.medicineCategories)..where((c) => c.id.equals(category.id))).write(
                MedicineCategoriesCompanion(
                  name: Value(name),
                  description: Value(desc.isEmpty ? null : desc),
                  sortOrder: Value(sort),
                  needsSync: const Value(true),
                ),
              );
            } else {
              await db.into(db.medicineCategories).insert(MedicineCategoriesCompanion.insert(
                    name: name,
                    description: Value(desc.isEmpty ? null : desc),
                    sortOrder: Value(sort),
                    needsSync: const Value(true),
                  ));
            }
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

// ─── Units ───────────────────────────────────────────────────────────────────

class _UnitsTab extends StatelessWidget {
  final AppDatabase db;
  const _UnitsTab({required this.db});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Spacer(),
                ElevatedButton.icon(
                  icon: const AppIcon(AppIcons.add, size: 18),
                  label: const Text('Add Unit'),
                  onPressed: () => showUnitDialog(context, db),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<MedicineUnit>>(
              stream: (db.select(db.medicineUnits)..orderBy([(u) => OrderingTerm.asc(u.name)])).watch(),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final units = snap.data!;
                if (units.isEmpty) {
                  return const Center(child: Text('No units yet', style: TextStyle(color: AppColors.textHint)));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: units.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final u = units[i];
                    return ListTile(
                      leading: const AppIcon(AppIcons.straighten, size: 20, color: AppColors.primary),
                      title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text(u.abbreviation),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const AppIcon(AppIcons.editOutlined, size: 18),
                            tooltip: 'Edit',
                            onPressed: () => showUnitDialog(context, db, unit: u),
                          ),
                          IconButton(
                            icon: const AppIcon(AppIcons.deleteOutline, size: 18, color: AppColors.error),
                            tooltip: 'Delete',
                            onPressed: () => _deleteUnit(context, db, u),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUnit(BuildContext context, AppDatabase db, MedicineUnit u) async {
    final usedBy = (await (db.select(db.medicines)..where((m) => m.unitId.equals(u.id))).get()).length;
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Unit'),
        content: Text(
          usedBy > 0
              ? 'Delete "${u.name}"? $usedBy medicine(s) use this unit and will be left without one.'
              : 'Delete "${u.name}"?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await (db.update(db.medicines)..where((m) => m.unitId.equals(u.id)))
          .write(const MedicinesCompanion(unitId: Value(null)));
      await (db.delete(db.medicineUnits)..where((x) => x.id.equals(u.id))).go();
    }
  }
}

Future<void> showUnitDialog(BuildContext context, AppDatabase db, {MedicineUnit? unit}) async {
  final nameCtrl = TextEditingController(text: unit?.name ?? '');
  final abbrCtrl = TextEditingController(text: unit?.abbreviation ?? '');
  final formKey = GlobalKey<FormState>();

  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(unit != null ? 'Edit Unit' : 'Add Unit'),
      content: SizedBox(
        width: 340,
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name *  (e.g. Strip, Bottle)'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: abbrCtrl,
                decoration: const InputDecoration(labelText: 'Abbreviation *  (max 10 chars)'),
                maxLength: 10,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
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
            final name = nameCtrl.text.trim();
            final abbr = abbrCtrl.text.trim();
            if (unit != null) {
              await (db.update(db.medicineUnits)..where((u) => u.id.equals(unit.id))).write(
                MedicineUnitsCompanion(
                  name: Value(name),
                  abbreviation: Value(abbr),
                ),
              );
            } else {
              await db.into(db.medicineUnits).insert(MedicineUnitsCompanion.insert(
                    name: name,
                    abbreviation: abbr,
                  ));
            }
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
