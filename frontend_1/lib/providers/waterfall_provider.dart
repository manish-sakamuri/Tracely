import 'package:flutter/material.dart';
import '../services/api_service.dart';

class WaterfallProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  Map<String, dynamic>? _waterfallData;
  bool _isLoading = false;
  String? _errorMessage;

  Map<String, dynamic>? get waterfallData => _waterfallData;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> getWaterfall(String workspaceId, String traceId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _waterfallData = await _apiService.getWaterfall(workspaceId, traceId);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _waterfallData = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
