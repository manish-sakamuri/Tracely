// lib/screens/collections_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/collection_provider.dart';
import '../providers/request_provider.dart';
import '../providers/workspace_provider.dart';
import '../screens/request_studio_screen.dart';
import '../widgets/animations.dart';

class CollectionScreen extends StatefulWidget {
  final Map<String, dynamic> workspace;

  const CollectionScreen({
    Key? key,
    required this.workspace,
  }) : super(key: key);

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  String _searchQuery = '';
  String? _selectedCollectionId;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _collectionNameController = TextEditingController();
  final TextEditingController _collectionDescController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCollections();
    });
  }

  Future<void> _loadCollections() async {
    await context.read<CollectionProvider>().loadCollections(widget.workspace['id']?.toString() ?? '');
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value.toLowerCase();
    });
  }

  Future<void> _createCollection() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Collection'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _collectionNameController,
              decoration: InputDecoration(
                labelText: 'Collection Name',
                hintText: 'e.g., User Management',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _collectionDescController,
              decoration: InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Describe this collection',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _collectionNameController.clear();
              _collectionDescController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_collectionNameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Collection name is required'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }

              final collectionProvider = context.read<CollectionProvider>();
              await collectionProvider.createCollection(
                widget.workspace['id']?.toString() ?? '',
                _collectionNameController.text.trim(),
                description: _collectionDescController.text.trim(),
              );

              if (mounted) {
                _collectionNameController.clear();
                _collectionDescController.clear();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Collection created successfully'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade900,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _createNewRequest() async {
    if (_selectedCollectionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a collection first'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Navigate to Request Studio
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RequestStudioScreen(),
      ),
    ).then((_) {
      // Refresh requests when returning
      setState(() {});
    });
  }

  Future<void> _importCollection() async {
    final importController = TextEditingController();
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.file_upload_outlined, color: Colors.grey.shade800),
            const SizedBox(width: 8),
            const Text('Import Collection'),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paste Postman Collection JSON below:',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              Container(
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: importController,
                  maxLines: null,
                  decoration: const InputDecoration(
                    hintText: '{\n  "info": {\n    "name": "My Collection"\n  },\n  "item": [...]\n}',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(12),
                  ),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final jsonText = importController.text.trim();
              if (jsonText.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please paste JSON content'),
                    backgroundColor: Colors.orange,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }

              Navigator.pop(context);
              final provider = context.read<CollectionProvider>();
              final success = await provider.importFromJson(
                widget.workspace['id']?.toString() ?? '',
                jsonText,
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Collection imported successfully!' : 'Import failed: ${provider.errorMessage}'),
                    backgroundColor: success ? Colors.green : Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            icon: const Icon(Icons.file_upload, size: 16),
            label: const Text('Import'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade900,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCollection() async {
    if (_selectedCollectionId == null) return;

    final provider = context.read<CollectionProvider>();
    final jsonString = await provider.exportToJson(
      widget.workspace['id']?.toString() ?? '',
      _selectedCollectionId!.toString(),
    );

    if (jsonString != null && mounted) {
      await Clipboard.setData(ClipboardData(text: jsonString));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Collection JSON copied to clipboard!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: ${provider.errorMessage}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: Row(
        children: [
          // Left Sidebar - Collections
          Container(
            width: 300,
            color: Colors.white,
            child: Column(
              children: [
                // Workspace header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.workspaces_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.workspace['name'] ?? 'Workspace',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Collections',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Search collections
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search collections...',
                      prefixIcon: const Icon(Icons.search, size: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),

                // New Collection button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _createCollection,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('New Collection'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Import / Export buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _importCollection,
                          icon: const Icon(Icons.file_upload_outlined, size: 14),
                          label: const Text('Import', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _selectedCollectionId != null ? _exportCollection : null,
                          icon: const Icon(Icons.file_download_outlined, size: 14),
                          label: const Text('Export', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Collections list
                Expanded(
                  child: Consumer<CollectionProvider>(
                    builder: (context, collectionProvider, child) {
                      final collections = collectionProvider
                          .collections
                          .where((collection) {
                        final name = collection['name']?.toString().toLowerCase() ?? '';
                        return _searchQuery.isEmpty || name.contains(_searchQuery);
                      }).toList();

                      if (collections.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.folder_outlined,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isEmpty
                                    ? 'No collections yet'
                                    : 'No matching collections',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (_searchQuery.isEmpty)
                                Text(
                                  'Create your first collection',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: collections.length,
                        itemBuilder: (context, index) {
                          final collection = collections[index];
                          final isSelected = _selectedCollectionId == collection['id'];
                          final requestCount = 0;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.grey.shade100 : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.grey.shade900
                                      : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.folder,
                                  size: 16,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey.shade600,
                                ),
                              ),
                              title: Text(
                                collection['name'] ?? 'Untitled',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.grey.shade900
                                      : Colors.grey.shade800,
                                ),
                              ),
                              subtitle: Text(
                                '$requestCount ${requestCount == 1 ? 'request' : 'requests'}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              selected: isSelected,
                              onTap: () {
                                setState(() {
                                  _selectedCollectionId = collection['id'];
                                });
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Right Content - Requests
          Expanded(
            child: _selectedCollectionId == null
                ? _buildNoCollectionSelected()
                : _buildRequestsView(),
          ),
        ],
      ),
    );
  }

  Widget _buildNoCollectionSelected() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.folder_outlined,
              size: 40,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Collection Selected',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a collection from the sidebar to view its requests',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _createCollection,
            icon: const Icon(Icons.add),
            label: const Text('Create New Collection'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade900,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsView() {
    return Consumer<CollectionProvider>(
      builder: (context, collectionProvider, child) {
        final requests = collectionProvider.requests;
        
        final collections = collectionProvider.collections;
        Map<String, dynamic>? collection;
        try {
          collection = collections.firstWhere((c) => c['id']?.toString() == _selectedCollectionId?.toString());
        } catch (e) {
          collection = {'name': 'Collection', 'description': ''};
        }

        return Column(
          children: [
            // Collection header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.folder,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          collection?['name'] ?? 'Collection',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          collection?['description'] ?? 'No description',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // New Request button
                  ElevatedButton.icon(
                    onPressed: _createNewRequest,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('New Request'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade900,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Requests list
            Expanded(
              child: requests.isEmpty
                  ? _buildEmptyRequests()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        final request = requests[index];
                        return _buildRequestCard(request);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyRequests() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.link_off,
              size: 40,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No requests yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first API request in this collection',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _createNewRequest,
            icon: const Icon(Icons.add),
            label: const Text('Create New Request'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade900,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final method = request['method'] ?? 'GET';
    final color = _getMethodColor(method);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () {
          // Load request and navigate to Request Studio
          context.read<RequestProvider>().setRequestData(request);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const RequestStudioScreen(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      method,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request['name'] ?? 'Untitled Request',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          request['path'] ?? '/api/endpoint',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatTimestamp(request['updated_at']),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.description_outlined, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    request['description'] ?? 'No description',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getMethodColor(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return Colors.blue;
      case 'POST':
        return Colors.green;
      case 'PUT':
        return Colors.amber;
      case 'DELETE':
        return Colors.red;
      case 'PATCH':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (e) {
      return timestamp;
    }
  }
}