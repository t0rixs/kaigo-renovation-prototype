import 'dart:math' as math;

import 'package:flutter/material.dart';

class EditorToolButton extends StatelessWidget {
  const EditorToolButton({
    super.key,
    this.icon,
    this.iconWidget,
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
    this.color,
  });

  final IconData? icon;
  final Widget? iconWidget;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool enabled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? Theme.of(context).colorScheme.primary;
    final scheme = Theme.of(context).colorScheme;
    final scaledLabel = MediaQuery.textScalerOf(context).scale(11);
    final extraWidth = math.max(0, scaledLabel - 11) * 4;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Semantics(
        button: true,
        selected: selected,
        enabled: enabled,
        label: label,
        child: Tooltip(
          message: label,
          child: InkWell(
            borderRadius: BorderRadius.circular(7),
            onTap: enabled ? onTap : null,
            child: Opacity(
              opacity: enabled ? 1 : .35,
              child: Container(
                width: (66 + extraWidth).toDouble(),
                decoration: BoxDecoration(
                  color: selected
                      ? foreground.withValues(alpha: .12)
                      : Colors.transparent,
                  border: Border.all(
                    width: selected ? 1.5 : 1,
                    color: selected ? foreground : Colors.transparent,
                  ),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    iconWidget ??
                        Icon(
                          icon,
                          size: 22,
                          color: selected || color != null
                              ? foreground
                              : scheme.onSurfaceVariant,
                        ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: selected ? foreground : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
