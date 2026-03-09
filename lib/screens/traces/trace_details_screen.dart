import 'package:flutter/material.dart';
import 'package:tracely/screens/traces/trace_timeline_screen.dart';
import 'package:tracely/screens/traces/request_response_viewer.dart';
import 'package:tracely/services/api_service.dart';

class TraceDetailsScreen extends StatefulWidget {
  final dynamic trace;

  const TraceDetailsScreen({super.key, required this.trace});

  @override
  State<TraceDetailsScreen> createState() => _TraceDetailsScreenState();
}

class _TraceDetailsScreenState extends State<TraceDetailsScreen> {
  Map<String, dynamic>? _details;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get workspace ID — trace already carries it or we fetch workspaces
      final workspaces = await ApiService().getWorkspaces();
      if (!mounted || workspaces.isEmpty) return;
      final wsId =
          (workspaces.first as Map<String, dynamic>)['id']?.toString() ?? '';
      final traceId = widget.trace.traceId.toString();

      final data = await ApiService().getTraceDetails(wsId, traceId);
      if (mounted) {
        setState(() {
          _details = data;
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
    final method = widget.trace.method;
    final path = widget.trace.path;
    final status = widget.trace.status as int;
    final duration = widget.trace.durationMs;

    // Build request/response display from real span data
    String requestData = 'No captured request body';
    String responseData = 'No captured response body';

    if (_details != null) {
      final spans = (_details!['spans'] ?? []) as List<dynamic>;
      if (spans.isNotEmpty) {
        final firstSpan = spans.first as Map<String, dynamic>;
        final tags = firstSpan['tags'] ?? '{}';
        requestData =
            '{\n  "method": "$method",\n  "url": "$path",\n  "tags": $tags\n}';
        responseData =
            '{\n  "status_code": $status,\n  "duration_ms": ${duration.toStringAsFixed(0)},\n  "service": "${_details!['service_name'] ?? 'unknown'}"\n}';
      }
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Trace Details'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Timeline'),
              Tab(text: 'Request'),
              Tab(text: 'Response'),
            ],
          ),
        ),
        body: Column(
          children: [
            _MetadataSection(
              method: method,
              path: path,
              status: status,
              duration: duration,
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : TabBarView(
                          children: [
                            TraceTimelineScreen(
                              trace: widget.trace,
                              spans: (_details?['spans'] ?? [])
                                  as List<dynamic>,
                            ),
                            RequestResponseViewer(data: requestData),
                            RequestResponseViewer(data: responseData),
                          ],
                        ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _QuickActionChip(icon: Icons.replay, label: 'Replay'),
                _QuickActionChip(
                    icon: Icons.smart_toy, label: 'Replay with mocks'),
                _QuickActionChip(icon: Icons.code, label: 'Copy as cURL'),
                _QuickActionChip(
                    icon: Icons.share, label: 'Share trace link'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetadataSection extends StatelessWidget {
  final String method;
  final String path;
  final int status;
  final double duration;

  const _MetadataSection({
    required this.method,
    required this.path,
    required this.status,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = status >= 500
        ? Colors.red
        : status >= 400
            ? Colors.orange
            : status > 0
                ? Colors.green
                : Colors.grey;
    final statusText = status > 0 ? '$status' : 'N/A';

    return Container(
      padding: const EdgeInsets.all(16),
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Badge(text: method, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(path,
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _Badge(text: statusText, color: statusColor),
              const SizedBox(width: 8),
              Text('${duration.toStringAsFixed(0)}ms',
                  style: theme.textTheme.bodyMedium),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _QuickActionChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar:
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
      label: Text(label),
      onPressed: () {},
    );
  }
}
