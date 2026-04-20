import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

// ─── Gradient Button ──────────────────────────────────────────────────────────
class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final LinearGradient? gradient;
  final double height;
  final double? width;

  const GradientButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.gradient,
    this.height = 52,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        width: width ?? double.infinity,
        decoration: BoxDecoration(
          gradient: gradient ?? AppTheme.greenGradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Score Button (run buttons) ───────────────────────────────────────────────
class ScoreButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final Color? textColor;
  final bool isActive;
  final double size;

  const ScoreButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color,
    this.textColor,
    this.isActive = false,
    this.size = 60,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isActive
              ? (color ?? AppTheme.primary)
              : (color ?? AppTheme.bgSurface),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? (color ?? AppTheme.primary)
                : AppTheme.borderColor,
            width: isActive ? 2 : 1,
          ),
          boxShadow: isActive
              ? [
            BoxShadow(
              color: (color ?? AppTheme.primary).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : (textColor ?? AppTheme.textPrimary),
              fontWeight: FontWeight.w700,
              fontSize: size > 50 ? 18 : 13,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            gradient: AppTheme.greenGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// ─── Extra Toggle Button ──────────────────────────────────────────────────────
class ExtraToggle extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color activeColor;

  const ExtraToggle({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.2) : AppTheme.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? activeColor : AppTheme.borderColor,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? activeColor : AppTheme.textSecondary,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ─── Player Selector Dialog ───────────────────────────────────────────────────
class PlayerSelectorDialog extends StatelessWidget {
  final String title;
  final List<String> players;
  final Function(String) onSelected;

  const PlayerSelectorDialog({
    super.key,
    required this.title,
    required this.players,
    required this.onSelected,
  });

  static Future<String?> show(
      BuildContext context, {
        required String title,
        required List<String> players,
      }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => PlayerSelectorDialog(
        title: title,
        players: players,
        onSelected: (name) => Navigator.of(ctx).pop(name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            if (players.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No players available',
                    style: TextStyle(color: AppTheme.textSecondary)),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: players.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) => ListTile(
                    dense: true,
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: AppTheme.greenGradient,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          players[i].substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    title: Text(players[i],
                        style: const TextStyle(color: AppTheme.textPrimary)),
                    onTap: () => onSelected(players[i]),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Player Search + Add Picker ───────────────────────────────────────────────
//
// Unified picker for batsman / bowler selection.
//   • Top text field filters the existing list as you type
//   • If the typed name is not in the list, an Add button creates a new
//     player via the provided callback and returns it
//   • Tapping any filtered list row selects that player
//
// Generic over T — pass a list of items and functions to extract the display
// name and an optional subtitle. On select / add the dialog pops with the
// picked item (T). For "add new" cases, the caller's [onAddNew] must return
// a new T (the newly created player) which will then be popped.
class PlayerSearchPickerDialog<T> extends StatefulWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color accent;
  final List<T> items;
  final String Function(T) labelOf;
  final String? Function(T)? subtitleOf;
  final Future<T?> Function(String name) onAddNew;

  const PlayerSearchPickerDialog({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.person_rounded,
    this.accent = AppTheme.primary,
    required this.items,
    required this.labelOf,
    this.subtitleOf,
    required this.onAddNew,
  });

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    String? subtitle,
    IconData icon = Icons.person_rounded,
    Color accent = AppTheme.primary,
    required List<T> items,
    required String Function(T) labelOf,
    String? Function(T)? subtitleOf,
    required Future<T?> Function(String name) onAddNew,
  }) {
    return showDialog<T>(
      context: context,
      builder: (ctx) => PlayerSearchPickerDialog<T>(
        title: title,
        subtitle: subtitle,
        icon: icon,
        accent: accent,
        items: items,
        labelOf: labelOf,
        subtitleOf: subtitleOf,
        onAddNew: onAddNew,
      ),
    );
  }

  @override
  State<PlayerSearchPickerDialog<T>> createState() =>
      _PlayerSearchPickerDialogState<T>();
}

class _PlayerSearchPickerDialogState<T>
    extends State<PlayerSearchPickerDialog<T>> {
  final TextEditingController _ctrl = TextEditingController();
  String _query = '';
  bool _adding = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<T> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.items;
    return widget.items
        .where((e) => widget.labelOf(e).toLowerCase().contains(q))
        .toList();
  }

  bool get _exactMatchExists {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return false;
    return widget.items.any((e) => widget.labelOf(e).toLowerCase() == q);
  }

  Future<void> _addNew() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty || _exactMatchExists || _adding) return;
    setState(() => _adding = true);
    try {
      final created = await widget.onAddNew(name);
      if (!mounted) return;
      if (created != null) Navigator.of(context).pop(created);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final canAdd = _query.trim().isNotEmpty && !_exactMatchExists && !_adding;
    final mq = MediaQuery.of(context);
    // Dialog internally adds viewInsets.bottom via AnimatedPadding, so don't
    // add it again to insetPadding. Just cap our own content height so the
    // list still renders when the keyboard is open.
    final double available = mq.size.height - mq.viewInsets.bottom - 96;
    final double maxDialogHeight = available > 260 ? available : 260;

    return Dialog(
      backgroundColor: AppTheme.bgCard,
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: widget.accent.withOpacity(0.6), width: 1.2),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxDialogHeight),
        child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Row(
              children: [
                Icon(widget.icon, color: widget.accent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (widget.subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            widget.subtitle!,
                            style: TextStyle(
                              color: widget.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppTheme.textSecondary, size: 20),
                  onPressed: () => Navigator.of(context).pop(null),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Search + Add row ─────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Type player name',
                      hintStyle:
                          const TextStyle(color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: AppTheme.bgSurface,
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: AppTheme.textSecondary, size: 20),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppTheme.borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppTheme.borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            BorderSide(color: widget.accent, width: 1.2),
                      ),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                    onSubmitted: (_) => canAdd ? _addNew() : null,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: canAdd ? _addNew : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.accent,
                      disabledBackgroundColor:
                          AppTheme.bgSurface.withOpacity(0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    icon: _adding
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.add_rounded,
                            color: Colors.white, size: 18),
                    label: const Text('Add',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1, color: AppTheme.borderColor),
            const SizedBox(height: 10),

            // ── Filtered list ────────────────────────────────────────────
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppTheme.textSecondary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _query.isEmpty
                            ? 'No players yet — add one above'
                            : 'No match. Tap Add to create "${_ctrl.text.trim()}"',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                fit: FlexFit.loose,
                child: Scrollbar(
                  child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (ctx, i) {
                    final item = filtered[i];
                    final label = widget.labelOf(item);
                    final sub = widget.subtitleOf?.call(item);
                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => Navigator.of(ctx).pop(item),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.bgSurface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: widget.accent.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  label.isNotEmpty
                                      ? label[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: widget.accent,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    label,
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (sub != null && sub.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        sub,
                                        style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded,
                                color: AppTheme.textSecondary, size: 20),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }
}

// ─── Wicket Dialog ────────────────────────────────────────────────────────────
class WicketDialog extends StatefulWidget {
  final List<String> battingPlayers;
  final List<String> fieldingPlayers;
  final Function(String wicketType, String? outPlayer, String? fielder, int runs) onConfirm;

  const WicketDialog({
    super.key,
    required this.battingPlayers,
    required this.fieldingPlayers,
    required this.onConfirm,
  });

  static Future<void> show(
      BuildContext context, {
        required List<String> battingPlayers,
        required List<String> fieldingPlayers,
        required Function(String wicketType, String? outPlayer, String? fielder, int runs) onConfirm,
      }) {
    return showDialog(
      context: context,
      builder: (ctx) => WicketDialog(
        battingPlayers: battingPlayers,
        fieldingPlayers: fieldingPlayers,
        onConfirm: (t, o, f, r) {
          Navigator.of(ctx).pop();
          onConfirm(t, o, f, r);
        },
      ),
    );
  }

  @override
  State<WicketDialog> createState() => _WicketDialogState();
}

class _WicketDialogState extends State<WicketDialog> {
  String? selectedType;
  String? selectedBatsman;
  String? selectedFielder;
  int runOutRuns = 0; // runs completed before the run-out

  final List<Map<String, dynamic>> wicketTypes = [
    {'label': 'Bowled', 'icon': Icons.sports_cricket},
    {'label': 'Caught', 'icon': Icons.back_hand},
    {'label': 'LBW', 'icon': Icons.sports_cricket},
    {'label': 'Run Out', 'icon': Icons.directions_run},
    {'label': 'Stumped', 'icon': Icons.sports_cricket},
    {'label': 'Hit Wicket', 'icon': Icons.sports_cricket},
  ];

  @override
  Widget build(BuildContext context) {
    final isRunOut = selectedType == 'Run Out';

    return Dialog(
      backgroundColor: AppTheme.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.error),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              children: [
                Icon(Icons.sports_cricket, color: AppTheme.error),
                SizedBox(width: 8),
                Text('Wicket',
                    style: TextStyle(
                        color: AppTheme.error,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 16),

            // Wicket type grid
            const Text('Dismissal Type',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: wicketTypes.map((wt) {
                final isSelected = selectedType == wt['label'];
                return GestureDetector(
                  onTap: () => setState(() {
                    selectedType = wt['label'] as String;
                    if (!isRunOut) runOutRuns = 0;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.error.withOpacity(0.2)
                          : AppTheme.bgSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? AppTheme.error : AppTheme.borderColor,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      wt['label'] as String,
                      style: TextStyle(
                        color: isSelected ? AppTheme.error : AppTheme.textSecondary,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // ── Run Out runs selector ────────────────────────────────────────
            if (isRunOut) ...[
              Row(
                children: [
                  const Text(
                    'Runs completed before run-out',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: AppTheme.warning.withOpacity(0.5)),
                    ),
                    child: Text(
                      '$runOutRuns run${runOutRuns == 1 ? '' : 's'}',
                      style: const TextStyle(
                          color: AppTheme.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [0, 1, 2, 3].map((r) {
                  final isSelected = runOutRuns == r;
                  return GestureDetector(
                    onTap: () => setState(() => runOutRuns = r),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      margin: const EdgeInsets.only(right: 8),
                      width: 52,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: isSelected ? AppTheme.greenGradient : null,
                        color: isSelected ? null : AppTheme.bgSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppTheme.primary : AppTheme.borderColor,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$r',
                              style: TextStyle(
                                color: isSelected ? Colors.white : AppTheme.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              r == 1 ? 'run' : 'runs',
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white70
                                    : AppTheme.textSecondary,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Out batsman (for run out, caught if non-striker)
            if (widget.battingPlayers.length > 1) ...[
              const Text('Out Batsman',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: selectedBatsman,
                dropdownColor: AppTheme.bgCard,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppTheme.bgSurface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.borderColor),
                  ),
                ),
                hint: const Text('Select batsman',
                    style: TextStyle(color: AppTheme.textSecondary)),
                items: widget.battingPlayers
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (v) => setState(() => selectedBatsman = v),
              ),
              const SizedBox(height: 12),
            ],

            // Fielder (for caught, run out, stumped)
            if (selectedType == 'Caught' ||
                selectedType == 'Run Out' ||
                selectedType == 'Stumped') ...[
              Text(
                selectedType == 'Caught'
                    ? 'Caught By'
                    : selectedType == 'Stumped'
                    ? 'Stumped By (WK)'
                    : 'Fielder / Thrower',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: selectedFielder,
                dropdownColor: AppTheme.bgCard,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppTheme.bgSurface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.borderColor),
                  ),
                ),
                hint: const Text('Select fielder',
                    style: TextStyle(color: AppTheme.textSecondary)),
                items: widget.fieldingPlayers
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (v) => setState(() => selectedFielder = v),
              ),
              const SizedBox(height: 12),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel',
                      style: TextStyle(color: AppTheme.textSecondary)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: selectedType == null
                      ? null
                      : () => widget.onConfirm(
                    selectedType!,
                    selectedBatsman,
                    selectedFielder,
                    isRunOut ? runOutRuns : 0,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Confirm Wicket'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}