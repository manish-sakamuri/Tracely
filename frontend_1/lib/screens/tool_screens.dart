// All remaining tool screens — compact panels for each service
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/workspace_provider.dart';
import '../services/api_service.dart';
import 'dart:convert';

// ========== MOCK SERVICE SCREEN ==========
class MockServiceScreen extends StatefulWidget {
  const MockServiceScreen({Key? key}) : super(key: key);
  @override State<MockServiceScreen> createState() => _MockServiceScreenState();
}
class _MockServiceScreenState extends State<MockServiceScreen> {
  List<dynamic> _mocks = [];
  bool _loading = true;
  String? _error;
  final _traceIdController = TextEditingController();

  @override void initState() { super.initState(); _loadMocks(); }
  @override void dispose() { _traceIdController.dispose(); super.dispose(); }

  Future<void> _loadMocks() async {
    final wsId = context.read<WorkspaceProvider>().selectedWorkspaceId;
    if (wsId == null) { setState(() { _loading = false; _error = 'Select a workspace'; }); return; }
    setState(() => _loading = true);
    try {
      final res = await ApiService().getMocks(wsId);
      setState(() { _mocks = res; _loading = false; });
    } catch (e) { setState(() { _error = e.toString(); _loading = false; }); }
  }

  Future<void> _generateFromTrace() async {
    final wsId = context.read<WorkspaceProvider>().selectedWorkspaceId;
    if (wsId == null || _traceIdController.text.isEmpty) return;
    try {
      await ApiService().generateMockFromTrace(wsId, _traceIdController.text.trim());
      _traceIdController.clear();
      _loadMocks();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Mock generated from trace'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _deleteMock(String id) async {
    final wsId = context.read<WorkspaceProvider>().selectedWorkspaceId;
    if (wsId == null) return;
    try { await ApiService().deleteMock(wsId, id); _loadMocks(); } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => _ToolPanel(
    title: 'Mock Service', subtitle: 'Simulate downstream API responses',
    loading: _loading, error: _error, onRefresh: _loadMocks,
    headerAction: Row(children: [
      SizedBox(width: 200, height: 36, child: TextField(controller: _traceIdController, style: const TextStyle(fontSize: 12), decoration: _inputDeco('Trace ID to mock...'))),
      const SizedBox(width: 8),
      _ActionBtn(label: 'Generate', onTap: _generateFromTrace),
    ]),
    body: _mocks.isEmpty
        ? _EmptyState(icon: Icons.cloud_off, text: 'No mocks yet. Generate from a trace.')
        : ListView.builder(itemCount: _mocks.length, padding: const EdgeInsets.all(16), itemBuilder: (ctx, i) {
            final m = _mocks[i];
            return _ItemCard(
              title: m['name'] ?? m['endpoint'] ?? 'Mock ${i + 1}',
              subtitle: m['description'] ?? m['method'] ?? '',
              trailing: IconButton(icon: Icon(Icons.delete_outline, size: 16, color: Colors.red.shade400), onPressed: () => _deleteMock(m['id'] ?? '')),
            );
          }),
  );
}

// ========== LOAD TEST SCREEN ==========
class LoadTestScreen extends StatefulWidget {
  const LoadTestScreen({Key? key}) : super(key: key);
  @override State<LoadTestScreen> createState() => _LoadTestScreenState();
}
class _LoadTestScreenState extends State<LoadTestScreen> {
  final _urlController = TextEditingController(text: 'http://localhost:8081/health');
  final _concurrencyController = TextEditingController(text: '10');
  final _durationController = TextEditingController(text: '5');
  String _method = 'GET';
  Map<String, dynamic>? _results;
  bool _running = false;

  @override void dispose() { _urlController.dispose(); _concurrencyController.dispose(); _durationController.dispose(); super.dispose(); }

  Future<void> _runLoadTest() async {
    final wsId = context.read<WorkspaceProvider>().selectedWorkspaceId;
    if (wsId == null) return;
    setState(() => _running = true);
    try {
      final res = await ApiService().createLoadTest(wsId, {
        'url': _urlController.text.trim(),
        'method': _method,
        'concurrency': int.tryParse(_concurrencyController.text) ?? 10,
        'duration_seconds': int.tryParse(_durationController.text) ?? 5,
      });
      setState(() { _results = res; _running = false; });
    } catch (e) {
      setState(() => _running = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) => _ToolPanel(
    title: 'Load Testing', subtitle: 'Stress test your APIs with concurrent requests',
    loading: false, error: null, onRefresh: () {},
    body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel('Configuration'),
      const SizedBox(height: 10),
      Row(children: [
        SizedBox(width: 100, child: DropdownButtonFormField<String>(value: _method, decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8), isDense: true),
          items: ['GET','POST','PUT','DELETE'].map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12)))).toList(), onChanged: (v) => setState(() => _method = v ?? 'GET'))),
        const SizedBox(width: 8),
        Expanded(child: SizedBox(height: 36, child: TextField(controller: _urlController, style: const TextStyle(fontSize: 12), decoration: _inputDeco('URL')))),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: SizedBox(height: 36, child: TextField(controller: _concurrencyController, style: const TextStyle(fontSize: 12), decoration: _inputDeco('Concurrency')))),
        const SizedBox(width: 8),
        Expanded(child: SizedBox(height: 36, child: TextField(controller: _durationController, style: const TextStyle(fontSize: 12), decoration: _inputDeco('Duration (sec)')))),
        const SizedBox(width: 8),
        _ActionBtn(label: _running ? 'Running...' : '▶ Run Test', onTap: _running ? null : _runLoadTest),
      ]),
      if (_results != null) ...[
        const SizedBox(height: 24),
        _sectionLabel('Results'),
        const SizedBox(height: 10),
        _ResultCard(data: _results!),
      ],
    ])),
  );
}

// ========== ENVIRONMENT SCREEN ==========
class EnvironmentScreen extends StatefulWidget {
  const EnvironmentScreen({Key? key}) : super(key: key);
  @override State<EnvironmentScreen> createState() => _EnvironmentScreenState();
}
class _EnvironmentScreenState extends State<EnvironmentScreen> {
  List<dynamic> _envs = [];
  bool _loading = true;
  String? _error;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final wsId = context.read<WorkspaceProvider>().selectedWorkspaceId;
    if (wsId == null) { setState(() { _loading = false; _error = 'Select a workspace'; }); return; }
    setState(() => _loading = true);
    try {
      final res = await ApiService().getEnvironments(wsId);
      setState(() { _envs = res; _loading = false; });
    } catch (e) { setState(() { _error = e.toString(); _loading = false; }); }
  }

  Future<void> _createEnv() async {
    final wsId = context.read<WorkspaceProvider>().selectedWorkspaceId;
    if (wsId == null) return;
    final nameCtrl = TextEditingController();
    final typeCtrl = TextEditingController(text: 'development');
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('New Environment'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: typeCtrl, decoration: const InputDecoration(labelText: 'Type (development/staging/production)', border: OutlineInputBorder())),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create'))],
    ));
    if (confirmed == true && nameCtrl.text.isNotEmpty) {
      await ApiService().createEnvironment(wsId, nameCtrl.text, typeCtrl.text);
      _load();
    }
  }

  Future<void> _deleteEnv(String id) async {
    final wsId = context.read<WorkspaceProvider>().selectedWorkspaceId;
    if (wsId == null) return;
    await ApiService().deleteEnvironment(wsId, id);
    _load();
  }

  @override
  Widget build(BuildContext context) => _ToolPanel(
    title: 'Environments', subtitle: 'Switch between dev, staging, and production',
    loading: _loading, error: _error, onRefresh: _load,
    headerAction: _ActionBtn(label: '+ New Environment', onTap: _createEnv),
    body: _envs.isEmpty
        ? _EmptyState(icon: Icons.swap_horiz, text: 'No environments. Create one to get started.')
        : ListView.builder(padding: const EdgeInsets.all(16), itemCount: _envs.length, itemBuilder: (ctx, i) {
            final e = _envs[i];
            return _ItemCard(
              title: e['name'] ?? 'Env ${i + 1}',
              subtitle: 'Type: ${e['type'] ?? 'N/A'} • Active: ${e['is_active'] ?? false}',
              trailing: IconButton(icon: Icon(Icons.delete_outline, size: 16, color: Colors.red.shade400), onPressed: () => _deleteEnv(e['id'] ?? '')),
            );
          }),
  );
}

// ========== TRACING CONFIG SCREEN ==========
class TracingConfigScreen extends StatefulWidget {
  const TracingConfigScreen({Key? key}) : super(key: key);
  @override State<TracingConfigScreen> createState() => _TracingConfigScreenState();
}
class _TracingConfigScreenState extends State<TracingConfigScreen> {
  List<dynamic> _configs = [];
  bool _loading = true;
  String? _error;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final wsId = context.read<WorkspaceProvider>().selectedWorkspaceId;
    if (wsId == null) { setState(() { _loading = false; _error = 'Select a workspace'; }); return; }
    setState(() => _loading = true);
    try {
      final res = await ApiService().getTracingConfigs(wsId);
      setState(() { _configs = res; _loading = false; });
    } catch (e) { setState(() { _error = e.toString(); _loading = false; }); }
  }

  Future<void> _createConfig() async {
    final wsId = context.read<WorkspaceProvider>().selectedWorkspaceId;
    if (wsId == null) return;
    final nameCtrl = TextEditingController();
    final rateCtrl = TextEditingController(text: '100');
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Tracing Config'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Service/Endpoint', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: rateCtrl, decoration: const InputDecoration(labelText: 'Sample Rate (%)', border: OutlineInputBorder())),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create'))],
    ));
    if (confirmed == true && nameCtrl.text.isNotEmpty) {
      await ApiService().createTracingConfig(wsId, {'service_name': nameCtrl.text, 'sample_rate': int.tryParse(rateCtrl.text) ?? 100, 'enabled': true});
      _load();
    }
  }

  Future<void> _toggle(String id) async {
    final wsId = context.read<WorkspaceProvider>().selectedWorkspaceId;
    if (wsId == null) return;
    await ApiService().toggleTracingConfig(wsId, id);
    _load();
  }

  @override
  Widget build(BuildContext context) => _ToolPanel(
    title: 'Tracing Config', subtitle: 'Control sampling rates per service/endpoint',
    loading: _loading, error: _error, onRefresh: _load,
    headerAction: _ActionBtn(label: '+ New Rule', onTap: _createConfig),
    body: _configs.isEmpty
        ? _EmptyState(icon: Icons.tune, text: 'No tracing configs. Set sampling rules per endpoint.')
        : ListView.builder(padding: const EdgeInsets.all(16), itemCount: _configs.length, itemBuilder: (ctx, i) {
            final c = _configs[i];
            final enabled = c['enabled'] ?? false;
            return _ItemCard(
              title: c['service_name'] ?? 'Config ${i + 1}',
              subtitle: 'Sample: ${c['sample_rate'] ?? 100}% • ${enabled ? "Active" : "Disabled"}',
              leading: Icon(enabled ? Icons.circle : Icons.circle_outlined, size: 12, color: enabled ? Colors.green : Colors.grey),
              trailing: Switch(value: enabled, onChanged: (_) => _toggle(c['id'] ?? ''), activeColor: Colors.grey.shade900),
            );
          }),
  );
}

// ========== SCHEMA VALIDATOR SCREEN ==========
class SchemaValidatorScreen extends StatefulWidget {
  const SchemaValidatorScreen({Key? key}) : super(key: key);
  @override State<SchemaValidatorScreen> createState() => _SchemaValidatorScreenState();
}
class _SchemaValidatorScreenState extends State<SchemaValidatorScreen> {
  final _schemaController = TextEditingController(text: '{\n  "type": "object",\n  "properties": {\n    "price": {"type": "number"},\n    "name": {"type": "string"}\n  },\n  "required": ["price", "name"]\n}');
  final _dataController = TextEditingController(text: '{\n  "price": 19.99,\n  "name": "Pizza"\n}');
  Map<String, dynamic>? _result;
  bool _validating = false;

  @override void dispose() { _schemaController.dispose(); _dataController.dispose(); super.dispose(); }

  Future<void> _validate() async {
    final wsId = context.read<WorkspaceProvider>().selectedWorkspaceId;
    if (wsId == null) return;
    setState(() => _validating = true);
    try {
      final res = await ApiService().validateSchema(wsId, {'schema': json.decode(_schemaController.text), 'data': json.decode(_dataController.text)});
      setState(() { _result = res; _validating = false; });
    } catch (e) {
      setState(() { _result = {'valid': false, 'error': e.toString()}; _validating = false; });
    }
  }

  @override
  Widget build(BuildContext context) => _ToolPanel(
    title: 'Schema Validator', subtitle: 'Validate API responses against JSON schemas',
    loading: false, error: null, onRefresh: () {},
    body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionLabel('Schema'), const SizedBox(height: 6),
          SizedBox(height: 200, child: TextField(controller: _schemaController, maxLines: null, expands: true, style: const TextStyle(fontFamily: 'monospace', fontSize: 12), decoration: _inputDeco(''))),
        ])),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionLabel('Data'), const SizedBox(height: 6),
          SizedBox(height: 200, child: TextField(controller: _dataController, maxLines: null, expands: true, style: const TextStyle(fontFamily: 'monospace', fontSize: 12), decoration: _inputDeco(''))),
        ])),
      ]),
      const SizedBox(height: 12),
      _ActionBtn(label: _validating ? 'Validating...' : '✓ Validate', onTap: _validating ? null : _validate),
      if (_result != null) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: (_result!['valid'] == true ? Colors.green : Colors.red).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8), border: Border.all(color: (_result!['valid'] == true ? Colors.green : Colors.red).withOpacity(0.3))),
          child: Text(_result!['valid'] == true ? '✅ Schema validation passed!' : '❌ Validation failed: ${_result!['errors'] ?? _result!['error'] ?? 'Invalid'}',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _result!['valid'] == true ? Colors.green.shade800 : Colors.red.shade800)),
        ),
      ],
    ])),
  );
}

// ========== TEST DATA GENERATOR SCREEN ==========
class TestDataGeneratorScreen extends StatefulWidget {
  const TestDataGeneratorScreen({Key? key}) : super(key: key);
  @override State<TestDataGeneratorScreen> createState() => _TestDataGeneratorScreenState();
}
class _TestDataGeneratorScreenState extends State<TestDataGeneratorScreen> {
  final _schemaController = TextEditingController(text: '{\n  "type": "object",\n  "properties": {\n    "name": {"type": "string"},\n    "email": {"type": "string"},\n    "age": {"type": "integer"}\n  }\n}');
  List<dynamic> _generated = [];
  bool _generating = false;

  @override void dispose() { _schemaController.dispose(); super.dispose(); }

  Future<void> _generate() async {
    final wsId = context.read<WorkspaceProvider>().selectedWorkspaceId;
    if (wsId == null) return;
    setState(() => _generating = true);
    try {
      final res = await ApiService().generateTestData(wsId, json.decode(_schemaController.text));
      setState(() { _generated = res['data'] is List ? res['data'] : [res['data'] ?? res]; _generating = false; });
    } catch (e) {
      setState(() => _generating = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) => _ToolPanel(
    title: 'Test Data Generator', subtitle: 'Generate realistic fake data from JSON schemas',
    loading: false, error: null, onRefresh: () {},
    body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel('JSON Schema'), const SizedBox(height: 6),
      SizedBox(height: 160, child: TextField(controller: _schemaController, maxLines: null, expands: true, style: const TextStyle(fontFamily: 'monospace', fontSize: 12), decoration: _inputDeco(''))),
      const SizedBox(height: 12),
      _ActionBtn(label: _generating ? 'Generating...' : '⚡ Generate Data', onTap: _generating ? null : _generate),
      if (_generated.isNotEmpty) ...[
        const SizedBox(height: 16), _sectionLabel('Generated Data'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12), width: double.infinity,
          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
          child: Text(const JsonEncoder.withIndent('  ').convert(_generated), style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
        ),
      ],
    ])),
  );
}

// ========== FAILURE INJECTION SCREEN ==========
class FailureInjectionScreen extends StatefulWidget {
  const FailureInjectionScreen({Key? key}) : super(key: key);
  @override State<FailureInjectionScreen> createState() => _FailureInjectionScreenState();
}
class _FailureInjectionScreenState extends State<FailureInjectionScreen> {
  final _serviceCtrl = TextEditingController();
  final _latencyCtrl = TextEditingController(text: '500');
  String _failureType = 'latency';
  double _failureRate = 0.5;
  Map<String, dynamic>? _result;

  @override void dispose() { _serviceCtrl.dispose(); _latencyCtrl.dispose(); super.dispose(); }

  Future<void> _inject() async {
    final wsId = context.read<WorkspaceProvider>().selectedWorkspaceId;
    if (wsId == null || _serviceCtrl.text.isEmpty) return;
    try {
      final res = await ApiService().createFailureInjectionRule(wsId, {
        'service_name': _serviceCtrl.text.trim(),
        'failure_type': _failureType,
        'failure_rate': _failureRate,
        'latency_ms': int.tryParse(_latencyCtrl.text) ?? 500,
      });
      setState(() => _result = res);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Failure rule created'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) => _ToolPanel(
    title: 'Failure Injection', subtitle: 'Chaos engineering — test resilience by injecting failures',
    loading: false, error: null, onRefresh: () {},
    body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel('Injection Rule'), const SizedBox(height: 10),
      SizedBox(height: 36, child: TextField(controller: _serviceCtrl, style: const TextStyle(fontSize: 12), decoration: _inputDeco('Service Name (e.g. payment-service)'))),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: DropdownButtonFormField<String>(value: _failureType, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
          items: ['latency','error','timeout','crash'].map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12)))).toList(), onChanged: (v) => setState(() => _failureType = v ?? 'latency'))),
        const SizedBox(width: 8),
        Expanded(child: SizedBox(height: 36, child: TextField(controller: _latencyCtrl, style: const TextStyle(fontSize: 12), decoration: _inputDeco('Latency (ms)')))),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Text('Failure Rate: ${(_failureRate * 100).toInt()}%', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        Expanded(child: Slider(value: _failureRate, onChanged: (v) => setState(() => _failureRate = v), activeColor: Colors.red)),
      ]),
      const SizedBox(height: 12),
      _ActionBtn(label: '💥 Inject Failure', onTap: _inject),
      if (_result != null) ...[const SizedBox(height: 16), _ResultCard(data: _result!)],
    ])),
  );
}

// ========== MUTATION TESTING SCREEN ==========
class MutationTestingScreen extends StatefulWidget {
  const MutationTestingScreen({Key? key}) : super(key: key);
  @override State<MutationTestingScreen> createState() => _MutationTestingScreenState();
}
class _MutationTestingScreenState extends State<MutationTestingScreen> {
  final _dataController = TextEditingController(text: '{\n  "coupon": "DISCOUNT10",\n  "amount": 50.00\n}');
  final _countController = TextEditingController(text: '5');
  Map<String, dynamic>? _result;
  bool _running = false;

  @override void dispose() { _dataController.dispose(); _countController.dispose(); super.dispose(); }

  Future<void> _run() async {
    final wsId = context.read<WorkspaceProvider>().selectedWorkspaceId;
    if (wsId == null) return;
    setState(() => _running = true);
    try {
      final res = await ApiService().applyMutations(wsId, {'data': json.decode(_dataController.text), 'mutation_count': int.tryParse(_countController.text) ?? 5});
      setState(() { _result = res; _running = false; });
    } catch (e) {
      setState(() => _running = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) => _ToolPanel(
    title: 'Mutation Testing', subtitle: 'Fuzz test API fields with mutated values',
    loading: false, error: null, onRefresh: () {},
    body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel('Input Data'), const SizedBox(height: 6),
      SizedBox(height: 120, child: TextField(controller: _dataController, maxLines: null, expands: true, style: const TextStyle(fontFamily: 'monospace', fontSize: 12), decoration: _inputDeco(''))),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: SizedBox(height: 36, child: TextField(controller: _countController, style: const TextStyle(fontSize: 12), decoration: _inputDeco('# Mutations')))),
        const SizedBox(width: 8),
        _ActionBtn(label: _running ? 'Running...' : '🧬 Mutate', onTap: _running ? null : _run),
      ]),
      if (_result != null) ...[const SizedBox(height: 16), _ResultCard(data: _result!)],
    ])),
  );
}

// ========== PERCENTILE CALCULATOR SCREEN ==========
class PercentileCalculatorScreen extends StatefulWidget {
  const PercentileCalculatorScreen({Key? key}) : super(key: key);
  @override State<PercentileCalculatorScreen> createState() => _PercentileCalculatorScreenState();
}
class _PercentileCalculatorScreenState extends State<PercentileCalculatorScreen> {
  final _valuesController = TextEditingController(text: '100, 200, 150, 300, 500, 120, 180, 900, 1200, 250');
  Map<String, dynamic>? _result;
  bool _running = false;

  @override void dispose() { _valuesController.dispose(); super.dispose(); }

  Future<void> _calc() async {
    final wsId = context.read<WorkspaceProvider>().selectedWorkspaceId;
    if (wsId == null) return;
    setState(() => _running = true);
    try {
      final values = _valuesController.text.split(',').map((s) => double.tryParse(s.trim()) ?? 0).toList();
      final res = await ApiService().calculatePercentiles(wsId, {'values': values, 'percentiles': [50, 75, 90, 95, 99]});
      setState(() { _result = res; _running = false; });
    } catch (e) {
      setState(() => _running = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) => _ToolPanel(
    title: 'Percentile Calculator', subtitle: 'Analyze P50, P95, P99 latency from response times',
    loading: false, error: null, onRefresh: () {},
    body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel('Response Times (comma-separated, in ms)'), const SizedBox(height: 6),
      SizedBox(height: 60, child: TextField(controller: _valuesController, maxLines: null, expands: true, style: const TextStyle(fontFamily: 'monospace', fontSize: 12), decoration: _inputDeco(''))),
      const SizedBox(height: 12),
      _ActionBtn(label: _running ? 'Calculating...' : '📊 Calculate Percentiles', onTap: _running ? null : _calc),
      if (_result != null) ...[const SizedBox(height: 16), _ResultCard(data: _result!)],
    ])),
  );
}

// ========== ALERTS SCREEN ==========
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({Key? key}) : super(key: key);
  @override State<AlertsScreen> createState() => _AlertsScreenState();
}
class _AlertsScreenState extends State<AlertsScreen> {
  List<dynamic> _alerts = [];
  bool _loading = true;
  String? _error;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final wsId = context.read<WorkspaceProvider>().selectedWorkspaceId;
    if (wsId == null) { setState(() { _loading = false; _error = 'Select a workspace'; }); return; }
    setState(() => _loading = true);
    try {
      final res = await ApiService().getActiveAlerts(wsId);
      setState(() { _alerts = res; _loading = false; });
    } catch (e) { setState(() { _error = e.toString(); _loading = false; }); }
  }

  Future<void> _createRule() async {
    final wsId = context.read<WorkspaceProvider>().selectedWorkspaceId;
    if (wsId == null) return;
    final nameCtrl = TextEditingController();
    final thresholdCtrl = TextEditingController(text: '5');
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Create Alert Rule'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Rule Name', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: thresholdCtrl, decoration: const InputDecoration(labelText: 'Threshold (failures per window)', border: OutlineInputBorder())),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create'))],
    ));
    if (confirmed == true && nameCtrl.text.isNotEmpty) {
      await ApiService().createAlertRule(wsId, {'name': nameCtrl.text, 'threshold': int.tryParse(thresholdCtrl.text) ?? 5, 'window_minutes': 2, 'enabled': true});
      _load();
    }
  }

  Future<void> _ack(String id) async {
    final wsId = context.read<WorkspaceProvider>().selectedWorkspaceId;
    if (wsId == null) return;
    await ApiService().acknowledgeAlert(wsId, id);
    _load();
  }

  @override
  Widget build(BuildContext context) => _ToolPanel(
    title: 'Alerts', subtitle: 'Threshold-based alerting for API failures',
    loading: _loading, error: _error, onRefresh: _load,
    headerAction: _ActionBtn(label: '+ Alert Rule', onTap: _createRule),
    body: _alerts.isEmpty
        ? _EmptyState(icon: Icons.notifications_off, text: 'No active alerts. Create alert rules to monitor failures.')
        : ListView.builder(padding: const EdgeInsets.all(16), itemCount: _alerts.length, itemBuilder: (ctx, i) {
            final a = _alerts[i];
            return _ItemCard(
              title: a['name'] ?? a['rule_name'] ?? 'Alert ${i + 1}',
              subtitle: a['message'] ?? 'Triggered',
              leading: Icon(Icons.warning_amber, size: 16, color: Colors.orange.shade700),
              trailing: TextButton(onPressed: () => _ack(a['id'] ?? ''), child: const Text('Acknowledge', style: TextStyle(fontSize: 11))),
            );
          }),
  );
}

// ========== AUDIT LOGS SCREEN ==========
class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({Key? key}) : super(key: key);
  @override State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}
class _AuditLogsScreenState extends State<AuditLogsScreen> {
  List<dynamic> _logs = [];
  bool _loading = true;
  String? _error;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final wsId = context.read<WorkspaceProvider>().selectedWorkspaceId;
    if (wsId == null) { setState(() { _loading = false; _error = 'Select a workspace'; }); return; }
    setState(() => _loading = true);
    try {
      final res = await ApiService().getAuditLogs(wsId);
      setState(() { _logs = res; _loading = false; });
    } catch (e) { setState(() { _error = e.toString(); _loading = false; }); }
  }

  @override
  Widget build(BuildContext context) => _ToolPanel(
    title: 'Audit Logs', subtitle: 'Track every action in your workspace',
    loading: _loading, error: _error, onRefresh: _load,
    body: _logs.isEmpty
        ? _EmptyState(icon: Icons.history, text: 'No audit logs yet. Actions are logged automatically.')
        : ListView.builder(padding: const EdgeInsets.all(16), itemCount: _logs.length, itemBuilder: (ctx, i) {
            final l = _logs[i];
            return _ItemCard(
              title: '${l['action'] ?? 'Action'} — ${l['resource_type'] ?? ''}',
              subtitle: '${l['user_email'] ?? l['user_id'] ?? 'Unknown user'} • ${l['created_at'] ?? ''}',
              leading: Icon(Icons.person, size: 14, color: Colors.grey.shade500),
            );
          }),
  );
}

// ========== SECRETS VAULT SCREEN ==========
class SecretsVaultScreen extends StatefulWidget {
  const SecretsVaultScreen({Key? key}) : super(key: key);
  @override State<SecretsVaultScreen> createState() => _SecretsVaultScreenState();
}
class _SecretsVaultScreenState extends State<SecretsVaultScreen> {
  Map<String, dynamic>? _lastResult;

  Future<void> _createSecret() async {
    final wsId = context.read<WorkspaceProvider>().selectedWorkspaceId;
    if (wsId == null) return;
    final nameCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Store Secret'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Secret Name', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: valueCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Secret Value', border: OutlineInputBorder())),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Store'))],
    ));
    if (confirmed == true && nameCtrl.text.isNotEmpty) {
      try {
        final res = await ApiService().createSecret(wsId, {'name': nameCtrl.text, 'value': valueCtrl.text});
        setState(() => _lastResult = res);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Secret stored securely'), backgroundColor: Colors.green));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) => _ToolPanel(
    title: 'Secrets Vault', subtitle: 'Store and manage encrypted API keys and credentials',
    loading: false, error: null, onRefresh: () {},
    headerAction: _ActionBtn(label: '+ Store Secret', onTap: _createSecret),
    body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _EmptyState(icon: Icons.lock, text: 'Secrets are encrypted at rest.\nStore API keys, tokens, and credentials securely.'),
      if (_lastResult != null) ...[const SizedBox(height: 16), _ResultCard(data: _lastResult!)],
    ])),
  );
}

// ========== WEBHOOKS SCREEN ==========
class WebhooksScreen extends StatefulWidget {
  const WebhooksScreen({Key? key}) : super(key: key);
  @override State<WebhooksScreen> createState() => _WebhooksScreenState();
}
class _WebhooksScreenState extends State<WebhooksScreen> {
  Map<String, dynamic>? _result;

  Future<void> _createWebhook() async {
    final wsId = context.read<WorkspaceProvider>().selectedWorkspaceId;
    if (wsId == null || wsId.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a workspace first'), backgroundColor: Colors.orange));
      return;
    }
    final nameCtrl = TextEditingController(text: 'My Webhook');
    final urlCtrl = TextEditingController(text: 'https://hooks.slack.com/services/example/incoming');
    final eventCtrl = TextEditingController(text: 'trace.created');
    final secretCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Create Webhook'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Slack Alerts', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'Webhook URL', hintText: 'https://...', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: eventCtrl, decoration: const InputDecoration(labelText: 'Events (comma-separated)', hintText: 'e.g. trace.created, request.failed', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: secretCtrl, decoration: const InputDecoration(labelText: 'Secret (optional)', border: OutlineInputBorder())),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create'))],
    ));
    if (confirmed == true) {
      try {
        final eventStr = eventCtrl.text.trim();
        final events = eventStr.isEmpty ? ['trace.created'] : eventStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        if (events.isEmpty) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one event'), backgroundColor: Colors.orange));
          return;
        }
        final res = await ApiService().createWebhook(wsId, {
          'name': nameCtrl.text.trim().isEmpty ? 'My Webhook' : nameCtrl.text.trim(),
          'url': urlCtrl.text.trim(),
          'events': events,
          if (secretCtrl.text.trim().isNotEmpty) 'secret': secretCtrl.text.trim(),
        });
        setState(() => _result = res);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Webhook created'), backgroundColor: Colors.green));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _triggerWebhook() async {
    final wsId = context.read<WorkspaceProvider>().selectedWorkspaceId;
    if (wsId == null || wsId.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a workspace first'), backgroundColor: Colors.orange));
      return;
    }
    try {
      final res = await ApiService().triggerWebhook(wsId, {
        'event_type': 'manual_test',
        'payload': {'message': 'Test trigger from Tracely', 'source': 'tracely_ui'},
      });
      setState(() => _result = res);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Webhook triggered'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) => _ToolPanel(
    title: 'Webhooks', subtitle: 'Event-driven notifications to Slack, email, or any URL',
    loading: false, error: null, onRefresh: () {},
    headerAction: Row(children: [
      _ActionBtn(label: '+ Create', onTap: _createWebhook),
      const SizedBox(width: 8),
      _ActionBtn(label: '⚡ Trigger', onTap: _triggerWebhook),
    ]),
    body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
      _EmptyState(icon: Icons.webhook, text: 'Set up webhooks to notify your team on events.'),
      if (_result != null) ...[const SizedBox(height: 16), _ResultCard(data: _result!)],
    ])),
  );
}

// ========== WORKFLOWS SCREEN ==========
class WorkflowsScreen extends StatefulWidget {
  const WorkflowsScreen({Key? key}) : super(key: key);
  @override State<WorkflowsScreen> createState() => _WorkflowsScreenState();
}
class _WorkflowsScreenState extends State<WorkflowsScreen> {
  Map<String, dynamic>? _result;

  Future<void> _createWorkflow() async {
    final wsId = context.read<WorkspaceProvider>().selectedWorkspaceId;
    if (wsId == null) return;
    final nameCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Create Workflow'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Workflow Name', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        Text('Workflows chain multiple API calls in sequence.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create'))],
    ));
    if (confirmed == true && nameCtrl.text.isNotEmpty) {
      try {
        final res = await ApiService().createWorkflow(wsId, {'name': nameCtrl.text, 'steps': [
          {'name': 'Login', 'method': 'POST', 'url': '/api/v1/auth/login'},
          {'name': 'Get Workspaces', 'method': 'GET', 'url': '/api/v1/workspaces'},
        ]});
        setState(() => _result = res);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Workflow created'), backgroundColor: Colors.green));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) => _ToolPanel(
    title: 'Workflows', subtitle: 'Chain API calls in sequence: Login → Search → Order',
    loading: false, error: null, onRefresh: () {},
    headerAction: _ActionBtn(label: '+ New Workflow', onTap: _createWorkflow),
    body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
      _EmptyState(icon: Icons.account_tree, text: 'Create multi-step API workflows.\nChain requests with dependencies.'),
      if (_result != null) ...[const SizedBox(height: 16), _ResultCard(data: _result!)],
    ])),
  );
}

// ========== WATERFALL VIEW SCREEN ==========
class WaterfallScreen extends StatefulWidget {
  const WaterfallScreen({Key? key}) : super(key: key);
  @override State<WaterfallScreen> createState() => _WaterfallScreenState();
}
class _WaterfallScreenState extends State<WaterfallScreen> {
  final _traceIdCtrl = TextEditingController();
  Map<String, dynamic>? _result;
  bool _loading = false;

  @override void dispose() { _traceIdCtrl.dispose(); super.dispose(); }

  Future<void> _loadWaterfall() async {
    final wsId = context.read<WorkspaceProvider>().selectedWorkspaceId;
    if (wsId == null || _traceIdCtrl.text.isEmpty) return;
    setState(() => _loading = true);
    try {
      final res = await ApiService().getWaterfall(wsId, _traceIdCtrl.text.trim());
      setState(() { _result = res; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) => _ToolPanel(
    title: 'Waterfall View', subtitle: 'Visualize span timing and dependencies for a trace',
    loading: false, error: null, onRefresh: () {},
    body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: SizedBox(height: 36, child: TextField(controller: _traceIdCtrl, style: const TextStyle(fontSize: 12), decoration: _inputDeco('Enter Trace ID')))),
        const SizedBox(width: 8),
        _ActionBtn(label: _loading ? 'Loading...' : '🔍 Load Waterfall', onTap: _loading ? null : _loadWaterfall),
      ]),
      if (_result != null) ...[
        const SizedBox(height: 20),
        _buildWaterfallChart(_result!),
      ],
    ])),
  );

  Widget _buildWaterfallChart(Map<String, dynamic> data) {
    final spans = data['spans'] as List<dynamic>? ?? [];
    if (spans.isEmpty) return _EmptyState(icon: Icons.waterfall_chart, text: 'No spans found for this trace.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Trace Waterfall (${spans.length} spans)'),
        const SizedBox(height: 12),
        ...spans.asMap().entries.map((entry) {
          final s = entry.value;
          final offset = (s['relative_start_ms'] ?? 0).toDouble();
          final duration = (s['duration_ms'] ?? 0).toDouble();
          final maxDur = (data['total_duration_ms'] ?? 1000).toDouble();
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              SizedBox(width: 140, child: Text(s['operation_name'] ?? s['service_name'] ?? 'span', style: const TextStyle(fontSize: 11, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              Expanded(child: LayoutBuilder(builder: (ctx, constraints) {
                final barStart = (offset / maxDur) * constraints.maxWidth;
                final barWidth = (duration / maxDur) * constraints.maxWidth;
                return Stack(children: [
                  Container(height: 20, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4))),
                  Positioned(left: barStart.clamp(0, constraints.maxWidth - 4), child: Container(
                    width: barWidth.clamp(4, constraints.maxWidth), height: 20,
                    decoration: BoxDecoration(color: Colors.blue.shade400, borderRadius: BorderRadius.circular(4)),
                    alignment: Alignment.center,
                    child: Text('${duration.toInt()}ms', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600)),
                  )),
                ]);
              })),
            ]),
          );
        }),
      ],
    );
  }
}

// ========== MONITORING SCREEN ==========
class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({Key? key}) : super(key: key);
  @override State<MonitoringScreen> createState() => _MonitoringScreenState();
}
class _MonitoringScreenState extends State<MonitoringScreen> {
  Map<String, dynamic>? _dashboard;
  bool _loading = true;
  String? _error;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final wsId = context.read<WorkspaceProvider>().selectedWorkspaceId;
    if (wsId == null) { setState(() { _loading = false; _error = 'Select a workspace'; }); return; }
    setState(() => _loading = true);
    try {
      final res = await ApiService().getDashboard(wsId);
      setState(() { _dashboard = res; _loading = false; });
    } catch (e) { setState(() { _error = e.toString(); _loading = false; }); }
  }

  @override
  Widget build(BuildContext context) => _ToolPanel(
    title: 'Monitoring', subtitle: 'System health, metrics, and resource usage',
    loading: _loading, error: _error, onRefresh: _load,
    body: _dashboard == null
        ? _EmptyState(icon: Icons.monitor_heart, text: 'No monitoring data yet.')
        : SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [_ResultCard(data: _dashboard!)])),
  );
}


// ========== SHARED WIDGETS ==========

class _ToolPanel extends StatelessWidget {
  final String title, subtitle;
  final bool loading;
  final String? error;
  final VoidCallback onRefresh;
  final Widget? headerAction;
  final Widget body;

  const _ToolPanel({required this.title, required this.subtitle, required this.loading, required this.error, required this.onRefresh, this.headerAction, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8F9FA),
      child: Column(children: [
        // Tool header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey.shade900)),
              Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ]),
            const Spacer(),
            if (headerAction != null) headerAction!,
            const SizedBox(width: 8),
            IconButton(icon: const Icon(Icons.refresh, size: 16), onPressed: onRefresh, tooltip: 'Refresh'),
          ]),
        ),
        // Content
        Expanded(
          child: loading
              ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey.shade600))
              : error != null
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.error_outline, size: 40, color: Colors.red.shade300),
                      const SizedBox(height: 8),
                      Text(error!, style: TextStyle(color: Colors.red.shade600, fontSize: 13)),
                      const SizedBox(height: 12),
                      TextButton(onPressed: onRefresh, child: const Text('Retry')),
                    ]))
                  : body,
        ),
      ]),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _ActionBtn({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: onTap == null ? Colors.grey.shade400 : Colors.grey.shade900, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyState({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 48, color: Colors.grey.shade300),
    const SizedBox(height: 12),
    Text(text, style: TextStyle(fontSize: 13, color: Colors.grey.shade500), textAlign: TextAlign.center),
  ]));
}

class _ItemCard extends StatelessWidget {
  final String title, subtitle;
  final Widget? leading, trailing;
  const _ItemCard({required this.title, required this.subtitle, this.leading, this.trailing});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
    child: Row(children: [
      if (leading != null) ...[leading!, const SizedBox(width: 10)],
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade900)),
        Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ])),
      if (trailing != null) trailing!,
    ]),
  );
}

class _ResultCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ResultCard({required this.data});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
    child: SelectableText(const JsonEncoder.withIndent('  ').convert(data), style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
  );
}

InputDecoration _inputDeco(String hint) => InputDecoration(
  hintText: hint, hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade600)),
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), isDense: true,
);

Widget _sectionLabel(String text) => Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700));
