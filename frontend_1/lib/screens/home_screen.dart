// lib/screens/home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/workspace_provider.dart';
import '../providers/trace_provider.dart';
import '../providers/request_provider.dart';
import '../providers/collection_provider.dart';
import '../providers/monitoring_provider.dart';
import '../providers/governance_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/animations.dart';
import '../screens/workspaces_screen.dart';
import '../screens/request_studio_screen.dart';
import '../screens/trace_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/replay_screen.dart';
import '../screens/workspace_setup_screen.dart';
import '../screens/collections_screen.dart';
import '../screens/governance_screen.dart';
import '../screens/tool_screens.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onLogout;
  final VoidCallback onNavigateToAuth;

  const HomeScreen({
    Key? key,
    required this.onLogout,
    required this.onNavigateToAuth,
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 0=dashboard, 1=request studio, 2=collections, 3=traces, 4=replay,
  // 5=workspaces, 6=governance, 7=settings,
  // 8=mock, 9=load test, 10=schema validator, 11=test data, 12=failure injection,
  // 13=mutation, 14=workflows, 15=webhooks, 16=secrets, 17=audit, 18=alerts,
  // 19=environments, 20=monitoring, 21=percentile, 22=tracing config, 23=waterfall
  int _selectedNav = 0;
  String _selectedTimeRange = 'Today';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _sidebarCollapsed = false;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
      _startAutoRefresh();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _loadDashboardData();
    });
  }

  Future<void> _loadDashboardData() async {
    final workspaceProvider = context.read<WorkspaceProvider>();
    final traceProvider = context.read<TraceProvider>();
    final dashboardProvider = context.read<DashboardProvider>();
    
    // Load workspaces if not loaded
    if (workspaceProvider.workspaces.isEmpty) {
      await workspaceProvider.loadWorkspaces();
    }
    
    if (workspaceProvider.selectedWorkspaceId != null) {
      final wsId = workspaceProvider.selectedWorkspaceId!;
      await Future.wait([
        traceProvider.fetchTraces(wsId),
        dashboardProvider.fullRefresh(wsId),
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<AuthProvider, WorkspaceProvider, TraceProvider>(
      builder: (context, authProvider, workspaceProvider, traceProvider, child) {
        if (!authProvider.isAuthenticated) {
          return _buildUnauthenticatedView();
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          body: Row(
            children: [
              // Sidebar
              _buildSidebar(authProvider, workspaceProvider),
              // Main content
              Expanded(
                child: Column(
                  children: [
                    _buildTopBar(authProvider, workspaceProvider),
                    Expanded(
                      child: _buildCurrentScreen(workspaceProvider, traceProvider),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebar(AuthProvider authProvider, WorkspaceProvider workspaceProvider) {
    final navItems = [
      {'icon': Icons.dashboard_outlined, 'activeIcon': Icons.dashboard, 'label': 'Dashboard', 'index': 0},
      {'icon': Icons.edit_note_outlined, 'activeIcon': Icons.edit_note, 'label': 'Request Studio', 'index': 1},
      {'icon': Icons.folder_outlined, 'activeIcon': Icons.folder, 'label': 'Collections', 'index': 2},
      {'icon': Icons.timeline_outlined, 'activeIcon': Icons.timeline, 'label': 'Traces & Waterfall', 'index': 3},
      {'icon': Icons.replay_outlined, 'activeIcon': Icons.replay, 'label': 'Replay Engine', 'index': 4},
      {'icon': Icons.workspaces_outlined, 'activeIcon': Icons.workspaces, 'label': 'Workspaces', 'index': 5},
      {'icon': Icons.policy_outlined, 'activeIcon': Icons.policy, 'label': 'Governance', 'index': 6},
      {'icon': Icons.settings_outlined, 'activeIcon': Icons.settings, 'label': 'Settings', 'index': 7},
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _sidebarCollapsed ? 70 : 240,
      decoration: BoxDecoration(
        color: const Color(0xFF111214),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo
          Container(
            height: 70,
            padding: EdgeInsets.symmetric(horizontal: _sidebarCollapsed ? 12 : 20),
            child: Row(
              children: [
                const Icon(Icons.bolt, color: Color(0xFFFF6B2C), size: 24),
                if (!_sidebarCollapsed) ...[
                  const SizedBox(width: 10),
                  const Text(
                    'Tracely',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                ],
                IconButton(
                  icon: Icon(
                    _sidebarCollapsed ? Icons.chevron_right : Icons.chevron_left,
                    color: Colors.white54,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
                ),
              ],
            ),
          ),

          // Workspace indicator
          if (!_sidebarCollapsed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.green.shade400,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        workspaceProvider.selectedWorkspace?['name'] ?? 'No Workspace',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 8),

          // Section label
          if (!_sidebarCollapsed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'NAVIGATION',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),

          // Nav items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                ...navItems.map((item) => _buildSidebarItem(
                  icon: item['icon'] as IconData,
                  activeIcon: item['activeIcon'] as IconData,
                  label: item['label'] as String,
                  index: item['index'] as int,
                )),
                
                if (!_sidebarCollapsed) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Divider(color: Colors.white10),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Text(
                      'SERVICES',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  _buildServicePill('Mock Service', Icons.cloud_off, 8),
                  _buildServicePill('Load Testing', Icons.speed, 9),
                  _buildServicePill('Schema Validator', Icons.verified, 10),
                  _buildServicePill('Test Data Gen', Icons.data_array, 11),
                  _buildServicePill('Failure Injection', Icons.warning_amber, 12),
                  _buildServicePill('Mutation Testing', Icons.shuffle, 13),
                  _buildServicePill('Workflow Engine', Icons.account_tree, 14),
                  _buildServicePill('Webhooks', Icons.webhook, 15),
                  _buildServicePill('Secrets Vault', Icons.lock, 16),
                  _buildServicePill('Audit Logs', Icons.history, 17),
                  _buildServicePill('Alerting', Icons.notifications_active, 18),
                  _buildServicePill('Environments', Icons.swap_horiz, 19),
                  _buildServicePill('Monitoring', Icons.monitor_heart, 20),
                  _buildServicePill('Percentile Calc', Icons.analytics, 21),
                  _buildServicePill('Tracing Config', Icons.tune, 22),
                  _buildServicePill('Waterfall View', Icons.waterfall_chart, 23),
                ],
              ],
            ),
          ),

          // User profile
          Container(
            padding: EdgeInsets.all(_sidebarCollapsed ? 8 : 12),
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFFFF6B2C),
                  child: Text(
                    authProvider.user?['name']?.toString().substring(0, 1).toUpperCase() ?? 'U',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                if (!_sidebarCollapsed) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authProvider.user?['name'] ?? 'User',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          authProvider.user?['email'] ?? '',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white38, size: 16),
                    tooltip: 'Logout',
                    onPressed: widget.onLogout,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isActive = _selectedNav == index;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _selectedNav = index),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: _sidebarCollapsed ? 12 : 14,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: isActive ? Colors.white.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                isActive ? activeIcon : icon,
                color: isActive ? Colors.white : Colors.white54,
                size: 18,
              ),
              if (!_sidebarCollapsed) ...[
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.white54,
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServicePill(String label, IconData icon, int navIndex) {
    final isActive = _selectedNav == navIndex;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _selectedNav = navIndex),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? Colors.white.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, color: isActive ? const Color(0xFFFF6B2C) : Colors.white30, size: 14),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.white38,
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(AuthProvider authProvider, WorkspaceProvider workspaceProvider) {
    final screenTitles = ['Dashboard', 'Request Studio', 'Collections', 'Traces & Waterfall', 'Replay Engine', 'Workspaces', 'Governance', 'Settings',
      'Mock Service', 'Load Testing', 'Schema Validator', 'Test Data Generator', 'Failure Injection',
      'Mutation Testing', 'Workflows', 'Webhooks', 'Secrets Vault', 'Audit Logs', 'Alerts',
      'Environments', 'Monitoring', 'Percentile Calculator', 'Tracing Config', 'Waterfall View'];
    
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Text(
            _selectedNav < screenTitles.length ? screenTitles[_selectedNav] : 'Dashboard',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade900,
            ),
          ),
          const SizedBox(width: 16),
          
          // Workspace selector
          if (workspaceProvider.workspaces.isNotEmpty)
            PopupMenuButton<String>(
              tooltip: 'Switch Workspace',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.workspaces_outlined, size: 14, color: Colors.grey.shade700),
                    const SizedBox(width: 6),
                    Text(
                      workspaceProvider.selectedWorkspace?['name'] ?? 'Select',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade900),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey.shade700),
                  ],
                ),
              ),
              onSelected: (id) {
                workspaceProvider.selectWorkspace(id);
                _loadDashboardData();
              },
              itemBuilder: (context) => workspaceProvider.workspaces.map<PopupMenuEntry<String>>((w) {
                return PopupMenuItem<String>(
                  value: w['id'].toString(),
                  child: Text(w['name'] ?? 'Unnamed'),
                );
              }).toList(),
            ),
          
          const Spacer(),
          
          // Search
          Container(
            width: 260,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(Icons.search, size: 16, color: Colors.grey.shade500),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search APIs, traces...',
                      hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 12),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          
          // Refresh
          IconButton(
            icon: Icon(Icons.refresh, size: 18, color: Colors.grey.shade600),
            tooltip: 'Refresh Data',
            onPressed: _loadDashboardData,
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentScreen(WorkspaceProvider workspaceProvider, TraceProvider traceProvider) {
    final wsId = workspaceProvider.selectedWorkspaceId;
    final workspace = workspaceProvider.selectedWorkspace ?? {'id': wsId ?? '', 'name': 'Default'};

    switch (_selectedNav) {
      case 0:
        return _buildDashboard(workspaceProvider, traceProvider);
      case 1:
        return const RequestStudioScreen();
      case 2:
        return CollectionScreen(workspace: Map<String, dynamic>.from(workspace));
      case 3:
        return const TracesScreen();
      case 4:
        return const ReplayScreen();
      case 5:
        return const WorkspaceScreen();
      case 6:
        return const GovernanceScreen();
      case 7:
        return const SettingsScreen();
      case 8:
        return const MockServiceScreen();
      case 9:
        return const LoadTestScreen();
      case 10:
        return const SchemaValidatorScreen();
      case 11:
        return const TestDataGeneratorScreen();
      case 12:
        return const FailureInjectionScreen();
      case 13:
        return const MutationTestingScreen();
      case 14:
        return const WorkflowsScreen();
      case 15:
        return const WebhooksScreen();
      case 16:
        return const SecretsVaultScreen();
      case 17:
        return const AuditLogsScreen();
      case 18:
        return const AlertsScreen();
      case 19:
        return const EnvironmentScreen();
      case 20:
        return const MonitoringScreen();
      case 21:
        return const PercentileCalculatorScreen();
      case 22:
        return const TracingConfigScreen();
      case 23:
        return const WaterfallScreen();
      default:
        return _buildDashboard(workspaceProvider, traceProvider);
    }
  }

  Widget _buildDashboard(WorkspaceProvider workspaceProvider, TraceProvider traceProvider) {
    final authProvider = context.read<AuthProvider>();
    final dashboardProvider = context.watch<DashboardProvider>();
    final userName = authProvider.user?['name']?.toString().split(' ')[0] ?? 'User';
    final workspaceName = workspaceProvider.selectedWorkspace?['name'] ?? 'No Workspace';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Header
          FadeSlideIn(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back, $userName 👋',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          'Here\'s what\'s happening in $workspaceName',
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                        ),
                        if (dashboardProvider.lastRefreshed != null) ...[
                          const SizedBox(width: 12),
                          Icon(Icons.access_time, size: 12, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(
                            'Updated ${_formatLastRefreshed(dashboardProvider.lastRefreshed!)}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade700),
                      const SizedBox(width: 8),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedTimeRange,
                          items: ['Today', 'This Week', 'This Month']
                              .map((r) => DropdownMenuItem(value: r, child: Text(r, style: TextStyle(fontSize: 12, color: Colors.grey.shade900))))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _selectedTimeRange = v);
                          },
                          icon: Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Quick Actions
          FadeSlideIn(
            delay: const Duration(milliseconds: 50),
            child: Text('QUICK ACTIONS', style: _sectionLabelStyle()),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildQuickAction(Icons.play_arrow, 'New Request', () => setState(() => _selectedNav = 1), 0),
              const SizedBox(width: 12),
              _buildQuickAction(Icons.workspaces_outlined, 'New Workspace', () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkspaceSetupScreen()));
              }, 1),
              const SizedBox(width: 12),
              _buildQuickAction(Icons.folder_outlined, 'Collections', () => setState(() => _selectedNav = 2), 2),
              const SizedBox(width: 12),
              _buildQuickAction(Icons.replay, 'Replay Trace', () => setState(() => _selectedNav = 4), 3),
              const SizedBox(width: 12),
              _buildQuickAction(Icons.timeline, 'View Traces', () => setState(() => _selectedNav = 3), 4),
              const SizedBox(width: 12),
              _buildQuickAction(Icons.policy, 'Governance', () => setState(() => _selectedNav = 6), 5),
            ],
          ),
          const SizedBox(height: 32),

          // Metrics
          FadeSlideIn(
            delay: const Duration(milliseconds: 150),
            child: Text('WORKSPACE METRICS', style: _sectionLabelStyle()),
          ),
          const SizedBox(height: 12),
          dashboardProvider.isLoading
              ? Row(
                  children: [
                    Expanded(child: ShimmerCard(height: 90)),
                    const SizedBox(width: 16),
                    Expanded(child: ShimmerCard(height: 90)),
                    const SizedBox(width: 16),
                    Expanded(child: ShimmerCard(height: 90)),
                    const SizedBox(width: 16),
                    Expanded(child: ShimmerCard(height: 90)),
                  ],
                )
              : Row(
                  children: [
                    _buildAnimatedMetricCard('Total Requests', traceProvider.traces.length > 0 ? traceProvider.traces.length * 5 : 0, Icons.http, 0),
                    const SizedBox(width: 16),
                    _buildAnimatedMetricCard('Collections', workspaceProvider.workspaces.length, Icons.folder, 1),
                    const SizedBox(width: 16),
                    _buildAnimatedMetricCard('Traces', traceProvider.traces.length, Icons.timeline, 2),
                    const SizedBox(width: 16),
                    _buildAnimatedMetricCard('Workspaces', workspaceProvider.workspaces.length, Icons.workspaces, 3),
                  ],
                ),
          const SizedBox(height: 32),

          // Core Tools Grid
          Text('CORE TOOLS', style: _sectionLabelStyle()),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.3,
            children: [
              _buildToolCard('Request Studio', 'Build & test API requests with full control', Icons.edit_note, 'Core', () => setState(() => _selectedNav = 1)),
              _buildToolCard('Traces & Waterfall', 'Visualize distributed traces with span analysis', Icons.timeline, 'Observability', () => setState(() => _selectedNav = 3)),
              _buildToolCard('Replay Engine', 'Reproduce bugs by replaying historical traces', Icons.replay_circle_filled, 'Debug', () => setState(() => _selectedNav = 4)),
              _buildToolCard('Workspaces', 'Manage workspaces, collections & team access', Icons.workspaces, 'Management', () => setState(() => _selectedNav = 5)),
            ],
          ),
          const SizedBox(height: 32),

          // All Services Grid
          Text('ALL SERVICES', style: _sectionLabelStyle()),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _buildServiceCard('Trace Service', 'Capture & store spans', Icons.timeline, Colors.blue),
              _buildServiceCard('Waterfall', 'Visualize span trees', Icons.waterfall_chart, Colors.indigo),
              _buildServiceCard('Tracing Config', 'Sampling rules', Icons.tune, Colors.purple),
              _buildServiceCard('Percentile Calc', 'P95/P99 analysis', Icons.analytics, Colors.deepPurple),
              _buildServiceCard('Replay Engine', 'Reproduce bugs', Icons.replay, Colors.teal),
              _buildServiceCard('Test Data Gen', 'Realistic mock data', Icons.data_array, Colors.green),
              _buildServiceCard('Mock Service', 'Simulate APIs', Icons.cloud_off, Colors.orange),
              _buildServiceCard('Load Testing', 'Stress test APIs', Icons.speed, Colors.red),
              _buildServiceCard('Failure Injection', 'Chaos engineering', Icons.warning_amber, Colors.deepOrange),
              _buildServiceCard('Workflow Engine', 'Chain API scenarios', Icons.account_tree, Colors.cyan),
              _buildServiceCard('Request Service', 'HTTP client wrapper', Icons.http, Colors.blueGrey),
              _buildServiceCard('Schema Validator', 'Contract validation', Icons.verified, Colors.lightGreen),
              _buildServiceCard('Mutation Testing', 'Fuzz test variables', Icons.shuffle, Colors.amber),
              _buildServiceCard('Workspace Svc', 'Multi-tenant isolation', Icons.workspaces, Colors.grey),
              _buildServiceCard('Auth Service', 'JWT & Bcrypt security', Icons.security, Colors.brown),
              _buildServiceCard('Secrets Vault', 'Encrypted key mgmt', Icons.lock, Colors.pink),
              _buildServiceCard('Webhook Service', 'Event notifications', Icons.webhook, Colors.lime),
              _buildServiceCard('Audit Service', 'Action logging', Icons.history, Colors.blue),
              _buildServiceCard('Settings Svc', 'User preferences', Icons.settings, Colors.blueGrey),
              _buildServiceCard('Environment Svc', 'Dev/Staging/Prod', Icons.swap_horiz, Colors.indigo),
              _buildServiceCard('Governance', 'PII masking & policies', Icons.policy, Colors.deepPurple),
              _buildServiceCard('Session Svc', 'Debug sessions', Icons.access_time, Colors.teal),
              _buildServiceCard('Monitoring', 'System health', Icons.monitor_heart, Colors.red),
              _buildServiceCard('Alerting', 'Threshold alerts', Icons.notifications_active, Colors.orange),
              _buildServiceCard('Collections', 'Organize API suites', Icons.folder, Colors.cyan),
            ],
          ),
          const SizedBox(height: 32),

          // Recent Traces
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: _buildRecentActivitySection()),
              const SizedBox(width: 20),
              Expanded(child: _buildRecentTracesSection(traceProvider)),
            ],
          ),
          const SizedBox(height: 32),

          // System status footer
          _buildSystemStatusFooter(traceProvider),
        ],
      ),
    );
  }

  TextStyle _sectionLabelStyle() => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: Colors.grey.shade500,
    letterSpacing: 0.8,
  );

  String _formatLastRefreshed(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 10) return 'just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  Widget _buildQuickAction(IconData icon, String label, VoidCallback onTap, int index) {
    return Expanded(
      child: FadeSlideIn(
        delay: Duration(milliseconds: 80 + index * 50),
        child: HoverScaleCard(
          onTap: onTap,
          hoverScale: 1.04,
          hoverElevation: 6,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 6),
                Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade900)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedMetricCard(String title, int value, IconData icon, int index) {
    return Expanded(
      child: FadeSlideIn(
        delay: Duration(milliseconds: 200 + index * 60),
        child: HoverScaleCard(
          hoverScale: 1.03,
          hoverElevation: 6,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: Colors.grey.shade700),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    const SizedBox(height: 2),
                    AnimatedCounter(
                      value: value,
                      duration: const Duration(milliseconds: 1200),
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.grey.shade900),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolCard(String title, String desc, IconData icon, String badge, VoidCallback onTap) {
    return HoverScaleCard(
      onTap: onTap,
      hoverScale: 1.03,
      hoverElevation: 8,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, size: 18, color: Colors.grey.shade700),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                  child: Text(badge, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade900)),
            const SizedBox(height: 4),
            Text(desc, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(String title, String desc, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade900)),
          const SizedBox(height: 2),
          Text(desc, style: TextStyle(fontSize: 9, color: Colors.grey.shade500), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    final dashboardProvider = context.watch<DashboardProvider>();
    final activities = dashboardProvider.recentActivity;

    return FadeSlideIn(
      delay: const Duration(milliseconds: 400),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent Activity', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade900)),
            const SizedBox(height: 14),
            if (activities.isEmpty) ...[
              _buildActivityItem('New request created', 'GET /api/users/123', '2 minutes ago', Icons.play_arrow),
              _buildActivityItem('Trace replayed', 'Failed payment transaction', '15 minutes ago', Icons.replay),
              _buildActivityItem('Collection updated', 'User Management API', '1 hour ago', Icons.folder),
              _buildActivityItem('Schema validated', 'Order creation endpoint', '3 hours ago', Icons.verified),
              _buildActivityItem('Waterfall analyzed', 'Payment service dependency', '5 hours ago', Icons.waterfall_chart),
            ] else
              ...activities.map((a) {
                final iconMap = <String, IconData>{
                  'play_arrow': Icons.play_arrow,
                  'timeline': Icons.timeline,
                  'folder': Icons.folder,
                  'workspaces': Icons.workspaces,
                  'verified': Icons.verified,
                  'replay': Icons.replay,
                  'history': Icons.history,
                };
                return _buildActivityItem(
                  a['action'] ?? '',
                  a['target'] ?? '',
                  a['time'] ?? '',
                  iconMap[a['icon']] ?? Icons.history,
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(String action, String target, String time, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
            child: Icon(icon, size: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(action, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade900)),
                Text(target, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Text(time, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildRecentTracesSection(TraceProvider traceProvider) {
    final recentTraces = traceProvider.traces.take(5).toList();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent Traces', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade900)),
              IconButton(
                icon: Icon(Icons.refresh, size: 14, color: Colors.grey.shade600),
                onPressed: _loadDashboardData,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (recentTraces.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.timeline, size: 28, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text('No traces yet', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Text('Send API requests to see traces', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                  ],
                ),
              ),
            )
          else
            ...recentTraces.map((trace) {
              final duration = trace['duration'] ?? 0;
              final isError = trace['status'] == 'error';
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () => setState(() => _selectedNav = 3),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: isError ? Colors.red.shade50 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Icon(
                          isError ? Icons.error_outline : Icons.timeline,
                          size: 12,
                          color: isError ? Colors.red.shade700 : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(trace['service'] ?? trace['service_name'] ?? 'Service', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade900)),
                            Text('${duration}ms · ${trace['span_count'] ?? 0} spans', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSystemStatusFooter(TraceProvider traceProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          _buildStatChip('Traces', '${traceProvider.traces.length}', Icons.timeline),
          const SizedBox(width: 20),
          _buildStatChip('Status', 'Healthy', Icons.check_circle),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(Icons.circle, size: 8, color: Colors.green.shade600),
                const SizedBox(width: 6),
                Text('Backend Connected', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green.shade700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Text('$label:', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        const SizedBox(width: 4),
        Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade900)),
      ],
    );
  }

  Widget _buildUnauthenticatedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('Please login to continue', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: widget.onNavigateToAuth,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade900,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }
}