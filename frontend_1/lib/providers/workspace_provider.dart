import 'package:flutter/material.dart';
import '../services/api_service.dart';

// Workspace type enum with 3 types: personal, internal (team), partner, enterprise
enum WorkspaceType { personal, internal, partner, enterprise }
enum AccessType { teamOnly, inviteOnly, open }

class WorkspaceProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<dynamic> _workspaces = [];
  String? _selectedWorkspaceId;
  bool _isLoading = false;
  String? _errorMessage;
  
  List<dynamic> get workspaces => _workspaces;
  String? get selectedWorkspaceId => _selectedWorkspaceId;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  dynamic get selectedWorkspace {
    if (_selectedWorkspaceId == null) return null;
    try {
      return _workspaces.firstWhere((w) => w['id'] == _selectedWorkspaceId);
    } catch (e) {
      return null;
    }
  }
  
  Future<void> loadWorkspaces() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      _workspaces = await _apiService.getWorkspaces();
      if (_workspaces.isNotEmpty && _selectedWorkspaceId == null) {
        final id = _workspaces[0]['id']?.toString();
        // Only set if we have a valid UUID-like value (avoid "null" or empty)
        if (id != null && id.trim().isNotEmpty && id != 'null') {
          _selectedWorkspaceId = id;
        }
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _workspaces = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  void selectWorkspace(String workspaceId) {
    _selectedWorkspaceId = workspaceId;
    notifyListeners();
  }

  void setSelectedWorkspace(Map<String, dynamic> workspace) {
    _selectedWorkspaceId = workspace['id'];
    notifyListeners();
  }
  
  /// Map WorkspaceType enum to API string
  static String typeToString(WorkspaceType type) {
    switch (type) {
      case WorkspaceType.personal:
        return 'personal';
      case WorkspaceType.internal:
        return 'internal';
      case WorkspaceType.partner:
        return 'partner';
      case WorkspaceType.enterprise:
        return 'enterprise';
    }
  }

  /// Map AccessType enum to API string
  static String accessToString(AccessType access) {
    switch (access) {
      case AccessType.teamOnly:
        return 'team';
      case AccessType.inviteOnly:
        return 'invite';
      case AccessType.open:
        return 'open';
    }
  }

  // Enhanced createWorkspace method for multi-step form
  Future<bool> createWorkspace({
    required String name,
    required WorkspaceType type,
    required bool isPublic,
    required AccessType accessType,
    String? description,
  }) async {
    try {
      _errorMessage = null;
      _isLoading = true;
      notifyListeners();
      
      final typeString = typeToString(type);
      final accessString = accessToString(accessType);
      
      final workspace = await _apiService.createWorkspace(
        name,
        description: description,
        type: typeString,
        isPublic: isPublic,
        accessType: accessString,
      );
      
      _workspaces.add(workspace);
      _selectedWorkspaceId = workspace['id'].toString();
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  // Keep the simple version for backward compatibility
  Future<bool> createSimpleWorkspace(String name, {String? description}) async {
    return await createWorkspace(
      name: name,
      type: WorkspaceType.internal,
      isPublic: false,
      accessType: AccessType.teamOnly,
      description: description,
    );
  }
  
  Future<bool> updateWorkspace(String workspaceId, Map<String, dynamic> data) async {
    try {
      _errorMessage = null;
      _isLoading = true;
      notifyListeners();

      await _apiService.updateWorkspace(workspaceId, data['name'], description: data['description']);

      final index = _workspaces.indexWhere((w) => w['id'] == workspaceId);
      if (index != -1) {
        _workspaces[index] = {
          ..._workspaces[index],
          ...data,
        };
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  Future<bool> deleteWorkspace(String workspaceId) async {
    try {
      _errorMessage = null;
      _isLoading = true;
      notifyListeners();
      
      await _apiService.deleteWorkspace(workspaceId);
      
      _workspaces.removeWhere((w) => w['id'].toString() == workspaceId.toString());
      
      if (_selectedWorkspaceId == workspaceId) {
        _selectedWorkspaceId = _workspaces.isNotEmpty ? _workspaces[0]['id'].toString() : null;
      }
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Initialize workspace with template defaults
  Future<bool> initializeWorkspace({
    required int templateId,
    required String name,
    String? description,
  }) async {
    try {
      _errorMessage = null;
      _isLoading = true;
      notifyListeners();

      final workspace = await _apiService.initializeWorkspace(
        name,
        description: description,
        templateId: templateId,
      );

      _workspaces.add(workspace);
      _selectedWorkspaceId = workspace['id'].toString();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
