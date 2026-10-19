import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const bool kScreenshotMode = bool.fromEnvironment('SCREENSHOT_MODE');

void main() {
  runApp(
    ValatReneApp(
      repository: OperationsRepository(screenshotMode: kScreenshotMode),
    ),
  );
}

@visibleForTesting
class ValatReneApp extends StatelessWidget {
  const ValatReneApp({super.key, required this.repository});

  final OperationsRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VALAT RENE',
      debugShowCheckedModeBanner: false,
      theme: _theme(),
      home: OperationsShell(repository: repository),
    );
  }

  ThemeData _theme() {
    const navy = Color(0xFF3CC21E);
    const orange = Color(0xFF1EC252);
    const green = Color(0xFF1EC2A4);
    const surface = Color(0xFFF5F7FA);

    final scheme =
        ColorScheme.fromSeed(
          seedColor: navy,
          brightness: Brightness.light,
        ).copyWith(
          primary: navy,
          onPrimary: Colors.white,
          secondary: orange,
          onSecondary: Colors.white,
          tertiary: green,
          onTertiary: Colors.white,
          surface: Colors.white,
          surfaceContainerHighest: const Color(0xFFE8EDF3),
          outlineVariant: const Color(0xFFD9E0EA),
        );

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: surface,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: navy,
        centerTitle: false,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFDDE5EF)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: const Color(0xFFE9F0F8),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? navy
                : const Color(0xFF607084),
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

enum RecordKind { task, container, supply, attendance }

extension RecordKindCopy on RecordKind {
  String get label {
    return switch (this) {
      RecordKind.task => 'Tasks',
      RecordKind.container => 'Containers',
      RecordKind.supply => 'Supplies',
      RecordKind.attendance => 'Attendance',
    };
  }

  String get singular {
    return switch (this) {
      RecordKind.task => 'task',
      RecordKind.container => 'container',
      RecordKind.supply => 'supply order',
      RecordKind.attendance => 'attendance log',
    };
  }

  IconData get icon {
    return switch (this) {
      RecordKind.task => Icons.task_alt_rounded,
      RecordKind.container => Icons.inventory_2_outlined,
      RecordKind.supply => Icons.local_shipping_outlined,
      RecordKind.attendance => Icons.badge_outlined,
    };
  }

  Color get accent {
    return switch (this) {
      RecordKind.task => const Color(0xFF071B3A),
      RecordKind.container => const Color(0xFF0F5E8C),
      RecordKind.supply => const Color(0xFFD85D13),
      RecordKind.attendance => const Color(0xFF2E7A3E),
    };
  }
}

@immutable
class OpsRecord {
  const OpsRecord({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.owner,
    required this.status,
    required this.priority,
    required this.dueLabel,
    required this.notes,
    required this.createdAt,
  });

  final String id;
  final RecordKind kind;
  final String title;
  final String subtitle;
  final String owner;
  final String status;
  final String priority;
  final String dueLabel;
  final String notes;
  final DateTime createdAt;

  OpsRecord copyWith({
    String? id,
    RecordKind? kind,
    String? title,
    String? subtitle,
    String? owner,
    String? status,
    String? priority,
    String? dueLabel,
    String? notes,
    DateTime? createdAt,
  }) {
    return OpsRecord(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      owner: owner ?? this.owner,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      dueLabel: dueLabel ?? this.dueLabel,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kind': kind.name,
      'title': title,
      'subtitle': subtitle,
      'owner': owner,
      'status': status,
      'priority': priority,
      'dueLabel': dueLabel,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static OpsRecord fromJson(Map<String, dynamic> json) {
    return OpsRecord(
      id: json['id'] as String,
      kind: RecordKind.values.firstWhere(
        (kind) => kind.name == json['kind'],
        orElse: () => RecordKind.task,
      ),
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      owner: json['owner'] as String? ?? '',
      status: json['status'] as String? ?? 'Open',
      priority: json['priority'] as String? ?? 'Normal',
      dueLabel: json['dueLabel'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class OperationsRepository {
  OperationsRepository({required this.screenshotMode});

  static const _recordsKey = 'valat_rene_records_v1';
  final bool screenshotMode;

  Future<List<OpsRecord>> loadRecords() async {
    if (screenshotMode) {
      return _sampleRecords();
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recordsKey);
    if (raw == null || raw.isEmpty) {
      return _starterRecords();
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(OpsRecord.fromJson)
        .toList();
  }

  Future<void> saveRecords(List<OpsRecord> records) async {
    if (screenshotMode) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(records.map((record) => record.toJson()).toList());
    await prefs.setString(_recordsKey, raw);
  }

  Future<void> clearRecords() async {
    if (screenshotMode) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recordsKey);
  }
}

class OperationsShell extends StatefulWidget {
  const OperationsShell({super.key, required this.repository});

  final OperationsRepository repository;

  @override
  State<OperationsShell> createState() => _OperationsShellState();
}

class _OperationsShellState extends State<OperationsShell> {
  late Future<void> _loading;
  final List<OpsRecord> _records = [];
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _loading = _load();
  }

  Future<void> _load() async {
    final loaded = await widget.repository.loadRecords();
    _records
      ..clear()
      ..addAll(loaded);
  }

  Future<void> _save() async {
    await widget.repository.saveRecords(_records);
  }

  Future<void> _clear() async {
    await widget.repository.clearRecords();
    setState(_records.clear);
  }

  Future<void> _openEditor(RecordKind kind, {OpsRecord? initial}) async {
    final result = await showModalBottomSheet<OpsRecord>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => RecordEditor(kind: kind, initial: initial),
    );
    if (result == null) {
      return;
    }
    setState(() {
      final index = _records.indexWhere((record) => record.id == result.id);
      if (index == -1) {
        _records.insert(0, result);
      } else {
        _records[index] = result;
      }
    });
    await _save();
  }

  void _openDetail(OpsRecord record) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => RecordDetailScreen(
          record: record,
          onEdit: () => _openEditor(record.kind, initial: record),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final pages = [
          DashboardScreen(
            records: _records,
            onSelectIndex: (index) => setState(() => _index = index),
            onCreate: _openEditor,
            onOpenDetail: _openDetail,
          ),
          RecordListScreen(
            title: 'Task board',
            description: 'Prioritize daily work, owners, and due windows.',
            records: _records
                .where((record) => record.kind == RecordKind.task)
                .toList(),
            emptyLabel: 'No tasks yet',
            kind: RecordKind.task,
            onCreate: () => _openEditor(RecordKind.task),
            onOpenDetail: _openDetail,
          ),
          LogisticsScreen(
            records: _records,
            onCreate: _openEditor,
            onOpenDetail: _openDetail,
          ),
          RecordListScreen(
            title: 'Team attendance',
            description: 'Track arrivals, coverage, and shift exceptions.',
            records: _records
                .where((record) => record.kind == RecordKind.attendance)
                .toList(),
            emptyLabel: 'No attendance logs yet',
            kind: RecordKind.attendance,
            onCreate: () => _openEditor(RecordKind.attendance),
            onOpenDetail: _openDetail,
          ),
          SettingsScreen(
            recordCount: _records.length,
            onClear: _clear,
            onCreate: _openEditor,
          ),
        ];

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 20,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'VALAT RENE',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  _appBarSubtitle(_index),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF607084),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          body: pages[_index],
          floatingActionButton: _index == 4
              ? null
              : FloatingActionButton.extended(
                  key: const ValueKey('create-record'),
                  onPressed: () => _openEditor(_kindForIndex(_index)),
                  icon: const Icon(Icons.add),
                  label: Text('New ${_kindForIndex(_index).singular}'),
                ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (index) => setState(() => _index = index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.checklist_outlined),
                selectedIcon: Icon(Icons.checklist),
                label: 'Tasks',
              ),
              NavigationDestination(
                icon: Icon(Icons.warehouse_outlined),
                selectedIcon: Icon(Icons.warehouse),
                label: 'Logistics',
              ),
              NavigationDestination(
                icon: Icon(Icons.groups_outlined),
                selectedIcon: Icon(Icons.groups),
                label: 'Team',
              ),
              NavigationDestination(
                icon: Icon(Icons.tune_outlined),
                selectedIcon: Icon(Icons.tune),
                label: 'Settings',
              ),
            ],
          ),
        );
      },
    );
  }

  String _appBarSubtitle(int index) {
    return switch (index) {
      0 => 'Daily operations command center',
      1 => 'Task ownership and status',
      2 => 'Containers and supply orders',
      3 => 'Shift attendance tracking',
      _ => 'Local controls and privacy',
    };
  }

  RecordKind _kindForIndex(int index) {
    return switch (index) {
      1 => RecordKind.task,
      2 => RecordKind.container,
      3 => RecordKind.attendance,
      _ => RecordKind.task,
    };
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.records,
    required this.onSelectIndex,
    required this.onCreate,
    required this.onOpenDetail,
  });

  final List<OpsRecord> records;
  final ValueChanged<int> onSelectIndex;
  final void Function(RecordKind kind, {OpsRecord? initial}) onCreate;
  final ValueChanged<OpsRecord> onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final dueNow = records
        .where((record) => record.priority == 'High' || record.status == 'Due')
        .length;
    final openTasks = records
        .where(
          (record) =>
              record.kind == RecordKind.task && record.status != 'Closed',
        )
        .length;
    final movingContainers = records
        .where(
          (record) =>
              record.kind == RecordKind.container && record.status != 'Cleared',
        )
        .length;
    final presentTeam = records
        .where(
          (record) =>
              record.kind == RecordKind.attendance &&
              record.status.contains('Present'),
        )
        .length;

    final recent = records.take(4).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        _HeroPanel(
          dueNow: dueNow,
          onTask: () => onCreate(RecordKind.task),
          onSupply: () => onCreate(RecordKind.supply),
        ),
        const SizedBox(height: 16),
        MetricsGrid(
          metrics: [
            MetricData(
              label: 'Open tasks',
              value: openTasks.toString(),
              icon: Icons.task_alt_rounded,
              color: RecordKind.task.accent,
            ),
            MetricData(
              label: 'Containers',
              value: movingContainers.toString(),
              icon: Icons.inventory_2_outlined,
              color: RecordKind.container.accent,
            ),
            MetricData(
              label: 'Team present',
              value: presentTeam.toString(),
              icon: Icons.badge_outlined,
              color: RecordKind.attendance.accent,
            ),
            MetricData(
              label: 'Priority items',
              value: dueNow.toString(),
              icon: Icons.priority_high_rounded,
              color: RecordKind.supply.accent,
            ),
          ],
        ),
        const SizedBox(height: 18),
        SectionHeader(
          title: 'Work queues',
          actionLabel: 'View tasks',
          onAction: () => onSelectIndex(1),
        ),
        const SizedBox(height: 8),
        _QueueShortcuts(onSelectIndex: onSelectIndex),
        const SizedBox(height: 18),
        SectionHeader(
          title: 'Recent activity',
          actionLabel: 'Logistics',
          onAction: () => onSelectIndex(2),
        ),
        const SizedBox(height: 8),
        if (recent.isEmpty)
          const EmptyState(
            icon: Icons.inbox_outlined,
            title: 'No records yet',
            body: 'Create the first task, container, order, or attendance log.',
          )
        else
          ...recent.map(
            (record) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: RecordCard(
                record: record,
                onTap: () => onOpenDetail(record),
              ),
            ),
          ),
      ],
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.dueNow,
    required this.onTask,
    required this.onSupply,
  });

  final int dueNow;
  final VoidCallback onTask;
  final VoidCallback onSupply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF071B3A),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.account_tree_outlined,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Today needs $dueNow priority checks before close.',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Plan field tasks, track container movement, request supplies, and keep shift attendance in one local workspace.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFFDCE6F2),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: onTask,
                icon: const Icon(Icons.add_task),
                label: const Text('Add task'),
              ),
              OutlinedButton.icon(
                onPressed: onSupply,
                icon: const Icon(Icons.playlist_add),
                label: const Text('Order supply'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QueueShortcuts extends StatelessWidget {
  const _QueueShortcuts({required this.onSelectIndex});

  final ValueChanged<int> onSelectIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ShortcutTile(
            label: 'Tasks',
            icon: Icons.checklist,
            color: RecordKind.task.accent,
            onTap: () => onSelectIndex(1),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ShortcutTile(
            label: 'Logistics',
            icon: Icons.warehouse,
            color: RecordKind.container.accent,
            onTap: () => onSelectIndex(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ShortcutTile(
            label: 'Team',
            icon: Icons.groups,
            color: RecordKind.attendance.accent,
            onTap: () => onSelectIndex(3),
          ),
        ),
      ],
    );
  }
}

class ShortcutTile extends StatelessWidget {
  const ShortcutTile({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Ink(
        height: 92,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFDDE5EF)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class LogisticsScreen extends StatelessWidget {
  const LogisticsScreen({
    super.key,
    required this.records,
    required this.onCreate,
    required this.onOpenDetail,
  });

  final List<OpsRecord> records;
  final void Function(RecordKind kind, {OpsRecord? initial}) onCreate;
  final ValueChanged<OpsRecord> onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final containers = records
        .where((record) => record.kind == RecordKind.container)
        .toList();
    final supplies = records
        .where((record) => record.kind == RecordKind.supply)
        .toList();

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              child: const TabBar(
                tabs: [
                  Tab(
                    icon: Icon(Icons.inventory_2_outlined),
                    text: 'Containers',
                  ),
                  Tab(
                    icon: Icon(Icons.local_shipping_outlined),
                    text: 'Supplies',
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                RecordListBody(
                  records: containers,
                  emptyLabel: 'No containers yet',
                  kind: RecordKind.container,
                  onCreate: () => onCreate(RecordKind.container),
                  onOpenDetail: onOpenDetail,
                ),
                RecordListBody(
                  records: supplies,
                  emptyLabel: 'No supply orders yet',
                  kind: RecordKind.supply,
                  onCreate: () => onCreate(RecordKind.supply),
                  onOpenDetail: onOpenDetail,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RecordListScreen extends StatelessWidget {
  const RecordListScreen({
    super.key,
    required this.title,
    required this.description,
    required this.records,
    required this.emptyLabel,
    required this.kind,
    required this.onCreate,
    required this.onOpenDetail,
  });

  final String title;
  final String description;
  final List<OpsRecord> records;
  final String emptyLabel;
  final RecordKind kind;
  final VoidCallback onCreate;
  final ValueChanged<OpsRecord> onOpenDetail;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: _ListIntro(title: title, description: description, kind: kind),
        ),
        Expanded(
          child: RecordListBody(
            records: records,
            emptyLabel: emptyLabel,
            kind: kind,
            onCreate: onCreate,
            onOpenDetail: onOpenDetail,
          ),
        ),
      ],
    );
  }
}

class _ListIntro extends StatelessWidget {
  const _ListIntro({
    required this.title,
    required this.description,
    required this.kind,
  });

  final String title;
  final String description;
  final RecordKind kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE5EF)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: kind.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(kind.icon, color: kind.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF607084),
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

class RecordListBody extends StatelessWidget {
  const RecordListBody({
    super.key,
    required this.records,
    required this.emptyLabel,
    required this.kind,
    required this.onCreate,
    required this.onOpenDetail,
  });

  final List<OpsRecord> records;
  final String emptyLabel;
  final RecordKind kind;
  final VoidCallback onCreate;
  final ValueChanged<OpsRecord> onOpenDetail;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: EmptyState(
          icon: kind.icon,
          title: emptyLabel,
          body: 'Create a ${kind.singular} and it will stay on this device.',
          actionLabel: 'Create',
          onAction: onCreate,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      itemCount: records.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final record = records[index];
        return RecordCard(record: record, onTap: () => onOpenDetail(record));
      },
    );
  }
}

class RecordCard extends StatelessWidget {
  const RecordCard({super.key, required this.record, required this.onTap});

  final OpsRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: record.kind.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(record.kind.icon, color: record.kind.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          record.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF607084),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusPill(label: record.status, color: record.kind.accent),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  InfoChip(
                    icon: Icons.person_outline,
                    label: record.owner.isEmpty ? 'Unassigned' : record.owner,
                  ),
                  InfoChip(icon: Icons.flag_outlined, label: record.priority),
                  InfoChip(icon: Icons.schedule, label: record.dueLabel),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RecordDetailScreen extends StatelessWidget {
  const RecordDetailScreen({
    super.key,
    required this.record,
    required this.onEdit,
  });

  final OpsRecord record;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(record.kind.label),
        actions: [
          IconButton(
            tooltip: 'Edit',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: record.kind.accent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(record.kind.icon, color: Colors.white, size: 34),
                const SizedBox(height: 16),
                Text(
                  record.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  record.subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          DetailRow(label: 'Status', value: record.status),
          DetailRow(label: 'Owner', value: record.owner),
          DetailRow(label: 'Priority', value: record.priority),
          DetailRow(label: 'Due window', value: record.dueLabel),
          DetailRow(label: 'Record type', value: record.kind.singular),
          const SizedBox(height: 14),
          Text(
            'Notes',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            record.notes.isEmpty ? 'No notes added.' : record.notes,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }
}

class DetailRow extends StatelessWidget {
  const DetailRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE5EF)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF607084),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value.isEmpty ? 'Not set' : value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class RecordEditor extends StatefulWidget {
  const RecordEditor({super.key, required this.kind, this.initial});

  final RecordKind kind;
  final OpsRecord? initial;

  @override
  State<RecordEditor> createState() => _RecordEditorState();
}

class _RecordEditorState extends State<RecordEditor> {
  late final TextEditingController _title;
  late final TextEditingController _subtitle;
  late final TextEditingController _owner;
  late final TextEditingController _due;
  late final TextEditingController _notes;
  late String _status;
  late String _priority;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    final defaults = _defaultsFor(widget.kind);
    _title = TextEditingController(text: initial?.title ?? defaults.title);
    _subtitle = TextEditingController(
      text: initial?.subtitle ?? defaults.subtitle,
    );
    _owner = TextEditingController(text: initial?.owner ?? defaults.owner);
    _due = TextEditingController(text: initial?.dueLabel ?? defaults.dueLabel);
    _notes = TextEditingController(text: initial?.notes ?? defaults.notes);
    _status = initial?.status ?? defaults.status;
    _priority = initial?.priority ?? defaults.priority;
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _owner.dispose();
    _due.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(widget.kind.icon, color: widget.kind.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.initial == null
                        ? 'New ${widget.kind.singular}'
                        : 'Edit ${widget.kind.singular}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('record-title-field'),
              controller: _title,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: _titleLabel(widget.kind)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _subtitle,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: _subtitleLabel(widget.kind),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _owner,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Owner or team'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _due,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Due window'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _status,
              items: _statusesFor(widget.kind)
                  .map(
                    (status) =>
                        DropdownMenuItem(value: status, child: Text(status)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _status = value ?? _status),
              decoration: const InputDecoration(labelText: 'Status'),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Low', label: Text('Low')),
                ButtonSegment(value: 'Normal', label: Text('Normal')),
                ButtonSegment(value: 'High', label: Text('High')),
              ],
              selected: {_priority},
              onSelectionChanged: (values) {
                setState(() => _priority = values.first);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              minLines: 3,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('save-record-button'),
                onPressed: _submit,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save record'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      return;
    }

    final initial = widget.initial;
    final record = OpsRecord(
      id:
          initial?.id ??
          DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      kind: widget.kind,
      title: title,
      subtitle: _subtitle.text.trim(),
      owner: _owner.text.trim(),
      status: _status,
      priority: _priority,
      dueLabel: _due.text.trim(),
      notes: _notes.text.trim(),
      createdAt: initial?.createdAt ?? DateTime.now(),
    );
    Navigator.of(context).pop(record);
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.recordCount,
    required this.onClear,
    required this.onCreate,
  });

  final int recordCount;
  final VoidCallback onClear;
  final void Function(RecordKind kind, {OpsRecord? initial}) onCreate;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFDDE5EF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF071B3A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text(
                        'VR',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VALAT RENE',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          'Local operations workspace',
                          style: TextStyle(color: Color(0xFF607084)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                '$recordCount records saved on this device',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'The app does not require sign in, network sync, analytics, location, contacts, camera, microphone, or notification access.',
                style: TextStyle(color: Color(0xFF607084), height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SettingsTile(
          icon: Icons.task_alt_rounded,
          title: 'Create task',
          body: 'Assign a daily work item with owner and due window.',
          onTap: () => onCreate(RecordKind.task),
        ),
        SettingsTile(
          icon: Icons.inventory_2_outlined,
          title: 'Track container',
          body: 'Record container status, reference, and responsible team.',
          onTap: () => onCreate(RecordKind.container),
        ),
        SettingsTile(
          icon: Icons.local_shipping_outlined,
          title: 'Order supplies',
          body: 'Capture requested materials and approval status locally.',
          onTap: () => onCreate(RecordKind.supply),
        ),
        SettingsTile(
          icon: Icons.delete_outline,
          title: 'Clear local records',
          body: 'Remove saved operations records from this device.',
          onTap: onClear,
          destructive: true,
        ),
      ],
    );
  }
}

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? const Color(0xFFB3261E)
        : const Color(0xFF071B3A);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: color),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(body),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class MetricsGrid extends StatelessWidget {
  const MetricsGrid({super.key, required this.metrics});

  final List<MetricData> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 520;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: twoColumns ? 4 : 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: twoColumns ? 1.45 : 1.35,
          ),
          itemBuilder: (context, index) => MetricCard(data: metrics[index]),
        );
      },
    );
  }
}

class MetricData {
  const MetricData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class MetricCard extends StatelessWidget {
  const MetricCard({super.key, required this.data});

  final MetricData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE5EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(data.icon, color: data.color),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF071B3A),
                ),
              ),
              Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF607084),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class InfoChip extends StatelessWidget {
  const InfoChip({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6FA),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF607084)),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF36475A),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE5EF)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: const Color(0xFF607084)),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF607084), height: 1.35),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

_RecordDefaults _defaultsFor(RecordKind kind) {
  return switch (kind) {
    RecordKind.task => const _RecordDefaults(
      title: 'Yard safety inspection',
      subtitle: 'North loading zone',
      owner: 'Operations team',
      status: 'Open',
      priority: 'High',
      dueLabel: 'Today 16:00',
      notes: 'Verify signage, access paths, and handover notes.',
    ),
    RecordKind.container => const _RecordDefaults(
      title: 'CNT-4582 arrival check',
      subtitle: 'Gate 3 inbound container',
      owner: 'Logistics desk',
      status: 'Arrived',
      priority: 'Normal',
      dueLabel: 'Today 14:30',
      notes: 'Confirm seal reference and unload bay availability.',
    ),
    RecordKind.supply => const _RecordDefaults(
      title: 'Pallet wrap request',
      subtitle: 'Warehouse consumables',
      owner: 'Supply lead',
      status: 'Requested',
      priority: 'Normal',
      dueLabel: 'Tomorrow',
      notes: 'Add to next supply pickup with gloves and labels.',
    ),
    RecordKind.attendance => const _RecordDefaults(
      title: 'Morning shift coverage',
      subtitle: 'Main floor team',
      owner: 'Shift lead',
      status: 'Present',
      priority: 'Normal',
      dueLabel: 'Today',
      notes: 'Two team members assigned to container receiving.',
    ),
  };
}

List<String> _statusesFor(RecordKind kind) {
  return switch (kind) {
    RecordKind.task => ['Open', 'In progress', 'Due', 'Closed'],
    RecordKind.container => ['Expected', 'Arrived', 'In unload', 'Cleared'],
    RecordKind.supply => ['Requested', 'Approved', 'Ordered', 'Received'],
    RecordKind.attendance => ['Present', 'Late', 'Absent', 'On leave'],
  };
}

String _titleLabel(RecordKind kind) {
  return switch (kind) {
    RecordKind.task => 'Task name',
    RecordKind.container => 'Container reference',
    RecordKind.supply => 'Supply request',
    RecordKind.attendance => 'Shift or employee',
  };
}

String _subtitleLabel(RecordKind kind) {
  return switch (kind) {
    RecordKind.task => 'Location or workstream',
    RecordKind.container => 'Gate, bay, or route',
    RecordKind.supply => 'Category or vendor',
    RecordKind.attendance => 'Team or role',
  };
}

class _RecordDefaults {
  const _RecordDefaults({
    required this.title,
    required this.subtitle,
    required this.owner,
    required this.status,
    required this.priority,
    required this.dueLabel,
    required this.notes,
  });

  final String title;
  final String subtitle;
  final String owner;
  final String status;
  final String priority;
  final String dueLabel;
  final String notes;
}

List<OpsRecord> _starterRecords() {
  return [
    _record(
      kind: RecordKind.task,
      title: 'Morning yard review',
      subtitle: 'Main entry and dispatch desk',
      owner: 'Ops lead',
      status: 'Open',
      priority: 'Normal',
      dueLabel: 'Today',
      notes: 'Check overnight handover notes and assign follow ups.',
    ),
    _record(
      kind: RecordKind.attendance,
      title: 'Main floor shift',
      subtitle: 'Receiving and dispatch',
      owner: 'Shift lead',
      status: 'Present',
      priority: 'Normal',
      dueLabel: 'Today',
      notes: 'Use this area to keep local shift coverage notes.',
    ),
  ];
}

List<OpsRecord> _sampleRecords() {
  return [
    _record(
      kind: RecordKind.task,
      title: 'Inspect gate 2 loading lane',
      subtitle: 'Safety check before afternoon dispatch',
      owner: 'Mina',
      status: 'In progress',
      priority: 'High',
      dueLabel: 'Today 13:30',
      notes: 'Confirm cones, dock plates, and handover photos are ready.',
    ),
    _record(
      kind: RecordKind.container,
      title: 'CNT-2048 customs hold',
      subtitle: 'Inbound textiles, bay 4',
      owner: 'Yassine',
      status: 'Arrived',
      priority: 'High',
      dueLabel: 'Today 15:00',
      notes: 'Waiting for seal verification before unloading begins.',
    ),
    _record(
      kind: RecordKind.supply,
      title: 'Barcode labels refill',
      subtitle: 'Packing station materials',
      owner: 'Nora',
      status: 'Approved',
      priority: 'Normal',
      dueLabel: 'Tomorrow',
      notes: 'Add two cartons of labels to the supply pickup.',
    ),
    _record(
      kind: RecordKind.attendance,
      title: 'Morning shift',
      subtitle: 'Warehouse floor team',
      owner: 'Shift desk',
      status: 'Present',
      priority: 'Normal',
      dueLabel: 'Today',
      notes: 'Eight present, one late arrival moved to receiving.',
    ),
    _record(
      kind: RecordKind.task,
      title: 'Prepare dispatch manifest',
      subtitle: 'Client route A7',
      owner: 'Samir',
      status: 'Open',
      priority: 'Normal',
      dueLabel: 'Today 17:00',
      notes: 'Match container references with final load sequence.',
    ),
    _record(
      kind: RecordKind.container,
      title: 'CNT-8821 outbound staging',
      subtitle: 'Export lane',
      owner: 'Hajar',
      status: 'In unload',
      priority: 'Normal',
      dueLabel: 'Today',
      notes: 'Staged for final check after pallet count.',
    ),
    _record(
      kind: RecordKind.supply,
      title: 'Protective gloves',
      subtitle: 'Warehouse consumables',
      owner: 'Nora',
      status: 'Requested',
      priority: 'High',
      dueLabel: 'Today',
      notes: 'Low stock at packing benches and receiving lane.',
    ),
    _record(
      kind: RecordKind.attendance,
      title: 'Receiving coverage',
      subtitle: 'Container unloading team',
      owner: 'Mina',
      status: 'Present',
      priority: 'Normal',
      dueLabel: 'Today',
      notes: 'Coverage confirmed for the afternoon delivery window.',
    ),
  ];
}

OpsRecord _record({
  required RecordKind kind,
  required String title,
  required String subtitle,
  required String owner,
  required String status,
  required String priority,
  required String dueLabel,
  required String notes,
}) {
  return OpsRecord(
    id: '${kind.name}-${title.hashCode.abs()}',
    kind: kind,
    title: title,
    subtitle: subtitle,
    owner: owner,
    status: status,
    priority: priority,
    dueLabel: dueLabel,
    notes: notes,
    createdAt: DateTime(2026, 5, 11, 8),
  );
}
