import 'package:flutter/material.dart';
import '../services/api_service.dart';

class TracingConfigProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<dynamic> _configs = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isTracingEnabled = false;

  List<dynamic> get configs => _configs;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isTracingEnabled => _isTracingEnabled;

  Future<void> loadTracingConfigs(String workspaceId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _configs = await _apiService.getTracingConfigs(workspaceId);
      final checkResult = await _apiService.checkTracingEnabled(workspaceId);
      _isTracingEnabled = checkResult['enabled'] == true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createTracingConfig(String workspaceId, Map<String, dynamic> configData) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.createTracingConfig(workspaceId, configData);
      await loadTracingConfigs(workspaceId);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateTracingConfig(String workspaceId, String configId, Map<String, dynamic> updates) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.updateTracingConfig(workspaceId, configId, updates);
      await loadTracingConfigs(workspaceId);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteTracingConfig(String workspaceId, String configId) async {
    try {
      await _apiService.deleteTracingConfig(workspaceId, configId);
      await loadTracingConfigs(workspaceId);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }

  Future<void> toggleTracingConfig(String workspaceId, String configId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.toggleTracingConfig(workspaceId, configId);
      await loadTracingConfigs(workspaceId);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> bulkToggleTracingConfigs(String workspaceId, Map<String, dynamic> toggleData) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.bulkToggleTracingConfigs(workspaceId, toggleData);
      await loadTracingConfigs(workspaceId);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
}
