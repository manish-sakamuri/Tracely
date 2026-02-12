// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/workspace_provider.dart';
import '../providers/trace_provider.dart';
import '../providers/request_provider.dart';
import '../providers/collection_provider.dart';
import '../screens/workspaces_screen.dart';
import '../screens/request_studio_screen.dart';
import '../screens/trace_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/replay_screen.dart';
import '../screens/workspace_setup_screen.dart';
import '../screens/collections_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedTimeRange = 'Today';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    final workspaceProvider = context.read<WorkspaceProvider>();
    final traceProvider = context.read<TraceProvider>();
    final requestProvider = context.read<RequestProvider>();
    
    if (workspaceProvider.selectedWorkspaceId != null) {
      await traceProvider.fetchTraces(workspaceProvider.selectedWorkspaceId!);
      await requestProvider.fetchRecentRequests();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Consumer3<AuthProvider, WorkspaceProvider, TraceProvider>(
        builder: (context, authProvider, workspaceProvider, traceProvider, child) {
          if (!authProvider.isAuthenticated) {
            return _buildUnauthenticatedView();
          }

          return Column(
            children: [
              _buildTopBar(authProvider, workspaceProvider),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome Header
                      _buildWelcomeHeader(authProvider, workspaceProvider),
                      const SizedBox(height: 32),

                      // Quick Actions Row
                      _buildQuickActionsSection(),
                      const SizedBox(height: 40),

                      // Metrics Grid
                      _buildMetricsSection(),
                      const SizedBox(height: 40),

                      // Main Tools Grid
                      _buildToolsGrid(),
                      const SizedBox(height: 40),

                      // Advanced Tools Section
                      _buildAdvancedToolsSection(),
                      const SizedBox(height: 40),

                      // Recent Activity and Traces
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildRecentActivitySection(),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildRecentTracesSection(traceProvider),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),

                      // Quick Stats Footer
                      _buildQuickStatsFooter(),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopBar(AuthProvider authProvider, WorkspaceProvider workspaceProvider) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Text(
            'Tracely',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(width: 48),
          
          // Navigation
          _buildNavItem('Dashboard', true),
          _buildNavItem('Workspaces', false, onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const WorkspaceScreen()),
            );
          }),
          _buildNavItem('Traces', false, onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TracesScreen()),
            );
          }),
          
          const Spacer(),
          
          // Workspace Selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.workspaces_outlined, size: 16, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                Text(
                  workspaceProvider.selectedWorkspace?['name'] ?? 'Select Workspace',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade900,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey.shade700),
              ],
            ),
          ),
          const SizedBox(width: 16),
          
          // User Menu
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey.shade900,
            child: Text(
              authProvider.user?['name']?.toString().substring(0, 1).toUpperCase() ?? 'U',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(String label, bool isActive, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? Colors.grey.shade900 : Colors.grey.shade600,
              ),
            ),
            if (isActive) ...[
              const SizedBox(height: 20),
              Container(
                height: 3,
                width: 24,
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader(AuthProvider authProvider, WorkspaceProvider workspaceProvider) {
    final userName = authProvider.user?['name']?.toString().split(' ')[0] ?? 'User';
    final workspaceName = workspaceProvider.selectedWorkspace?['name'] ?? 'No Workspace';
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back, $userName 👋',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Here\'s what\'s happening in $workspaceName',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        Row(
          children: [
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
                      items: ['Today', 'This Week', 'This Month', 'Custom']
                          .map((range) => DropdownMenuItem(
                                value: range,
                                child: Text(
                                  range,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade900,
                                  ),
                                ),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedTimeRange = value);
                          _loadDashboardData();
                        }
                      },
                      icon: Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 280,
              height: 40,
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
                        hintText: 'Search APIs, traces, collections...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                        border: InputBorder.none,
                      ),
                      onChanged: (value) => setState(() => _searchQuery = value),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.close, size: 16, color: Colors.grey.shade500),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUICK ACTIONS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildQuickAction(
              icon: Icons.play_arrow,
              label: 'New Request',
              color: Colors.grey.shade900,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RequestStudioScreen()),
                );
              },
            ),
            const SizedBox(width: 12),
            _buildQuickAction(
              icon: Icons.workspaces_outlined,
              label: 'New Workspace',
              color: Colors.grey.shade800,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const WorkspaceSetupScreen()),
                );
              },
            ),
            const SizedBox(width: 12),
            _buildQuickAction(
              icon: Icons.folder_outlined,
              label: 'New Collection',
              color: Colors.grey.shade700,
              onTap: () {
                // Show create collection dialog
              },
            ),
            const SizedBox(width: 12),
            _buildQuickAction(
              icon: Icons.replay,
              label: 'Replay Trace',
              color: Colors.grey.shade600,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ReplayScreen()),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WORKSPACE METRICS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildMetricCard(
              title: 'Total Requests',
              value: '2,847',
              change: '+12.3%',
              icon: Icons.http,
              isPositive: true,
            ),
            const SizedBox(width: 20),
            _buildMetricCard(
              title: 'Collections',
              value: '24',
              change: '+3',
              icon: Icons.folder,
              isPositive: true,
            ),
            const SizedBox(width: 20),
            _buildMetricCard(
              title: 'Traces',
              value: '1,234',
              change: '+8.2%',
              icon: Icons.timeline,
              isPositive: true,
            ),
            const SizedBox(width: 20),
            _buildMetricCard(
              title: 'Error Rate',
              value: '2.4%',
              change: '-0.8%',
              icon: Icons.error_outline,
              isPositive: false,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String change,
    required IconData icon,
    required bool isPositive,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: Colors.grey.shade700),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isPositive
                              ? Colors.green.shade50
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          change,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isPositive
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolsGrid() {
    final tools = [
      {
        'title': 'Request Studio',
        'description': 'Build and test API requests with full control over headers, body, and authentication',
        'icon': Icons.edit_note,
        'color': Colors.grey.shade900,
        'badge': 'Core',
        'route': const RequestStudioScreen(),
      },
      {
        'title': 'Traces & Waterfall',
        'description': 'Visualize distributed traces with waterfall charts and span analysis',
        'icon': Icons.timeline,
        'color': Colors.grey.shade800,
        'badge': 'Observability',
        'route': const TracesScreen(),
      },
      {
        'title': 'Replay',
        'description': 'Replay historical traces to debug and reproduce issues',
        'icon': Icons.replay_circle_filled,
        'color': Colors.grey.shade700,
        'badge': 'Debug',
        'route': const ReplayScreen(),
      },
      {
        'title': 'Workspaces',
        'description': 'Manage workspaces, collections, and team permissions',
        'icon': Icons.workspaces,
        'color': Colors.grey.shade600,
        'badge': 'Management',
        'route': const WorkspaceScreen(),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CORE TOOLS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: 1.2,
          ),
          itemCount: tools.length,
          itemBuilder: (context, index) {
            final tool = tools[index];
            return _buildToolCard(tool);
          },
        ),
      ],
    );
  }

  Widget _buildToolCard(Map<String, dynamic> tool) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => tool['route']),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (tool['color'] as Color).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    tool['icon'] as IconData,
                    size: 20,
                    color: tool['color'] as Color,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    tool['badge'] as String,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              tool['title'] as String,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tool['description'] as String,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedToolsSection() {
    final advancedTools = [
      {
        'title': 'Test Data Generator',
        'description': 'Generate realistic test data for your APIs with customizable schemas',
        'icon': Icons.data_array,
        'route': const Placeholder(),
        'tags': ['Mock Data', 'Faker'],
      },
      {
        'title': 'Schema Validator',
        'description': 'Validate API requests and responses against JSON schemas',
        'icon': Icons.verified,
        'route': const Placeholder(),
        'tags': ['JSON Schema', 'Validation'],
      },
      {
        'title': 'Waterfall Services',
        'description': 'Deep dive into service dependencies and latency breakdowns',
        'icon': Icons.vertical_distribute,
        'route': const Placeholder(),
        'tags': ['Dependencies', 'Latency'],
      },
      {
        'title': 'Settings',
        'description': 'Configure workspace settings, team permissions, and integrations',
        'icon': Icons.settings,
        'route': const SettingsScreen(),
        'tags': ['Preferences', 'Team'],
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ADVANCED TOOLS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
                letterSpacing: 0.8,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: Text(
                'View All →',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: 1.3,
          ),
          itemCount: advancedTools.length,
          itemBuilder: (context, index) {
            final tool = advancedTools[index];
            return _buildAdvancedToolCard(tool);
          },
        ),
      ],
    );
  }

  Widget _buildAdvancedToolCard(Map<String, dynamic> tool) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => tool['route']),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    tool['icon'] as IconData,
                    size: 16,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tool['title'] as String,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              tool['description'] as String,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: (tool['tags'] as List<String>).map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey.shade700,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildActivityItem(
            'New request created',
            'GET /api/users/123',
            '2 minutes ago',
            Icons.play_arrow,
          ),
          _buildActivityItem(
            'Trace replayed',
            'Failed payment transaction',
            '15 minutes ago',
            Icons.replay,
          ),
          _buildActivityItem(
            'Collection updated',
            'User Management API',
            '1 hour ago',
            Icons.folder,
          ),
          _buildActivityItem(
            'Schema validated',
            'Order creation endpoint',
            '3 hours ago',
            Icons.verified,
          ),
          _buildActivityItem(
            'Waterfall analyzed',
            'Payment service dependency',
            '5 hours ago',
            Icons.vertical_distribute,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String action, String target, String time, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade900,
                  ),
                ),
                Text(
                  target,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTracesSection(TraceProvider traceProvider) {
    final recentTraces = traceProvider.traces.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Traces',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                ),
              ),
              IconButton(
                icon: Icon(Icons.refresh, size: 16, color: Colors.grey.shade600),
                onPressed: _loadDashboardData,
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (recentTraces.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(Icons.timeline, size: 32, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text(
                      'No traces yet',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...recentTraces.map((trace) => _buildTraceItem(trace)),
        ],
      ),
    );
  }

  Widget _buildTraceItem(Map<String, dynamic> trace) {
    final duration = trace['duration'] ?? 0;
    final isError = trace['status'] == 'error';
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TracesScreen(),
            ),
          );
        },
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isError ? Colors.red.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                isError ? Icons.error_outline : Icons.timeline,
                size: 12,
                color: isError ? Colors.red.shade700 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trace['service'] ?? 'Unknown Service',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  Text(
                    '${duration}ms · ${trace['span_count'] ?? 0} spans',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getDurationColor(duration).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${duration}ms',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _getDurationColor(duration),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getDurationColor(int duration) {
    if (duration < 100) return Colors.green.shade600;
    if (duration < 500) return Colors.orange.shade600;
    return Colors.red.shade600;
  }

  Widget _buildQuickStatsFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          _buildStatChip('API Calls', '2.8K', Icons.http),
          const SizedBox(width: 24),
          _buildStatChip('Avg Latency', '124ms', Icons.speed),
          const SizedBox(width: 24),
          _buildStatChip('Success Rate', '97.6%', Icons.check_circle),
          const SizedBox(width: 24),
          _buildStatChip('Active Traces', '23', Icons.timeline),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(Icons.bolt, size: 14, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  'System Healthy',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
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
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade900,
          ),
        ),
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
          Text(
            'Please login to continue',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // Navigate to login
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade900,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }
}