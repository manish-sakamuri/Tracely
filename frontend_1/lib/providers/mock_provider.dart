import 'package:flutter/material.dart';
import '../services/api_service.dart';

class MockProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<dynamic> _mocks = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<dynamic> get mocks => _mocks;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadMocks(String workspaceId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _mocks = await _apiService.getMocks(workspaceId);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> generateMockFromTrace(String workspaceId, String traceId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.generateMockFromTrace(workspaceId, traceId);
      await loadMocks(workspaceId);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateMock(String workspaceId, String mockId, Map<String, dynamic> updates) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.updateMock(workspaceId, mockId, updates);
      await loadMocks(workspaceId);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteMock(String workspaceId, String mockId) async {
    try {
      await _apiService.deleteMock(workspaceId, mockId);
      await loadMocks(workspaceId);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }
}
