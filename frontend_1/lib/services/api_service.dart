import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:8080/api/v1';
  // For Android emulator: 'http://10.0.2.2:8080/api/v1'
  // For iOS simulator: 'http://localhost:8080/api/v1'
  // For real device: 'http://YOUR_IP:8080/api/v1'
  
  String? _accessToken;
  String? _refreshToken;
  
  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();
  
  // Check if user is authenticated
  bool get isAuthenticated => _accessToken != null && _accessToken!.isNotEmpty;

    // Get access token
    String? get accessToken => _accessToken;

    // Get refresh token
    String? get refreshToken => _refreshToken;
  
  // Load tokens from storage
  Future<void> loadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
    _refreshToken = prefs.getString('refresh_token');
  }
  
  // Save tokens to storage
  Future<void> saveTokens(String accessToken, String refreshToken) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);
  }
  
  // Clear tokens
  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_id');
    await prefs.remove('user_name');
    await prefs.remove('user_email');
  }

  /// Persist user info so it survives refresh
  Future<void> saveUserInfo(String userId, String name, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userId);
    await prefs.setString('user_name', name);
    await prefs.setString('user_email', email);
  }

  /// Load persisted user info (for use after refresh)
  Future<Map<String, dynamic>?> loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('user_id');
    final name = prefs.getString('user_name');
    final email = prefs.getString('user_email');
    if (id == null && name == null && email == null) return null;
    return {
      'id': id,
      'name': name ?? '',
      'email': email ?? '',
    };
  }
  
  /// Ensures workspaceId is valid (non-null, non-empty, not literal "null").
  /// Backend expects a UUID; invalid values cause 400 Bad Request.
  void _requireValidWorkspaceId(String? workspaceId) {
    if (workspaceId == null ||
        workspaceId.trim().isEmpty ||
        workspaceId == 'null') {
      throw Exception('Select a workspace first');
    }
  }

  // Get headers with optional auth
  Future<Map<String, String>> _getHeaders({bool includeAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
    };
    
    if (includeAuth && _accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    
    return headers;
  }
  // Add this public method to ApiService:
  Future<Map<String, String>> getRequestHeaders({bool includeAuth = true}) async {
    return await _getHeaders(includeAuth: includeAuth);
  }
  
  // Generic request handler with automatic token refresh
  Future<Map<String, dynamic>> _handleResponse(http.Response response, {String? originalBody}) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isNotEmpty) {
        return json.decode(response.body);
      }
      return {'success': true};
    } else if (response.statusCode == 401) {
      // Try to refresh token automatically
      if (_refreshToken != null && _refreshToken!.isNotEmpty) {
        try {
          final refreshResponse = await http.post(
            Uri.parse('$baseUrl/auth/refresh'),
            headers: await _getHeaders(includeAuth: false),
            body: json.encode({'refresh_token': _refreshToken}),
          );

          if (refreshResponse.statusCode == 200) {
            final refreshData = json.decode(refreshResponse.body);
            if (refreshData['access_token'] != null) {
              await saveTokens(refreshData['access_token'], _refreshToken!);

              // Retry the original request with new token
              final originalRequest = http.Request(
                response.request!.method,
                response.request!.url,
              )..headers.addAll(await _getHeaders(includeAuth: true));

              if (originalBody != null) {
                originalRequest.body = originalBody;
              }

              final client = http.Client();
              final retryResponse = await client.send(originalRequest);
              final retryBody = await retryResponse.stream.bytesToString();
              final retryHttpResponse = http.Response(retryBody, retryResponse.statusCode, request: retryResponse.request);

              return _handleResponse(retryHttpResponse, originalBody: originalBody);
            }
          }
        } catch (e) {
          // Token refresh failed, clear tokens and throw original error
          await clearTokens();
        }
      }

      // If we reach here, token refresh failed or wasn't attempted
      await clearTokens();
      throw Exception('Unauthorized - Please login again');
    } else {
      try {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? error['message'] ?? 'Request failed');
      } catch (_) {
        throw Exception('Request failed: ${response.statusCode}');
      }
    }
  }
  
  // ==================== AUTH ENDPOINTS ====================
  
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: await _getHeaders(includeAuth: false),
      body: json.encode({
        'email': email,
        'password': password,
      }),
    );
    
    final data = await _handleResponse(response);
    if (data['access_token'] != null && data['refresh_token'] != null) {
      await saveTokens(data['access_token'], data['refresh_token']);
    }
    return data;
  }
  
  Future<Map<String, dynamic>> register(String email, String password, String name) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: await _getHeaders(includeAuth: false),
      body: json.encode({
        'email': email,
        'password': password,
        'name': name,
      }),
    );
    
    return await _handleResponse(response);
  }
  
  Future<void> logout() async {
    try {
      await http.post(
        Uri.parse('$baseUrl/auth/logout'),
        headers: await _getHeaders(),
      );
    } finally {
      await clearTokens();
    }
  }
  
  // ==================== WORKSPACE ENDPOINTS ====================
  
  Future<List<dynamic>> getWorkspaces() async {
    final response = await http.get(
      Uri.parse('$baseUrl/workspaces'),
      headers: await _getHeaders(),
    );
  
    final data = await _handleResponse(response);
    return data['workspaces'] ?? data['data'] ?? [];
  }

  // In your ApiService class, update the createWorkspace method:

  Future<Map<String, dynamic>> createWorkspace(
    String name, {
    String? description,
    // New optional parameters with defaults
    String? type = 'internal',
    bool isPublic = false,
    String? accessType = 'team',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/workspaces'),
      headers: await _getHeaders(),
      body: json.encode({
        'name': name,
        if (description != null) 'description': description,
        // Add the new fields
        'type': type,
        'is_public': isPublic,
        'access_type': accessType,
      }),
    );

    return await _handleResponse(response);
  }

  Future<Map<String, dynamic>> initializeWorkspace(
    String name, {
    String? description,
    required int templateId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/workspaces/initialize'),
      headers: await _getHeaders(),
      body: json.encode({
        'name': name,
        if (description != null) 'description': description,
        'template_id': templateId,
      }),
    );

    return await _handleResponse(response);
  }

  Future<Map<String, dynamic>> updateWorkspace(
    String workspaceId,
    String name,
    {String? description}
  ) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.put(
      Uri.parse('$baseUrl/workspaces/$workspaceId'),
      headers: await _getHeaders(),
      body: json.encode({
        'name': name,
        if (description != null) 'description': description,
      }),
    );
  
    return await _handleResponse(response);
  }

  Future<void> deleteWorkspace(String workspaceId) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.delete(
      Uri.parse('$baseUrl/workspaces/$workspaceId'),
      headers: await _getHeaders(),
    );
  
    await _handleResponse(response);
  }
  
  // ==================== COLLECTION ENDPOINTS ====================
  
  Future<List<dynamic>> getCollections(String workspaceId) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.get(
      Uri.parse('$baseUrl/workspaces/$workspaceId/collections'),
      headers: await _getHeaders(),
    );
    
    final data = await _handleResponse(response);
    return data['collections'] ?? data['data'] ?? [];
  }
  
  Future<Map<String, dynamic>> createCollection(
    String workspaceId,
    String name,
    {String? description}
  ) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.post(
      Uri.parse('$baseUrl/workspaces/$workspaceId/collections'),
      headers: await _getHeaders(),
      body: json.encode({
        'name': name,
        if (description != null) 'description': description,
      }),
    );

    return await _handleResponse(response);
  }

  Future<Map<String, dynamic>> getCollectionById(String workspaceId, String collectionId) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.get(
      Uri.parse('$baseUrl/workspaces/$workspaceId/collections/$collectionId'),
      headers: await _getHeaders(),
    );
    return await _handleResponse(response);
  }

  Future<Map<String, dynamic>> updateCollection(String workspaceId, String collectionId, String name, {String? description}) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.put(
      Uri.parse('$baseUrl/workspaces/$workspaceId/collections/$collectionId'),
      headers: await _getHeaders(),
      body: json.encode({
        'name': name,
        if (description != null) 'description': description,
      }),
    );
    return await _handleResponse(response);
  }

  Future<void> deleteCollection(String workspaceId, String collectionId) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.delete(
      Uri.parse('$baseUrl/workspaces/$workspaceId/collections/$collectionId'),
      headers: await _getHeaders(),
    );
    await _handleResponse(response);
  }
  
  // ==================== REQUEST ENDPOINTS ====================
  
  Future<Map<String, dynamic>> createRequest(
    String workspaceId,
    String collectionId,
    Map<String, dynamic> requestData,
  ) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.post(
      Uri.parse('$baseUrl/workspaces/$workspaceId/collections/$collectionId/requests'),
      headers: await _getHeaders(),
      body: json.encode(requestData),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> executeRequest(
    String workspaceId,
    String requestId,
    {String? overrideUrl, Map<String, String>? overrideHeaders, String? traceId, String? spanId, String? parentSpanId}
  ) async {
    _requireValidWorkspaceId(workspaceId);
    final body = <String, dynamic>{};
    if (overrideUrl != null) body['override_url'] = overrideUrl;
    if (overrideHeaders != null) body['override_headers'] = overrideHeaders;
    if (traceId != null) body['trace_id'] = traceId;
    if (spanId != null) body['span_id'] = spanId;
    if (parentSpanId != null) body['parent_span_id'] = parentSpanId;

    final response = await http.post(
      Uri.parse('$baseUrl/workspaces/$workspaceId/requests/$requestId/execute'),
      headers: await _getHeaders(),
      body: body.isNotEmpty ? json.encode(body) : null,
    );

    return await _handleResponse(response);
  }

  Future<Map<String, dynamic>> quickExecuteRequest(
    String workspaceId,
    Map<String, dynamic> requestData,
  ) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.post(
      Uri.parse('$baseUrl/workspaces/$workspaceId/trace/quick-execute'),
      headers: await _getHeaders(),
      body: json.encode(requestData),
    );

    return await _handleResponse(response);
  }

  Future<Map<String, dynamic>> getRequestById(String workspaceId, String requestId) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.get(
      Uri.parse('$baseUrl/workspaces/$workspaceId/requests/$requestId'),
      headers: await _getHeaders(),
    );
    return await _handleResponse(response);
  }

  Future<Map<String, dynamic>> updateRequest(String workspaceId, String requestId, Map<String, dynamic> updates) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.put(
      Uri.parse('$baseUrl/workspaces/$workspaceId/requests/$requestId'),
      headers: await _getHeaders(),
      body: json.encode(updates),
    );
    return await _handleResponse(response);
  }

  Future<void> deleteRequest(String workspaceId, String requestId) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.delete(
      Uri.parse('$baseUrl/workspaces/$workspaceId/requests/$requestId'),
      headers: await _getHeaders(),
    );
    await _handleResponse(response);
  }

  Future<Map<String, dynamic>> getRequestHistory(String workspaceId, String requestId, {int limit = 50, int offset = 0}) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.get(
      Uri.parse('$baseUrl/workspaces/$workspaceId/requests/$requestId/history?limit=$limit&offset=$offset'),
      headers: await _getHeaders(),
    );
    return await _handleResponse(response);
  }
    
  // ==================== MONITORING ENDPOINTS ====================
  
  Future<Map<String, dynamic>> getDashboard(String workspaceId) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.get(
      Uri.parse('$baseUrl/workspaces/$workspaceId/monitoring/dashboard'),
      headers: await _getHeaders(),
    );
    
    return await _handleResponse(response);
  }
  
  Future<Map<String, dynamic>> getMetrics(String workspaceId) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.get(
      Uri.parse('$baseUrl/workspaces/$workspaceId/monitoring/metrics'),
      headers: await _getHeaders(),
    );
    
    return await _handleResponse(response);
  }
  
  // ==================== GOVERNANCE ENDPOINTS ====================
  
  Future<List<dynamic>> getGovernancePolicies(String workspaceId) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.get(
      Uri.parse('$baseUrl/workspaces/$workspaceId/governance/policies'),
      headers: await _getHeaders(),
    );
    final data = await _handleResponse(response);
    return data['policies'] ?? data['data'] ?? [];
  }

  Future<Map<String, dynamic>> createGovernancePolicy(
    String workspaceId,
    String name,
    String description,
    String type,
  ) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.post(
      Uri.parse('$baseUrl/workspaces/$workspaceId/governance/policies'),
      headers: await _getHeaders(),
      body: json.encode({
        'name': name,
        'description': description,
        'type': type,
      }),
    );
    return await _handleResponse(response);
  }

  Future<Map<String, dynamic>> updateGovernancePolicy(
    String workspaceId,
    String policyId,
    Map<String, dynamic> updates,
  ) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.put(
      Uri.parse('$baseUrl/workspaces/$workspaceId/governance/policies/$policyId'),
      headers: await _getHeaders(),
      body: json.encode(updates),
    );
    return await _handleResponse(response);
  }

  Future<void> deleteGovernancePolicy(String workspaceId, String policyId) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.delete(
      Uri.parse('$baseUrl/workspaces/$workspaceId/governance/policies/$policyId'),
      headers: await _getHeaders(),
    );
    await _handleResponse(response);
  }
  
  // ==================== SETTINGS ENDPOINTS ====================
  
  Future<Map<String, dynamic>> getSettings() async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/settings'),
      headers: await _getHeaders(),
    );
    
    return await _handleResponse(response);
  }
  
  Future<Map<String, dynamic>> updateSettings(Map<String, dynamic> settings) async {
    final response = await http.put(
      Uri.parse('$baseUrl/users/settings'),
      headers: await _getHeaders(),
      body: json.encode(settings),
    );
    
    return await _handleResponse(response);
  }




// ==================== MONITORING ====================

  Future<Map<String, dynamic>> getTopology(String workspaceId) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.get(
      Uri.parse('$baseUrl/workspaces/$workspaceId/monitoring/topology'),
      headers: await _getHeaders(),
    );
    return _handleResponse(response);
  }

// ==================== TRACING ====================

  Future<Map<String, dynamic>> getTraces(String workspaceId, {int page = 1, int limit = 50}) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.get(
      Uri.parse('$baseUrl/workspaces/$workspaceId/traces?page=$page&limit=$limit'),
      headers: await _getHeaders(),
    );
    final data = await _handleResponse(response);
    return data;
  }

  Future<Map<String, dynamic>> getTraceDetails(
    String workspaceId,
    String traceId,
  ) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.get(
      Uri.parse('$baseUrl/workspaces/$workspaceId/traces/$traceId'),
      headers: await _getHeaders(),
    );
    return _handleResponse(response);
  }

// ==================== REPLAY ENGINE ====================

  Future<Map<String, dynamic>> createReplay(
    String workspaceId,
    Map<String, dynamic> replayData,
  ) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.post(
      Uri.parse('$baseUrl/workspaces/$workspaceId/replays'),
      headers: await _getHeaders(),
      body: json.encode(replayData),
    );
    final Map<String, dynamic> result = await _handleResponse(response);
    return result;
  }

  // CORRECT: This returns the JSON response from your Go backend
  Future<Map<String, dynamic>> executeReplay(String workspaceId, String replayId) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.post(
      Uri.parse('$baseUrl/workspaces/$workspaceId/replays/$replayId/execute'),
      headers: await _getHeaders(),
    );
  
    // Cast the dynamic result from _handleResponse to a Map
    final data = await _handleResponse(response);
    return Map<String, dynamic>.from(data);
  }

// ==================== MOCKS ====================

  Future<List<dynamic>> getMocks(String workspaceId) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.get(
      Uri.parse('$baseUrl/workspaces/$workspaceId/mocks'),
      headers: await _getHeaders(),
    );
    final data = await _handleResponse(response);
    return data['mocks'] ?? data['data'] ?? [];

  }

  Future<Map<String, dynamic>> generateMockFromTrace(
    String workspaceId,
    String traceId,
  ) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.post(
      Uri.parse('$baseUrl/workspaces/$workspaceId/mocks/generate'),
      headers: await _getHeaders(),
      body: json.encode({'trace_id': traceId}),
    );
    return _handleResponse(response);
  }

  Future<void> updateMock(
    String workspaceId,
    String mockId,
    Map<String, dynamic> updates,
  ) async {
    _requireValidWorkspaceId(workspaceId);
    await http.put(
      Uri.parse('$baseUrl/workspaces/$workspaceId/mocks/$mockId'),
      headers: await _getHeaders(),
      body: json.encode(updates),
    );
  }

  Future<void> deleteMock(String workspaceId, String mockId) async {
    _requireValidWorkspaceId(workspaceId);
    await http.delete(
      Uri.parse('$baseUrl/workspaces/$workspaceId/mocks/$mockId'),
      headers: await _getHeaders(),
    );
  }

  // ==================== ENVIRONMENT ENDPOINTS ====================

  Future<List<dynamic>> getEnvironments(String workspaceId) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.get(
      Uri.parse('$baseUrl/workspaces/$workspaceId/environments'),
      headers: await _getHeaders(),
    );
    final data = await _handleResponse(response);
    return data['environments'] ?? data['data'] ?? [];
  }

  Future<Map<String, dynamic>> createEnvironment(
    String workspaceId,
    String name,
    String type,
    {String? description, bool isActive = true}
  ) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.post(
      Uri.parse('$baseUrl/workspaces/$workspaceId/environments'),
      headers: await _getHeaders(),
      body: json.encode({
        'name': name,
        'type': type,
        if (description != null) 'description': description,
        'is_active': isActive,
      }),
    );
    return await _handleResponse(response);
  }

  Future<Map<String, dynamic>> updateEnvironment(
    String workspaceId,
    String environmentId,
    {String? name, String? type, String? description, bool? isActive}
  ) async {
    _requireValidWorkspaceId(workspaceId);
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (type != null) updates['type'] = type;
    if (description != null) updates['description'] = description;
    if (isActive != null) updates['is_active'] = isActive;

    final response = await http.put(
      Uri.parse('$baseUrl/workspaces/$workspaceId/environments/$environmentId'),
      headers: await _getHeaders(),
      body: json.encode(updates),
    );
    return await _handleResponse(response);
  }

  Future<void> deleteEnvironment(String workspaceId, String environmentId) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.delete(
      Uri.parse('$baseUrl/workspaces/$workspaceId/environments/$environmentId'),
      headers: await _getHeaders(),
    );
    await _handleResponse(response);
  }

  Future<Map<String, dynamic>> getEnvironmentVariables(String workspaceId, String environmentId) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.get(
      Uri.parse('$baseUrl/workspaces/$workspaceId/environments/$environmentId/variables'),
      headers: await _getHeaders(),
    );
    return await _handleResponse(response);
  }

  Future<Map<String, dynamic>> addEnvironmentVariable(
    String workspaceId,
    String environmentId,
    String key,
    String value,
    {String type = 'string', String? description}
  ) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.post(
      Uri.parse('$baseUrl/workspaces/$workspaceId/environments/$environmentId/variables'),
      headers: await _getHeaders(),
      body: json.encode({
        'key': key,
        'value': value,
        'type': type,
        if (description != null) 'description': description,
      }),
    );
    return await _handleResponse(response);
  }

  Future<Map<String, dynamic>> updateEnvironmentVariable(
    String workspaceId,
    String environmentId,
    String variableId,
    {String? key, String? value, String? type, String? description}
  ) async {
    _requireValidWorkspaceId(workspaceId);
    final updates = <String, dynamic>{};
    if (key != null) updates['key'] = key;
    if (value != null) updates['value'] = value;
    if (type != null) updates['type'] = type;
    if (description != null) updates['description'] = description;

    final response = await http.put(
      Uri.parse('$baseUrl/workspaces/$workspaceId/environments/$environmentId/variables/$variableId'),
      headers: await _getHeaders(),
      body: json.encode(updates),
    );
    return await _handleResponse(response);
  }

  Future<void> deleteEnvironmentVariable(String workspaceId, String environmentId, String variableId) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.delete(
      Uri.parse('$baseUrl/workspaces/$workspaceId/environments/$environmentId/variables/$variableId'),
      headers: await _getHeaders(),
    );
    await _handleResponse(response);
  }

  // ==================== REPLAY ENDPOINTS ====================

  Future<Map<String, dynamic>> getReplay(String workspaceId, String replayId) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.get(
      Uri.parse('$baseUrl/workspaces/$workspaceId/replays/$replayId'),
      headers: await _getHeaders(),
    );
    return await _handleResponse(response);
  }

  Future<Map<String, dynamic>> getReplayResults(String workspaceId, String replayId) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.get(
      Uri.parse('$baseUrl/workspaces/$workspaceId/replays/$replayId/results'),
      headers: await _getHeaders(),
    );
    return await _handleResponse(response);
  }

  // ==================== SCHEMA VALIDATOR ENDPOINTS ====================

  Future<Map<String, dynamic>> validateSchema(String workspaceId, Map<String, dynamic> schemaData) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.post(
      Uri.parse('$baseUrl/workspaces/$workspaceId/schema/validate'),
      headers: await _getHeaders(),
      body: json.encode(schemaData),
    );
    return await _handleResponse(response);
  }

  // ==================== TEST DATA GENERATOR ENDPOINTS ====================

  Future<Map<String, dynamic>> generateTestData(String workspaceId, Map<String, dynamic> schema) async {
  _requireValidWorkspaceId(workspaceId);
  final response = await http.post(
    Uri.parse('$baseUrl/workspaces/$workspaceId/test-data/generate'), 
    headers: await _getHeaders(),
    body: json.encode({
      'schema': schema, 
    }),
  );
  return await _handleResponse(response);
}

  // ==================== PII MASKER ENDPOINTS ====================

  Future<Map<String, dynamic>> maskPII(String workspaceId, Map<String, dynamic> data) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.post(
      Uri.parse('$baseUrl/workspaces/$workspaceId/pii/mask'),
      headers: await _getHeaders(),
      body: json.encode(data),
    );
    return await _handleResponse(response);
  }

  // ==================== ALERT ENDPOINTS ====================

  Future<Map<String, dynamic>> createAlertRule(String workspaceId, Map<String, dynamic> ruleData) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.post(
      Uri.parse('$baseUrl/workspaces/$workspaceId/alerts/rules'),
      headers: await _getHeaders(),
      body: json.encode(ruleData),
    );
    return await _handleResponse(response);
  }

  Future<List<dynamic>> getActiveAlerts(String workspaceId) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.get(
      Uri.parse('$baseUrl/workspaces/$workspaceId/alerts/active'),
      headers: await _getHeaders(),
    );
    final data = await _handleResponse(response);
    return data['alerts'] ?? data['data'] ?? [];
  }

  Future<Map<String, dynamic>> acknowledgeAlert(String workspaceId, String alertId) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.post(
      Uri.parse('$baseUrl/workspaces/$workspaceId/alerts/$alertId/acknowledge'),
      headers: await _getHeaders(),
    );
    return await _handleResponse(response);
  }

  // ==================== AUDIT ENDPOINTS ====================

  Future<List<dynamic>> getAuditLogs(String workspaceId) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.get(
      Uri.parse('$baseUrl/workspaces/$workspaceId/audit/logs'),
      headers: await _getHeaders(),
    );
    final data = await _handleResponse(response);
    return data['logs'] ?? data['data'] ?? [];
  }

  Future<Map<String, dynamic>> detectAnomalies(String workspaceId, String targetUserId) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.post(
      Uri.parse('$baseUrl/workspaces/$workspaceId/audit/anomalies/$targetUserId'),
      headers: await _getHeaders(),
    );
    return await _handleResponse(response);
  }

  // ==================== FAILURE INJECTION ENDPOINTS ====================

  Future<Map<String, dynamic>> createFailureInjectionRule(String workspaceId, Map<String, dynamic> ruleData) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.post(
      Uri.parse('$baseUrl/workspaces/$workspaceId/failure-injection/rules'),
      headers: await _getHeaders(),
      body: json.encode(ruleData),
    );
    return await _handleResponse(response);
  }

  // ==================== MUTATION ENDPOINTS ====================

  Future<Map<String, dynamic>> applyMutations(String workspaceId, Map<String, dynamic> mutationData) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.post(
      Uri.parse('$baseUrl/workspaces/$workspaceId/mutations/apply'),
      headers: await _getHeaders(),
      body: json.encode(mutationData),
    );
    return await _handleResponse(response);
  }

  // ==================== PERCENTILE CALCULATOR ENDPOINTS ====================

  Future<Map<String, dynamic>> calculatePercentiles(String workspaceId, Map<String, dynamic> percentileData) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.post(
      Uri.parse('$baseUrl/workspaces/$workspaceId/percentiles/calculate'),
      headers: await _getHeaders(),
      body: json.encode(percentileData),
    );
    return await _handleResponse(response);
  }

  // ==================== TRACING CONFIG ENDPOINTS ====================

  Future<List<dynamic>> getTracingConfigs(String workspaceId) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.get(
      Uri.parse('$baseUrl/workspaces/$workspaceId/tracing/configs'),
      headers: await _getHeaders(),
    );
    final data = await _handleResponse(response);
    return data['configs'] ?? data['data'] ?? [];
  }

  Future<Map<String, dynamic>> createTracingConfig(String workspaceId, Map<String, dynamic> configData) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.post(
      Uri.parse('$baseUrl/workspaces/$workspaceId/tracing/configs'),
      headers: await _getHeaders(),
      body: json.encode(configData),
    );
    return await _handleResponse(response);
  }

  Future<Map<String, dynamic>> getTracingConfigById(String workspaceId, String configId) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.get(
      Uri.parse('$baseUrl/workspaces/$workspaceId/tracing/configs/$configId'),
      headers: await _getHeaders(),
    );
    return await _handleResponse(response);
  }

  Future<Map<String, dynamic>> updateTracingConfig(String workspaceId, String configId, Map<String, dynamic> updates) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.put(
      Uri.parse('$baseUrl/workspaces/$workspaceId/tracing/configs/$configId'),
      headers: await _getHeaders(),
      body: json.encode(updates),
    );
    return await _handleResponse(response);
  }

  Future<void> deleteTracingConfig(String workspaceId, String configId) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.delete(
      Uri.parse('$baseUrl/workspaces/$workspaceId/tracing/configs/$configId'),
      headers: await _getHeaders(),
    );
    await _handleResponse(response);
  }

  Future<Map<String, dynamic>> toggleTracingConfig(String workspaceId, String configId) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.post(
      Uri.parse('$baseUrl/workspaces/$workspaceId/tracing/configs/$configId/toggle'),
      headers: await _getHeaders(),
    );
    return await _handleResponse(response);
  }

  Future<Map<String, dynamic>> bulkToggleTracingConfigs(String workspaceId, Map<String, dynamic> toggleData) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.post(
      Uri.parse('$baseUrl/workspaces/$workspaceId/tracing/configs/bulk-toggle'),
      headers: await _getHeaders(),
      body: json.encode(toggleData),
    );
    return await _handleResponse(response);
  }

  Future<Map<String, dynamic>> getTracingConfigByServiceName(String workspaceId, String serviceName) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.get(
      Uri.parse('$baseUrl/workspaces/$workspaceId/tracing/services/$serviceName'),
      headers: await _getHeaders(),
    );
    return await _handleResponse(response);
  }

  Future<List<dynamic>> getEnabledTracingServices(String workspaceId) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.get(
      Uri.parse('$baseUrl/workspaces/$workspaceId/tracing/enabled-services'),
      headers: await _getHeaders(),
    );
    final data = await _handleResponse(response);
    return data['services'] ?? data['data'] ?? [];
  }

  Future<List<dynamic>> getDisabledTracingServices(String workspaceId) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.get(
      Uri.parse('$baseUrl/workspaces/$workspaceId/tracing/disabled-services'),
      headers: await _getHeaders(),
    );
    final data = await _handleResponse(response);
    return data['services'] ?? data['data'] ?? [];
  }

  Future<Map<String, dynamic>> checkTracingEnabled(String workspaceId) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.get(
      Uri.parse('$baseUrl/workspaces/$workspaceId/tracing/check'),
      headers: await _getHeaders(),
    );
    return await _handleResponse(response);
  }

  // ==================== WATERFALL ENDPOINTS ====================

  Future<Map<String, dynamic>> getWaterfall(String workspaceId, String traceId) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.get(
      Uri.parse('$baseUrl/workspaces/$workspaceId/traces/$traceId/waterfall'),
      headers: await _getHeaders(),
    );
    return await _handleResponse(response);
  }

  // ==================== LOAD TEST ENDPOINTS ====================

  Future<Map<String, dynamic>> createLoadTest(String workspaceId, Map<String, dynamic> loadTestData) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.post(
      Uri.parse('$baseUrl/workspaces/$workspaceId/load-tests'),
      headers: await _getHeaders(),
      body: json.encode(loadTestData),
    );
    return await _handleResponse(response);
  }

  // ==================== SECRETS ENDPOINTS ====================

  Future<Map<String, dynamic>> createSecret(String workspaceId, Map<String, dynamic> secretData) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.post(
      Uri.parse('$baseUrl/workspaces/$workspaceId/secrets'),
      headers: await _getHeaders(),
      body: json.encode(secretData),
    );
    return await _handleResponse(response);
  }

  Future<Map<String, dynamic>> getSecretValue(String workspaceId, String secretId) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.get(
      Uri.parse('$baseUrl/workspaces/$workspaceId/secrets/$secretId'),
      headers: await _getHeaders(),
    );
    return await _handleResponse(response);
  }

  Future<Map<String, dynamic>> rotateSecret(String workspaceId, String secretId) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.post(
      Uri.parse('$baseUrl/workspaces/$workspaceId/secrets/$secretId/rotate'),
      headers: await _getHeaders(),
    );
    return await _handleResponse(response);
  }

  // ==================== WEBHOOK ENDPOINTS ====================

  Future<Map<String, dynamic>> createWebhook(String workspaceId, Map<String, dynamic> webhookData) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.post(
      Uri.parse('$baseUrl/workspaces/$workspaceId/webhooks'),
      headers: await _getHeaders(),
      body: json.encode(webhookData),
    );
    return await _handleResponse(response);
  }

  Future<Map<String, dynamic>> triggerWebhook(String workspaceId, Map<String, dynamic> triggerData) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.post(
      Uri.parse('$baseUrl/workspaces/$workspaceId/webhooks/trigger'),
      headers: await _getHeaders(),
      body: json.encode(triggerData),
    );
    return await _handleResponse(response);
  }

  // ==================== WORKFLOW ENDPOINTS ====================

  Future<Map<String, dynamic>> createWorkflow(String workspaceId, Map<String, dynamic> workflowData) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.post(
      Uri.parse('$baseUrl/workspaces/$workspaceId/workflows'),
      headers: await _getHeaders(),
      body: json.encode(workflowData),
    );
    return await _handleResponse(response);
  }

  Future<Map<String, dynamic>> executeWorkflow(String workspaceId, String workflowId) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.post(
      Uri.parse('$baseUrl/workspaces/$workspaceId/workflows/$workflowId/execute'),
      headers: await _getHeaders(),
    );
    return await _handleResponse(response);
  }

  // ==================== REPLAY ENDPOINTS (ADDITIONAL) ====================

  Future<List<dynamic>> getReplays(String workspaceId) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.get(
      Uri.parse('$baseUrl/workspaces/$workspaceId/replays'),
      headers: await _getHeaders(),
    );
    final data = await _handleResponse(response);
    return data['replays'] ?? data['data'] ?? [];
  }

  // ==================== COLLECTION REQUESTS ENDPOINTS ====================

  Future<List<dynamic>> getCollectionRequests(String workspaceId, String collectionId) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.get(
      Uri.parse('$baseUrl/workspaces/$workspaceId/collections/$collectionId/requests'),
      headers: await _getHeaders(),
    );
    final data = await _handleResponse(response);
    return data['requests'] ?? data['data'] ?? [];
  }

  Future<Map<String, dynamic>> importCollection(String workspaceId, Map<String, dynamic> jsonData) async {
    _requireValidWorkspaceId(workspaceId);
    final response = await http.post(
      Uri.parse('$baseUrl/workspaces/$workspaceId/collections/import/postman'),
      headers: await _getHeaders(),
      body: json.encode(jsonData),
    );
    return await _handleResponse(response);
  }

  // ==================== DIRECT REQUEST ====================

  Future<Map<String, dynamic>> sendDirectRequest({
    required String method,
    required String url,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
  }) async {
    // 1. Setup URL & Query Params
    Uri uri = Uri.parse(url);
    if (queryParams != null) {
      uri = uri.replace(queryParameters: queryParams.map((k, v) => MapEntry(k, v.toString())));
    }

    // 2. Setup Headers
    final requestHeaders = <String, String>{
      'Content-Type': 'application/json',
      ...?headers,
    };
    if (_accessToken != null) {
      requestHeaders['Authorization'] = 'Bearer $accessToken';
    }

    // 3. Execute — supports all standard HTTP methods
    final stopwatch = Stopwatch()..start();
    http.Response response;
    final encodedBody = body != null ? json.encode(body) : null;
    
    switch (method.toUpperCase()) {
      case 'GET':
        response = await http.get(uri, headers: requestHeaders);
        break;
      case 'POST':
        response = await http.post(uri, headers: requestHeaders, body: encodedBody);
        break;
      case 'PUT':
        response = await http.put(uri, headers: requestHeaders, body: encodedBody);
        break;
      case 'DELETE':
        response = await http.delete(uri, headers: requestHeaders);
        break;
      case 'PATCH':
        response = await http.patch(uri, headers: requestHeaders, body: encodedBody);
        break;
      case 'HEAD':
        response = await http.head(uri, headers: requestHeaders);
        break;
      case 'OPTIONS':
        // http package doesn't have options(), use Client
        final client = http.Client();
        final request = http.Request('OPTIONS', uri);
        request.headers.addAll(requestHeaders);
        final streamedResponse = await client.send(request);
        response = await http.Response.fromStream(streamedResponse);
        client.close();
        break;
      default:
        throw Exception('Method $method not supported');
    }
    stopwatch.stop();

    // 4. Format standardized responseInfo
    dynamic responseBody;
    try {
      responseBody = response.body.isNotEmpty ? json.decode(response.body) : null;
    } catch (_) {
      responseBody = response.body;
    }

    return {
      'status': response.statusCode,
      'headers': response.headers,
      'body': responseBody,
      'time': DateTime.now().toIso8601String(),
      'duration_ms': stopwatch.elapsedMilliseconds,
      'size_bytes': response.contentLength ?? response.body.length,
    };
  }
  Future<Map<String, dynamic>> initWorkspaceTemplate(String workspaceId, int templateId) async {
    final url = Uri.parse('$baseUrl/workspaces/$workspaceId/initialize');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          // 'Authorization': 'Bearer $yourToken', // Add if using auth
        },
        body: jsonEncode({
          'template_id': templateId,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        // Parse server error message if available
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to initialize workspace template');
      }
    } catch (e) {
      // Catch network errors or parsing exceptions
      throw Exception('Connection error: $e');
    }
  }

}


