import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../app/widgets/console_card.dart';
import '../../app/widgets/risk_style.dart';
import '../../core/models/alert_level.dart';
import '../../core/models/log_entry.dart';
import '../../core/utils/time_format.dart';
import '../../app/widgets/status_chip.dart';
import '../../layers/log/mission_log_controller.dart';
import '../../layers/security/security_service.dart';

/// Tab 4 — Mission Log: newest first, mono timestamps, filter chips,
/// expandable "why" on predictions, and JSON export.
class MissionLogScreen extends StatefulWidget {
  const MissionLogScreen({super.key});

  @override
  State<MissionLogScreen> createState() => _MissionLogScreenState();
}

class _MissionLogScreenState extends State<MissionLogScreen> {
  LogFilter _filter = LogFilter.all;

  @override
  Widget build(BuildContext context) {
    final log = context.watch<MissionLogController>();
    final entries = log.filtered(_filter);

    return CustomScrollView(
      key: const Key('logList'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            AppSpacing.screenPadding,
            AppSpacing.screenPadding,
            AppSpacing.sm,
          ),
          sliver: SliverToBoxAdapter(
            child: _Header(
              count: log.length,
              filter: _filter,
              onFilter: (f) => setState(() => _filter = f),
            ),
          ),
        ),
        if (entries.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            sliver: SliverToBoxAdapter(child: _EmptyState(filter: _filter)),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              0,
              AppSpacing.screenPadding,
              AppSpacing.lg,
            ),
            sliver: SliverList.separated(
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) =>
                  _EntryTile(key: ValueKey(entries[i].id), entry: entries[i]),
            ),
          ),
      ],
    );
  }
}

// --- Header: title, storage chip, export, filters ------------------------------

class _Header extends StatelessWidget {
  const _Header({
    required this.count,
    required this.filter,
    required this.onFilter,
  });

  final int count;
  final LogFilter filter;
  final ValueChanged<LogFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Everything the system saw and the astronaut did.',
                style: text.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            OutlinedButton.icon(
              key: const Key('exportLog'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: () => showExportDialog(context),
              icon: const Icon(Icons.data_object, size: 18),
              label: const Text('Export JSON'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        const LogStorageChip(),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            for (final f in LogFilter.values)
              ChoiceChip(
                key: Key('logFilter_${f.name}'),
                label: Text(f.label),
                selected: f == filter,
                showCheckmark: false,
                labelStyle: AppTypography.chip.copyWith(
                  color: f == filter
                      ? AppColors.primary
                      : AppColors.textPrimary,
                ),
                onSelected: (_) => onFilter(f),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '$count ENTRIES · NEWEST FIRST',
          style: AppTypography.consoleLabel,
        ),
      ],
    );
  }
}

/// Where the log is stored: "AES-256 · ON DEVICE" or "MEMORY ONLY".
class LogStorageChip extends StatelessWidget {
  const LogStorageChip({super.key});

  @override
  Widget build(BuildContext context) {
    final security = context.watch<SecurityService>();
    return StatusChip(
      key: const Key('logStorageChip'),
      icon: security.isEncrypted ? Icons.lock_outline : Icons.warning_amber,
      label: security.storageLabel,
      color: security.isEncrypted ? AppColors.normal : AppColors.warning,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});
  final LogFilter filter;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ConsoleCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.inbox_outlined, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              filter == LogFilter.all
                  ? 'No entries yet. Status changes, predictions, meals and '
                        'simulator events will appear here.'
                  : 'No ${filter.label.toLowerCase()} entries yet.',
              style: text.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

// --- One entry --------------------------------------------------------------------

/// Icon, color and label for an entry. Status is never color alone: the
/// tile always shows an icon AND a text label (e.g. "STATUS · WARNING").
({IconData icon, Color color, String label}) _styleOf(LogEntry e) {
  final levelName = e.data?['level'] as String?;
  final level = AlertLevel.values
      .where((l) => l.label == levelName)
      .firstOrNull;
  switch (e.type) {
    case LogEntryType.status:
    case LogEntryType.prediction:
      final l = level ?? AlertLevel.nominal;
      return (
        icon: RiskStyle.alertIcon(l),
        color: RiskStyle.alertColor(l),
        label: '${e.type.label.toUpperCase()} · ${l.label}',
      );
    case LogEntryType.meal:
      return (icon: Icons.restaurant, color: AppColors.info, label: 'MEAL');
    case LogEntryType.system:
      return (
        icon: Icons.settings_suggest_outlined,
        color: AppColors.textSecondary,
        label: 'SYSTEM · SIMULATOR',
      );
  }
}

class _EntryTile extends StatefulWidget {
  const _EntryTile({super.key, required this.entry});
  final LogEntry entry;

  @override
  State<_EntryTile> createState() => _EntryTileState();
}

class _EntryTileState extends State<_EntryTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final style = _styleOf(e);
    final text = Theme.of(context).textTheme;
    final why = (e.data?['why'] as List?)?.cast<String>() ?? const [];
    final canExpand = e.type == LogEntryType.prediction && why.isNotEmpty;

    return ConsoleCard(
      padding: const EdgeInsets.all(AppSpacing.sm + AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(style.icon, size: 20, color: style.color),
          const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        style.label,
                        style: AppTypography.consoleLabel.copyWith(
                          color: style.color,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      TimeFormat.clock(e.timestamp),
                      style: AppTypography.monoSmall,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(e.title, style: text.titleSmall),
                if (e.detail.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(e.detail, style: text.bodySmall),
                ],
                if (canExpand) ...[
                  TextButton.icon(
                    onPressed: () => setState(() => _open = !_open),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    iconAlignment: IconAlignment.end,
                    icon: Icon(
                      _open ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                    ),
                    label: const Text('Why?'),
                  ),
                  if (_open)
                    for (final reason in why)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 3),
                              child: Icon(
                                Icons.chevron_right,
                                size: 14,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(reason, style: text.bodySmall),
                            ),
                          ],
                        ),
                      ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Export ---------------------------------------------------------------------

/// Shows the whole log as pretty JSON with Copy and Close. Nothing leaves
/// the device: Copy only puts the text on the local clipboard.
Future<void> showExportDialog(BuildContext context) {
  final log = context.read<MissionLogController>();
  final json = const JsonEncoder.withIndent('  ')
      .convert(log.exportJson(storage: logStorageLabel(context)));
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        side: const BorderSide(color: AppColors.border),
      ),
      title: const Text('Mission Log · JSON'),
      content: SizedBox(
        width: double.maxFinite,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
            border: Border.all(color: AppColors.border),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              json,
              key: const Key('exportJsonText'),
              style: AppTypography.monoSmall.copyWith(
                color: AppColors.textPrimary,
                fontSize: 11,
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          key: const Key('copyExport'),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: json));
            if (!dialogContext.mounted) return;
            ScaffoldMessenger.of(dialogContext).showSnackBar(
              const SnackBar(content: Text('Log JSON copied to clipboard.')),
            );
          },
          icon: const Icon(Icons.copy, size: 18),
          label: const Text('Copy'),
        ),
        TextButton(
          key: const Key('closeExport'),
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

/// Storage description written into the export.
String logStorageLabel(BuildContext context) {
  final security = context.read<SecurityService>();
  return security.isEncrypted
      ? '${SecurityService.algorithm} encrypted, on device'
      : 'memory only (not saved)';
}
