import 'package:flutter/foundation.dart';
import 'dart:async';
import '../services/api_service.dart';
import 'dart:convert';

class RequestProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  Map<String, dynamic>? _lastResponse;
  Map<String, dynamic>? _lastRequest;
  String? _error;
  List<Map<String, dynamic>> _history = [];

  bool get isLoading => _isLoading;
  Map<String, dynamic>? get lastResponse => _lastResponse;
  Map<String, dynamic>? get lastRequest => _lastRequest;
  String? get error => _error;
  List<Map<String, dynamic>> get history => _history;
  bool _tracingEnabled = true;
  bool get tracingEnabled => _tracingEnabled;

  // Properties for request data
  String _method = 'GET';
  String _url = '';
  Map<String, String> _headers = {};
  String _body = '';
  String _name = '';
  String _collectionId = '';

  // Getters for request data
  String get method => _method;
  String get url => _url;
  Map<String, String> get headers => _headers;
  String get body => _body;
  String get name => _name;
  String get collectionId => _collectionId;
  Map<String, dynamic>? get response => _lastResponse;

  Future<Map<String, dynamic>> executeRequest({
    required String method,
    required String url,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
    String? workspaceId,
    String? collectionId,
    String? requestId,
    String? overrideUrl,
    Map<String, String>? overrideHeaders,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final requestTimestamp = DateTime.now();
      Map<String, dynamic> responseInfo;

      // MODE A: Backend Execution (via Go service)
      if (requestId != null && workspaceId != null) {
        responseInfo = await _apiService.executeRequest(
          workspaceId,
          requestId,
          overrideUrl: overrideUrl,
          overrideHeaders: overrideHeaders,
        );
      } 
      // MODE B: Quick Trace Execution (ad-hoc tracing)
      else if (workspaceId != null && _tracingEnabled) {
        final rawResponse = await _apiService.quickExecuteRequest(
          workspaceId,
          {
            'method': method,
            'url': overrideUrl ?? url,
            'headers': headers ?? {},
            'body': body,
          },
        );

        // Normalize backend Execution model keys to frontend expected keys
        Map<String, String> responseHeaders = {};
        if (rawResponse['response_headers'] != null) {
          try {
            final decodedHeaders = json.decode(rawResponse['response_headers']);
            if (decodedHeaders is Map) {
              decodedHeaders.forEach((k, v) {
                if (v is List && v.isNotEmpty) {
                  responseHeaders[k.toString()] = v[0].toString();
                } else {
                  responseHeaders[k.toString()] = v.toString();
                }
              });
            }
          } catch (e) {
            debugPrint('Error decoding response headers: $e');
          }
        }

        responseInfo = {
          'status': rawResponse['status_code'] ?? 200,
          'body': rawResponse['response_body'],
          'headers': responseHeaders,
          'duration_ms': rawResponse['response_time_ms'] ?? 0,
          'trace_id': rawResponse['trace_id'],
          'time': DateTime.now().toIso8601String(),
        };
      }
      // MODE C: Direct Execution (local HTTP)
      else {
        responseInfo = await _apiService.sendDirectRequest(
          method: method,
          url: overrideUrl ?? url,
          body: body,
          headers: headers,
          queryParams: queryParams,
        );
      }

      _lastResponse = responseInfo;
      _lastRequest = {
        'method': method,
        'url': url,
        'timestamp': requestTimestamp.toIso8601String(),
      };

      _addToHistory(_lastRequest!, responseInfo);

      // Auto-save to backend if it's a new request in a collection
      if (workspaceId != null && collectionId != null && requestId == null) {
        // We don't 'await' this so the UI updates immediately
        _saveRequestToBackend(
          workspaceId: workspaceId,
          collectionId: collectionId,
          method: method,
          url: url,
          body: body,
          headers: headers,
          queryParams: queryParams,
          responseInfo: responseInfo,
        );
      }

      return responseInfo;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _addToHistory(Map<String, dynamic> req, Map<String, dynamic> res) {
    _history.insert(0, {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'method': req['method'],
      'url': req['url'],
      'status': res['status'],
      'time': res['time'] ?? DateTime.now().toIso8601String(),
    });
    if (_history.length > 50) _history.removeLast();
  }

  Future<void> _saveRequestToBackend({
    required String workspaceId,
    required String collectionId,
    required String method,
    required String url,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
    required Map<String, dynamic> responseInfo,
  }) async {
    try {
      await _apiService.createRequest(
        workspaceId,
        collectionId,
        {
          'method': method,
          'url': url,
          'body': body,
          'headers': headers ?? {},
          'query_params': queryParams ?? {},
          'response': responseInfo,
          'name': url.split('/').last.isEmpty ? 'New Request' : url.split('/').last,
        },
      );
    } catch (e) {
      debugPrint('Silent Background Save Failed: $e');
    }
  }

  // Setter methods for request data
  void setMethod(String method) {
    _method = method;
    notifyListeners();
  }

  void setUrl(String url) {
    _url = url;
    notifyListeners();
  }

  void setHeaders(Map<String, String> headers) {
    _headers = headers;
    notifyListeners();
  }

  void setBody(String body) {
    _body = body;
    notifyListeners();
  }

  void setName(String name) {
    _name = name;
    notifyListeners();
  }

  void setCollectionId(String collectionId) {
    _collectionId = collectionId;
    notifyListeners();
  }

  void setTracingEnabled(bool enabled) {
    _tracingEnabled = enabled;
    notifyListeners();
  }

  // Send request method
Future<Map<String, dynamic>> sendRequest({String? workspaceId}) async {
  Map<String, dynamic>? bodyMap;
  if (_body.isNotEmpty) {
    try {
      bodyMap = jsonDecode(_body) as Map<String, dynamic>;
    } catch (e) {
      // Handle cases where the string isn't valid JSON
      debugPrint("Invalid JSON format in body: $e");
      //throw an error or return a specific response here
    }
  }

  return executeRequest(
    method: _method,
    url: _url,
    body: bodyMap, // Now matches the required Map<String, dynamic>? type
    headers: _headers,
    workspaceId: workspaceId,
  );
}

  // Save request method
  Future<bool> saveRequest() async {
    try {
      await _apiService.createRequest(
        'workspaceId', 
        _collectionId,
        {
          'name': _name,
          'method': _method,
          'url': _url,
          'headers': _headers,
          'body': _body,
        },
      );
      return true;
    } catch (e) {
      debugPrint('Save request failed: $e');
      return false;
    }
  }

  Future<void> fetchRecentRequests() async {
    // TODO: Implement fetching recent requests
  }

  // Set request data from existing request
  void setRequestData(Map<String, dynamic>? request) {
    if (request == null) return;
    _method = request['method'] ?? 'GET';
    _url = request['url'] ?? request['path'] ?? '';
    _headers = Map<String, String>.from(request['headers'] ?? {});
    _body = request['body'] ?? '';
    _name = request['name'] ?? '';
    _collectionId = request['collectionId'] ?? '';
    notifyListeners();
  }

  // Clear all request data
  void clear() {
    _method = 'GET';
    _url = '';
    _headers = {};
    _body = '';
    _name = '';
    _collectionId = '';
    notifyListeners();
  }

  // Standard cleanup methods
  void clearResponse() { _lastResponse = null; notifyListeners(); }
  void clearError() { _error = null; notifyListeners(); }
  void clearHistory() { _history.clear(); notifyListeners(); }
}