import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AuditProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<dynamic> _logs = [];
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _lastAnomalyResult;

  List<dynamic> get logs => _logs;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get lastAnomalyResult => _lastAnomalyResult;

  Future<void> loadAuditLogs(String workspaceId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _logs = await _apiService.getAuditLogs(workspaceId);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> detectAnomalies(String workspaceId, String targetUserId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _lastAnomalyResult = await _apiService.detectAnomalies(workspaceId, targetUserId);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
