import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class TraceProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Map<String, dynamic>> _traces = [];
  Map<String, dynamic>? _selectedTrace;
  bool _isLoading = false;
  String? _error;
  bool _hasMoreTraces = true;

  // Getters
  List<Map<String, dynamic>> get traces => _traces;
  Map<String, dynamic>? get selectedTrace => _selectedTrace;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMoreTraces => _hasMoreTraces;

  Future<bool> fetchTraces(String workspaceId, {int page = 1, int limit = 50}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.getTraces(workspaceId, page: page, limit: limit);
      final rawTraces = List<dynamic>.from(response['traces'] ?? []);
      
      final normalizedTraces = rawTraces.map((t) => _normalizeTrace(Map<String, dynamic>.from(t))).toList();
      
      if (page == 1) {
        _traces = normalizedTraces;
      } else {
        _traces.addAll(normalizedTraces);
      }
      _hasMoreTraces = normalizedTraces.length >= limit;
      return true;
    } catch (e) {
      _error = "Failed to load traces: ${e.toString()}";
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> getTraceDetails(String workspaceId, String traceId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final details = await _apiService.getTraceDetails(workspaceId, traceId);
      if (details != null) {
        _selectedTrace = _normalizeTrace(Map<String, dynamic>.from(details));
      } else {
        _selectedTrace = null;
      }
      return _selectedTrace;
    } catch (e) {
      _error = "Failed to load trace details: ${e.toString()}";
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Map<String, dynamic> _normalizeTrace(Map<String, dynamic> trace) {
    debugPrint("DEBUG: Normalizing trace: $trace");
    // Map backend keys to frontend expected keys
    final normalized = Map<String, dynamic>.from(trace);
    
    // Core trace metadata
    normalized['id'] ??= trace['trace_id'] ?? trace['id'];
    normalized['service'] ??= trace['service_name'] ?? trace['service'] ?? 'Unknown Service';
    
    // Duration normalization
    var duration = trace['duration'] ?? trace['total_duration_ms'] ?? 0;
    if (duration is String) {
      duration = int.tryParse(duration) ?? 0;
    } else if (duration is double) {
      duration = duration.round();
    }
    normalized['duration'] = duration;
    
    normalized['timestamp'] ??= trace['start_time'] ?? trace['timestamp'];
    normalized['status'] ??= trace['status'] ?? 'success';

    // Normalize Spans
    final rawSpans = normalized['spans'] as List?;
    if (rawSpans != null) {
      final normalizedSpans = rawSpans.map((s) {
        final spanMap = Map<String, dynamic>.from(s);
        spanMap['name'] ??= spanMap['operation_name'] ?? 'Unknown Op';
        
        var spanDur = spanMap['duration'] ?? spanMap['duration_ms'] ?? 0;
        if (spanDur is String) spanDur = double.tryParse(spanDur) ?? 0;
        spanMap['duration'] = spanDur;
        
        spanMap['service'] ??= spanMap['service_name'] ?? 'Unknown';
        spanMap['start_time'] ??= spanMap['start_time'];

        // Decode tags if it's a JSON string
        if (spanMap['tags'] is String && (spanMap['tags'] as String).isNotEmpty) {
          try {
            spanMap['tags'] = jsonDecode(spanMap['tags']);
          } catch (e) {
            debugPrint("ERROR: Failed to decode span tags: $e");
          }
        }

        // Decode logs if it's a JSON string
        if (spanMap['logs'] is String && (spanMap['logs'] as String).isNotEmpty) {
          try {
            spanMap['logs'] = jsonDecode(spanMap['logs']);
          } catch (e) {
            debugPrint("ERROR: Failed to decode span logs: $e");
          }
        }
        
        return spanMap;
      }).toList();
      normalized['spans'] = normalizedSpans;

      // Extract method and path for the trace title if missing
      if (normalized['method'] == null || normalized['path'] == null) {
        if (normalizedSpans.isNotEmpty) {
          final firstSpan = normalizedSpans[0];
          
          // Try to get from operation_name e.g. "GET /api/v1/resource"
          final opName = firstSpan['name'] as String?;
          if (opName != null && opName.contains(' ')) {
            final parts = opName.split(' ');
            normalized['method'] = parts[0];
            normalized['path'] = parts.sublist(1).join(' ');
          }

          // Try to get from tags JSON
          final tagsStr = firstSpan['tags'] as String?;
          if (tagsStr != null && tagsStr.isNotEmpty) {
            try {
              final tags = jsonDecode(tagsStr);
              if (tags is Map) {
                normalized['method'] ??= tags['http.method'];
                normalized['path'] ??= tags['http.url'];
              }
            } catch (_) {}
          }
        }
      }
    }

    // Final fallbacks
    normalized['method'] ??= 'GET';
    normalized['path'] ??= '/api/v1/resource';

    return normalized;
  }

  void reset() {
    _traces = [];
    _selectedTrace = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
