import 'package:flutter/material.dart';

import '../models/check_item.dart';

class CheckItemCard extends StatelessWidget {
  const CheckItemCard({
    super.key,
    required this.item,
    required this.onStatusChanged,
    required this.onTap,
  });

  final TaskItem item;
  final ValueChanged<bool> onStatusChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(16);
    final colorScheme = Theme.of(context).colorScheme;
    final canSubmit = item.isPending || item.isRejected;
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      elevation: 0,
      color: colorScheme.surface,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusPill(
                    label: item.statusLabel,
                    status: item.status,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.projectName,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (canSubmit)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Switch.adaptive(
                          value: item.isSubmitted || item.isApproved,
                          onChanged: canSubmit ? onStatusChanged : null,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.isApproved
                              ? 'Готово'
                              : item.isSubmitted
                                  ? 'На проверке'
                                  : 'В работе',
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: item.isApproved
                                        ? Colors.green
                                        : colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        item.isApproved
                            ? 'Готово'
                            : item.isSubmitted
                                ? 'На проверке'
                                : 'В работе',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: item.isApproved
                                      ? Colors.green
                                      : colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Обновлено ${_formatDate(item.updatedAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hours = date.hour.toString().padLeft(2, '0');
    final minutes = date.minute.toString().padLeft(2, '0');
    return '$day.$month.${date.year} $hours:$minutes';
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.status});

  final String label;
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'approved' || 'qa_approved' || 'final_approved' => Colors.green,
      'submitted' => Colors.blue,
      'rejected' || 'qa_rejected' => Colors.red,
      'sent_to_qa' => Colors.blueGrey,
      'draft' => Colors.grey,
      _ => Colors.orange,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
