import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tracely/core/config/env_config.dart';
import 'package:tracely/services/api_service.dart';

enum HttpMethod { get, post, put, delete, patch }

class TestsScreen extends StatefulWidget {
  const TestsScreen({super.key});

  @override
  State<TestsScreen> createState() => _TestsScreenState();
}

class _TestsScreenState extends State<TestsScreen> {
  // Real test runs populated from backend (empty until backend supports it)
  final List<_TestRun> _runs = [];

  HttpMethod _method = HttpMethod.get;
  final _urlController =
      TextEditingController(text: '/health');
  final _bodyController = TextEditingController();
  bool _sending = false;
  String? _responseStatus;
  String? _responseBody;
  String? _responseError;

  @override
  void initState() {
    super.initState();
    _loadTestRuns();
  }

  Future<void> _loadTestRuns() async {
    try {
      final data = await ApiService().getTestRuns();
      final runs = (data['test_runs'] ?? []) as List<dynamic>;
      if (mounted) {
        setState(() {
          _runs.clear();
          for (final r in runs) {
            _runs.add(_TestRun(
              method: (r['method'] ?? 'GET') as String,
              url: (r['url'] ?? '') as String,
              statusCode: (r['status_code'] as num?)?.toInt() ?? 0,
              responseBody: (r['response_body'] ?? '') as String,
              id: (r['id'] ?? '') as String,
            ));
          }
        });
      }
    } catch (e) {
      debugPrint('[TestsScreen] Failed to load test runs: $e');
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  /// Build the final URL from user input.
  /// - If the input starts with '/', treat it as a path relative to BASE_URL.
  /// - If the input is a full URL (http:// or https://), use it as-is.
  String _buildUrl(String input) {
    if (input.startsWith('http://') || input.startsWith('https://')) {
      return input;
    }
    // Relative path — prepend BASE_URL
    final base = EnvConfig.baseUrl;
    // Avoid double slashes: if base ends with '/' and input starts with '/'
    if (base.endsWith('/') && input.startsWith('/')) {
      return '$base${input.substring(1)}';
    }
    if (!base.endsWith('/') && !input.startsWith('/')) {
      return '$base/$input';
    }
    return '$base$input';
  }

  /// Determine if the URL targets our own backend (needs auth header).
  bool _isBackendUrl(String url) {
    final base = EnvConfig.baseUrl;
    return url.startsWith(base);
  }

  Future<void> _sendRequest() async {
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) {
      setState(() {
        _responseError = 'Enter a URL or path (e.g. /health)';
        _responseStatus = null;
        _responseBody = null;
      });
      return;
    }

    setState(() {
      _sending = true;
      _responseError = null;
      _responseStatus = null;
      _responseBody = null;
    });

    try {
      final url = _buildUrl(rawUrl);
      final uri = Uri.parse(url);
      final hasBody =
          _method == HttpMethod.post || _method == HttpMethod.put || _method == HttpMethod.patch;

      String? body;
      if (hasBody && _bodyController.text.trim().isNotEmpty) {
        body = _bodyController.text.trim();
        try {
          json.decode(body);
        } catch (_) {
          body = json.encode({'raw': body});
        }
      }

      // Build headers: always include Content-Type, add auth for backend URLs
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (_isBackendUrl(url)) {
        final token = ApiService().accessToken;
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }
      }

      debugPrint('[TestsScreen] ${_methodLabel(_method)} $url');

      // Measure response time
      final stopwatch = Stopwatch()..start();
      http.Response response;

      switch (_method) {
        case HttpMethod.get:
          response = await http.get(uri, headers: headers);
          break;
        case HttpMethod.post:
          response = await http.post(uri, headers: headers, body: body);
          break;
        case HttpMethod.put:
          response = await http.put(uri, headers: headers, body: body);
          break;
        case HttpMethod.delete:
          response = await http.delete(uri, headers: headers);
          break;
        case HttpMethod.patch:
          response = await http.patch(uri, headers: headers, body: body);
          break;
      }
      stopwatch.stop();
      final responseTimeMs = stopwatch.elapsedMilliseconds;

      // Log curl-equivalent for debugging
      if (kDebugMode) {
        final curlParts = <String>['curl -X ${_methodLabel(_method)}'];
        curlParts.add('"$url"');
        headers.forEach((k, v) => curlParts.add('-H "$k: $v"'));
        if (body != null) curlParts.add("-d '$body'");
        debugPrint('[TestsScreen] curl: ${curlParts.join(' ')}');
      }

      if (!mounted) return;

      final statusCode = response.statusCode;
      String formattedBody;
      try {
        final decoded = json.decode(response.body);
        formattedBody = const JsonEncoder.withIndent('  ').convert(decoded);
      } catch (_) {
        formattedBody = response.body;
      }

      // Save the test run to the backend
      try {
        await ApiService().createTestRun(
          method: _methodLabel(_method),
          url: _buildUrl(rawUrl),
          statusCode: statusCode,
          requestBody: body,
          responseBody: response.body.length > 5000
              ? response.body.substring(0, 5000)
              : response.body,
          responseTimeMs: responseTimeMs,
        );
        // Reload the runs list
        _loadTestRuns();
      } catch (e) {
        debugPrint('[TestsScreen] Failed to save test run: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Test run saved locally but failed to persist: $e')),
          );
        }
      }

      setState(() {
        _sending = false;
        _responseStatus = '$statusCode';
        _responseBody = formattedBody;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _responseError = e.toString();
      });
    }
  }

  static String _methodLabel(HttpMethod m) {
    return switch (m) {
      HttpMethod.get => 'GET',
      HttpMethod.post => 'POST',
      HttpMethod.put => 'PUT',
      HttpMethod.delete => 'DELETE',
      HttpMethod.patch => 'PATCH',
    };
  }

  static Color _methodColor(HttpMethod m) {
    return switch (m) {
      HttpMethod.get => Colors.green,
      HttpMethod.post => Colors.blue,
      HttpMethod.put => Colors.amber,
      HttpMethod.delete => Colors.red,
      HttpMethod.patch => Colors.purple,
    };
  }

  static Color _methodBadgeColor(String method) {
    return switch (method.toUpperCase()) {
      'GET' => Colors.blue,
      'POST' => Colors.green,
      'PUT' => Colors.orange,
      'PATCH' => Colors.purple,
      'DELETE' => Colors.red,
      _ => Colors.grey,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CustomScrollView(
      slivers: [
        const SliverAppBar(title: Text('Tests')),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildSendRequestCard(theme),
              const SizedBox(height: 24),
              Text(
                'Test Runs',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              if (_runs.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text('No test runs yet. Send a request to save one.',
                          style: theme.textTheme.bodyMedium),
                    ),
                  ),
                )
              else
                ..._runs.map(
                  (run) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _methodBadgeColor(run.method).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          run.method,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _methodBadgeColor(run.method),
                          ),
                        ),
                      ),
                      title: Text(
                        run.url,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        'Status: ${run.statusCode}',
                        style: TextStyle(
                          color: _statusColor(run.statusCode),
                          fontSize: 12,
                        ),
                      ),
                      trailing: run.id.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              color: theme.colorScheme.error,
                              tooltip: 'Delete run',
                              onPressed: () async {
                                try {
                                  await ApiService().deleteTestRun(run.id);
                                  _loadTestRuns();
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Failed: $e')),
                                    );
                                  }
                                }
                              },
                            )
                          : null,
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildSendRequestCard(ThemeData theme) {
    final hasBody =
        _method == HttpMethod.post || _method == HttpMethod.put || _method == HttpMethod.patch;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.send_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Send HTTP Request',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Method', style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: HttpMethod.values.map((m) {
                  final selected = _method == m;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(_methodLabel(m)),
                      selected: selected,
                      onSelected: (_) => setState(() => _method = m),
                      selectedColor: _methodColor(m).withOpacity(0.25),
                      checkmarkColor: _methodColor(m),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            Text('URL', style: theme.textTheme.labelMedium),
            const SizedBox(height: 6),
            TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                hintText: '/health or https://api.example.com/endpoint',
                prefixIcon: const Icon(Icons.link_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
            ),
            if (hasBody) ...[
              const SizedBox(height: 16),
              Text('Body (JSON)', style: theme.textTheme.labelMedium),
              const SizedBox(height: 6),
              TextField(
                controller: _bodyController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: '{\"key\": \"value\"}',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _sending ? null : _sendRequest,
                icon: _sending
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(_sending ? 'Sending...' : 'Send Request'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            if (_responseError != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _responseError!,
                        style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_responseStatus != null && _responseBody != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Chip(
                    label: Text('Status: $_responseStatus'),
                    backgroundColor: _responseStatus!.startsWith('2')
                        ? Colors.green.withOpacity(0.2)
                        : Colors.orange.withOpacity(0.2),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _responseBody!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TestRun {
  final String method;
  final String url;
  final int statusCode;
  final String responseBody;
  final String id;

  const _TestRun({
    required this.method,
    required this.url,
    required this.statusCode,
    required this.responseBody,
    required this.id,
  });
}

Color _statusColor(int code) {
  if (code >= 200 && code < 300) return Colors.green;
  if (code >= 400 && code < 500) return Colors.orange;
  if (code >= 500) return Colors.red;
  return Colors.grey;
}
