// lib/screens/workspace_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/workspace_provider.dart';
import '../providers/collection_provider.dart';
import '../providers/auth_provider.dart';
import 'workspace_setup_screen.dart';
import 'collections_screen.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({Key? key}) : super(key: key);

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWorkspaces();
    });
  }

  Future<void> _loadWorkspaces() async {
    final workspaceProvider = context.read<WorkspaceProvider>();
    await workspaceProvider.loadWorkspaces();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value.toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<WorkspaceProvider, CollectionProvider, AuthProvider>(
      builder: (context, workspaceProvider, collectionProvider, authProvider, child) {
        return Container(
          color: const Color(0xFFFAFAFA),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Workspaces',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage your API collections and requests',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    _buildNewWorkspaceButton(),
                  ],
                ),
                const SizedBox(height: 24),

                // Search bar
                _buildSearchBar(),
                const SizedBox(height: 20),

                // Stats
                _buildStatsSection(workspaceProvider, collectionProvider),
                const SizedBox(height: 24),

                // Workspaces grid
                Text(
                  'Your Workspaces',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade900,
                  ),
                ),
                const SizedBox(height: 16),
                _buildWorkspacesGrid(workspaceProvider),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar(AuthProvider authProvider, WorkspaceProvider workspaceProvider) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Text(
            'Tracely',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade900,
            ),
          ),
          const SizedBox(width: 60),
          _buildTopNavItem('Dashboard', false),
          _buildTopNavItem('Workspace', true),
          _buildTopNavItem('Collections', false),
          _buildTopNavItem('Monitors', false),
          const Spacer(),
          if (authProvider.isAuthenticated)
            IconButton(
              icon: const Icon(Icons.logout, size: 20),
              onPressed: () async {
                await authProvider.logout();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Logged out')),
                  );
                }
              },
              tooltip: 'Logout',
            ),
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey.shade900,
            child: Text(
              () {
                final name = authProvider.user?['name']?.toString() ?? "";
                return name.isNotEmpty ? name[0].toUpperCase() : "U";
              }(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopNavItem(String text, bool isActive) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive ? Colors.grey.shade900 : Colors.grey.shade600,
            ),
          ),
          if (isActive) ...[
            const SizedBox(height: 22),
            Container(
              height: 3,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNewWorkspaceButton() {
    return ElevatedButton.icon(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const WorkspaceSetupScreen(),
          ),
        ).then((_) => _loadWorkspaces());
      },
      icon: const Icon(Icons.add, size: 18),
      label: const Text('New Workspace'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey.shade900,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      width: 400,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(Icons.search, size: 18, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search workspaces...',
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                ),
                border: InputBorder.none,
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear, size: 16, color: Colors.grey.shade500),
              onPressed: () {
                _searchController.clear();
                _onSearchChanged('');
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(
    WorkspaceProvider workspaceProvider,
    CollectionProvider collectionProvider,
  ) {
    final workspaces = workspaceProvider.workspaces;
    int totalCollections = 0;
    int totalRequests = 0;

    for (var workspace in workspaces) {
      final collections = collectionProvider.getCollectionsByWorkspace(workspace['id']?.toString() ?? '');
      totalCollections += collections.length;
      for (var collection in collections) {
        totalRequests += collectionProvider.getRequestsByCollection(collection['id']?.toString() ?? '').length;
      }
    }

    return Row(
      children: [
        _buildStatCard('Total Workspaces', '${workspaces.length}', Icons.workspaces),
        const SizedBox(width: 16),
        _buildStatCard('Collections', '$totalCollections', Icons.folder),
        const SizedBox(width: 16),
        _buildStatCard('Recent Requests', '$totalRequests', Icons.history),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: Colors.grey.shade700),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade900,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspacesGrid(WorkspaceProvider workspaceProvider) {
    final workspaces = workspaceProvider.workspaces.where((workspace) {
      final name = workspace['name']?.toString().toLowerCase() ?? '';
      return _searchQuery.isEmpty || name.contains(_searchQuery);
    }).toList();

    if (workspaces.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 48),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.workspaces_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty ? 'No workspaces yet' : 'No matching workspaces',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            if (_searchQuery.isEmpty)
              Text(
                'Create your first workspace to get started',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 1.2,
      ),
      itemCount: workspaces.length,
      itemBuilder: (context, index) {
        final workspace = workspaces[index];
        return _buildWorkspaceCard(workspace);
      },
    );
  }

  Widget _buildWorkspaceCard(Map<String, dynamic> workspace) {
    final color = _getWorkspaceColor(workspace['id']);
    
    return GestureDetector(
      onTap: () async {
        // Select workspace and navigate to collections
        await context.read<WorkspaceProvider>().selectWorkspace(workspace['id']?.toString() ?? '');
        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CollectionScreen(workspace: workspace),
          ),
        );
      },
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
            // Header with icon and menu
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.workspaces_outlined,
                    color: color,
                    size: 24,
                  ),
                ),
                const Spacer(),
                PopupMenuButton(
                  icon: Icon(Icons.more_vert, size: 20, color: Colors.grey.shade600),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 16, color: Colors.grey.shade700),
                          const SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 16, color: Colors.red.shade400),
                          const SizedBox(width: 8),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) async {
                    if (value == 'delete') {
                      await _showDeleteDialog(workspace);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Workspace name
            Text(
              workspace['name'] ?? 'Untitled Workspace',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Description
            Text(
              workspace['description'] ?? 'No description',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            // Stats
            Consumer<CollectionProvider>(
              builder: (context, collectionProvider, child) {
                final collections = collectionProvider
                    .getCollectionsByWorkspace(workspace['id']?.toString() ?? '');
                final requestCount = collections.fold<int>(
                  0,
                  (sum, collection) => sum + collectionProvider
                      .getRequestsByCollection(collection['id']?.toString() ?? '').length,
                );
                
                return Row(
                  children: [
                    Icon(Icons.folder_outlined, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      '${collections.length} collections',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.link, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      '$requestCount requests',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _getWorkspaceColor(String id) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
    ];
    final hash = id.hashCode.abs();
    return colors[hash % colors.length];
  }

  Future<void> _showDeleteDialog(Map<String, dynamic> workspace) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Workspace'),
        content: Text(
          'Are you sure you want to delete "${workspace['name']}"? '
          'This action cannot be undone and all collections and requests will be lost.',
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await context
                  .read<WorkspaceProvider>()
                  .deleteWorkspace(workspace['id']);
              if (success && mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Workspace "${workspace['name']}" deleted'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}