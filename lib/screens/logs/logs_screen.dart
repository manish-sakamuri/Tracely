import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:tracely/services/api_service.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  String _severityFilter = 'All';
  List<dynamic> _logs = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await ApiService().getUserLogs(
        level: _severityFilter == 'All' ? null : _severityFilter,
      );
      if (mounted) {
        setState(() {
          _logs = (data['logs'] ?? []) as List<dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (v) {
              setState(() => _severityFilter = v);
              _fetchLogs();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'All', child: Text('All')),
              const PopupMenuItem(value: 'INFO', child: Text('INFO')),
              const PopupMenuItem(value: 'WARN', child: Text('WARN')),
              const PopupMenuItem(value: 'ERROR', child: Text('ERROR')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchLogs,
        child: _buildBody(theme),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchLogs, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_logs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.article_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('No logs yet — perform some actions to see activity',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _logs.length,
      itemBuilder: (context, i) {
        final log = _logs[i] as Map<String, dynamic>;
        // Parse metadata JSON safely
        Map<String, dynamic>? metadata;
        final rawMeta = log['metadata'];
        if (rawMeta != null && rawMeta is String && rawMeta.isNotEmpty && rawMeta != '{}') {
          try {
            metadata = json.decode(rawMeta) as Map<String, dynamic>;
          } catch (_) {}
        } else if (rawMeta is Map) {
          metadata = Map<String, dynamic>.from(rawMeta);
        }
        return _LogItem(
          severity: (log['level'] ?? 'INFO') as String,
          timestamp: (log['created_at'] ?? '') as String,
          message: (log['message'] ?? '') as String,
          metadata: metadata,
        );
      },
    );
  }
}

class _LogItem extends StatelessWidget {
  final String severity;
  final String timestamp;
  final String message;
  final Map<String, dynamic>? metadata;

  const _LogItem({
    required this.severity,
    required this.timestamp,
    required this.message,
    this.metadata,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (severity) {
      'ERROR' => Colors.red,
      'WARN' => Colors.amber,
      _ => Colors.blue,
    };

    // Format relative time
    String timeDisplay = timestamp;
    try {
      final dt = DateTime.parse(timestamp);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) {
        timeDisplay = 'Just now';
      } else if (diff.inMinutes < 60) {
        timeDisplay = '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        timeDisplay = '${diff.inHours}h ago';
      } else {
        timeDisplay = '${diff.inDays}d ago';
      }
    } catch (_) {}

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    severity,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        timeDisplay,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color:
                              theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(message, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
            // Metadata chips
            if (metadata != null && metadata!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: metadata!.entries
                    .where((e) =>
                        e.value != null &&
                        e.value.toString().isNotEmpty)
                    .map((e) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${e.key}: ${e.value}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontFamily: 'monospace',
                              fontSize: 10,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
