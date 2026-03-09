import 'package:flutter/material.dart';

/// Displays a timeline of spans for a trace.
/// Receives real span data from the trace details API — no hardcoded values.
class TraceTimelineScreen extends StatefulWidget {
  final dynamic trace;
  final List<dynamic> spans;

  const TraceTimelineScreen({
    super.key,
    required this.trace,
    this.spans = const [],
  });

  @override
  State<TraceTimelineScreen> createState() => _TraceTimelineScreenState();
}

class _TraceTimelineScreenState extends State<TraceTimelineScreen> {
  int? _expandedIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.spans.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timeline, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('No spans captured for this trace',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    // Parse spans into display data
    final spanItems = widget.spans.map((s) {
      final m = s as Map<String, dynamic>;
      return _SpanData(
        service: m['service_name'] ?? 'unknown',
        operation: m['operation_name'] ?? 'unknown',
        durationMs: (m['duration_ms'] ?? 0).toDouble(),
        status: m['status'] ?? 'ok',
        tags: m['tags'] ?? '{}',
      );
    }).toList();

    final maxDuration = spanItems
        .map((s) => s.durationMs)
        .reduce((a, b) => a > b ? a : b);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: spanItems.length,
      itemBuilder: (context, i) {
        final span = spanItems[i];
        final isExpanded = _expandedIndex == i;
        final isSlowest = span.durationMs == maxDuration && spanItems.length > 1;

        return _TimelineSpan(
          span: span,
          isExpanded: isExpanded,
          isSlowest: isSlowest,
          maxDuration: maxDuration,
          onTap: () => setState(() => _expandedIndex = isExpanded ? null : i),
        );
      },
    );
  }
}

class _SpanData {
  final String service;
  final String operation;
  final double durationMs;
  final String status;
  final String tags;

  _SpanData({
    required this.service,
    required this.operation,
    required this.durationMs,
    required this.status,
    this.tags = '{}',
  });
}

class _TimelineSpan extends StatelessWidget {
  final _SpanData span;
  final bool isExpanded;
  final bool isSlowest;
  final double maxDuration;
  final VoidCallback onTap;

  const _TimelineSpan({
    required this.span,
    required this.isExpanded,
    required this.isSlowest,
    required this.maxDuration,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final barWidth = maxDuration > 0
        ? (span.durationMs / maxDuration).clamp(0.05, 1.0)
        : 0.5;
    final isError = span.status == 'error';
    final dotColor = isError
        ? Colors.red
        : isSlowest
            ? Colors.orange
            : theme.colorScheme.primary;

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                if (isExpanded)
                  Container(
                    width: 2,
                    height: 40,
                    color: theme.colorScheme.outline.withOpacity(0.3),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                span.service,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (isSlowest) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Slowest',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange,
                                  ),
                                ),
                              ),
                            ],
                            if (isError) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Error',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          span.operation,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: barWidth.toDouble(),
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                            color: isError
                                ? Colors.red
                                : isSlowest
                                    ? Colors.orange
                                    : theme.colorScheme.primary,
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${span.durationMs.toStringAsFixed(0)}ms',
                          style: theme.textTheme.labelSmall,
                        ),
                        if (isExpanded) ...[
                          const SizedBox(height: 12),
                          const Divider(),
                          Text(
                            'Service: ${span.service}',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Operation: ${span.operation}',
                            style: theme.textTheme.bodySmall,
                          ),
                          if (span.tags != '{}') ...[
                            const SizedBox(height: 4),
                            Text(
                              'Tags: ${span.tags}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
