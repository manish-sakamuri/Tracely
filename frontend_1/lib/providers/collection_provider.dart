import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CollectionProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<dynamic> _collections = [];
  List<dynamic> _requests = [];
  Map<String, dynamic>? _selectedCollection;
  bool _isLoading = false;
  String? _errorMessage;
  
  List<dynamic> get collections => _collections;
  List<dynamic> get requests => _requests;
  Map<String, dynamic>? get selectedCollection => _selectedCollection;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadCollections(String workspaceId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      _collections = await _apiService.getCollections(workspaceId);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createCollection(String workspaceId, String name, {String? description}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      await _apiService.createCollection(workspaceId, name, description: description);
      await loadCollections(workspaceId);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteCollection(String workspaceId, String collectionId) async {
    try {
      await _apiService.deleteCollection(workspaceId, collectionId);
      await loadCollections(workspaceId);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }

  void selectCollection(Map<String, dynamic> collection) {
    _selectedCollection = collection;
    notifyListeners();
  }

  Future<void> loadRequests(String workspaceId, String collectionId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      _requests = await _apiService.getCollectionRequests(workspaceId, collectionId);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _requests = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Import a Postman-format JSON collection
  /// Supports both Postman Collection v2.0 and v2.1 formats
  Future<bool> importFromJson(String workspaceId, String jsonString) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = json.decode(jsonString);
      
      // Extract collection info from Postman format
      String collectionName;
      List<dynamic> items;

      if (data['info'] != null) {
        // Postman v2.x format
        collectionName = data['info']['name'] ?? data['info']['_postman_id'] ?? 'Imported Collection';
        items = data['item'] ?? [];
      } else if (data['name'] != null && data['requests'] != null) {
        // Simple format
        collectionName = data['name'];
        items = data['requests'] ?? [];
      } else if (data['name'] != null) {
        // Direct collection format
        collectionName = data['name'];
        items = data['item'] ?? data['requests'] ?? [];
      } else {
        throw Exception('Unrecognized collection format');
      }

      // Create the collection
      final description = data['info']?['description'] ?? data['description'] ?? 'Imported collection';
      await _apiService.createCollection(workspaceId, collectionName, description: description);
      
      // Reload to get the new collection ID
      await loadCollections(workspaceId);
      
      // Find the newly created collection
      final newCollection = _collections.firstWhere(
        (c) => c['name'] == collectionName,
        orElse: () => null,
      );

      if (newCollection != null) {
        final collectionId = newCollection['id']?.toString() ?? '';
        
        // Import each request
        for (final item in items) {
          try {
            final requestData = _parsePostmanItem(item);
            if (requestData != null) {
              await _apiService.createRequest(workspaceId, collectionId, requestData);
            }
          } catch (e) {
            // Continue importing other items even if one fails
            debugPrint('Failed to import item: $e');
          }
        }
      }

      await loadCollections(workspaceId);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Import failed: ${e.toString().replaceAll('Exception: ', '')}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Parse a Postman item into a request data map
  Map<String, dynamic>? _parsePostmanItem(Map<String, dynamic> item) {
    final request = item['request'];
    if (request == null) return null;

    String method;
    String url;
    Map<String, String> headers = {};
    String? body;

    if (request is String) {
      // Simple format: just a URL
      method = 'GET';
      url = request;
    } else {
      method = (request['method'] ?? 'GET').toString().toUpperCase();
      
      // Parse URL
      if (request['url'] is String) {
        url = request['url'];
      } else if (request['url'] is Map) {
        url = request['url']['raw'] ?? '';
      } else {
        url = '';
      }

      // Parse headers
      if (request['header'] is List) {
        for (final h in request['header']) {
          if (h is Map && h['key'] != null) {
            headers[h['key']] = h['value']?.toString() ?? '';
          }
        }
      }

      // Parse body
      if (request['body'] != null) {
        final bodyData = request['body'];
        if (bodyData['raw'] != null) {
          body = bodyData['raw'];
        } else if (bodyData['formdata'] != null) {
          body = json.encode(bodyData['formdata']);
        }
      }
    }

    return {
      'name': item['name'] ?? 'Unnamed Request',
      'method': method,
      'url': url,
      'headers': headers,
      if (body != null) 'body': body,
    };
  }

  /// Export a collection and its requests as Postman-compatible JSON
  Future<String?> exportToJson(String workspaceId, String collectionId) async {
    try {
      final collection = await _apiService.getCollectionById(workspaceId, collectionId);
      
      List<dynamic> requestsList = [];
      try {
        requestsList = await _apiService.getCollectionRequests(workspaceId, collectionId);
      } catch (e) {
        requestsList = _requests;
      }

      final exportData = {
        'info': {
          'name': collection['name'] ?? 'Exported Collection',
          'description': collection['description'] ?? '',
          'schema': 'https://schema.getpostman.com/json/collection/v2.1.0/collection.json',
        },
        'item': requestsList.map((req) {
          return {
            'name': req['name'] ?? 'Request',
            'request': {
              'method': req['method'] ?? 'GET',
              'header': (req['headers'] is Map)
                  ? (req['headers'] as Map).entries.map((e) => {'key': e.key, 'value': e.value}).toList()
                  : [],
              'url': {
                'raw': req['url'] ?? '',
              },
              if (req['body'] != null)
                'body': {
                  'mode': 'raw',
                  'raw': req['body'] is String ? req['body'] : json.encode(req['body']),
                },
            },
          };
        }).toList(),
      };

      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(exportData);
    } catch (e) {
      _errorMessage = 'Export failed: ${e.toString().replaceAll('Exception: ', '')}';
      notifyListeners();
      return null;
    }
  }

  /// Helper for WorkspaceScreen stats
  List<dynamic> getCollectionsByWorkspace(String workspaceId) {
    // Return empty list if current collections don't match, 
    // or return the current list (since we only load one workspace at a time)
    return _collections;
  }

  /// Helper for WorkspaceScreen stats
  List<dynamic> getRequestsByCollection(String collectionId) {
    // Return the current requests if they belong to this collection
    return _requests;
  }
}
