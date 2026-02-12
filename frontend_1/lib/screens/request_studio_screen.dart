// lib/screens/request_studio_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/request_provider.dart';
import 'dart:convert';
import 'dart:developer' as developer;

class RequestStudioScreen extends StatefulWidget {
  const RequestStudioScreen({Key? key}) : super(key: key);

  @override
  State<RequestStudioScreen> createState() => _RequestStudioScreenState();
}

class _RequestStudioScreenState extends State<RequestStudioScreen> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _bearerTokenController = TextEditingController();
  final TextEditingController _jsonBodyController = TextEditingController();
  
  String _selectedMethod = 'POST'; // Changed to POST for login
  bool _isSending = false;
  bool _isHeadersExpanded = true;
  bool _isBodyExpanded = true;
  bool _isAuthExpanded = true;

  final List<String> _httpMethods = [
    'GET',
    'POST',
    'PUT',
    'DELETE',
    'PATCH',
    'HEAD',
    'OPTIONS',
  ];

  // Sample headers
  final Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  @override
  void initState() {
    super.initState();
    _loadRequestData();
    // Set login JSON body
    _jsonBodyController.text = '''{
  "email": "subimv17@gmail.com",
  "password": "subi@2006"
}''';
    _urlController.text = 'http://localhost:8081/api/v1/auth/login';
  }

  void _loadRequestData() {
    final requestProvider = context.read<RequestProvider>();
    _selectedMethod = requestProvider.method;
    if (requestProvider.url.isNotEmpty) {
      _urlController.text = requestProvider.url;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _bearerTokenController.dispose();
    _jsonBodyController.dispose();
    super.dispose();
  }

  bool _isValidJson(String jsonString) {
    if (jsonString.trim().isEmpty) return false;
    try {
      json.decode(jsonString.trim());
      return true;
    } catch (e) {
      developer.log('JSON Validation Error: $e');
      return false;
    }
  }

  String? _formatJsonForBody(String jsonString) {
    try {
      if (jsonString.trim().isEmpty) return null;
      final decoded = json.decode(jsonString.trim());
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(decoded);
    } catch (e) {
      developer.log('JSON Format Error: $e');
      return null;
    }
  }

  Future<void> _sendRequest() async {
    final requestProvider = context.read<RequestProvider>();
    
    if (_urlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a URL'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Validate JSON for POST, PUT, PATCH requests
    if (['POST', 'PUT', 'PATCH'].contains(_selectedMethod)) {
      final bodyText = _jsonBodyController.text.trim();
      if (bodyText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request body is required for POST requests'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      
      if (!_isValidJson(bodyText)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid JSON format. Please check your syntax.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    setState(() {
      _isSending = true;
    });

    try {
      // Set method and URL
      requestProvider.setMethod(_selectedMethod);
      requestProvider.setUrl(_urlController.text.trim());
      
      // Set headers
      final headers = Map<String, String>.from(_headers);
      if (_bearerTokenController.text.isNotEmpty) {
        headers['Authorization'] = 'Bearer ${_bearerTokenController.text}';
      }
      requestProvider.setHeaders(headers);
      
      // IMPORTANT FIX: Parse JSON and set as actual JSON object, not string
      if (['POST', 'PUT', 'PATCH'].contains(_selectedMethod)) {
        final bodyText = _jsonBodyController.text.trim();
        if (bodyText.isNotEmpty) {
          try {
            // Parse the JSON to validate and get the actual object
            final jsonBody = json.decode(bodyText);
            // Set the body as the JSON object (will be stringified in the request)
            requestProvider.setBody(json.encode(jsonBody));
            developer.log('Sending JSON body: ${json.encode(jsonBody)}');
          } catch (e) {
            developer.log('Error parsing JSON: $e');
            requestProvider.setBody(bodyText);
          }
        }
      }
      
      // Send the request
      final response = await requestProvider.sendRequest();
      developer.log('Response received: $response');
      
      if (mounted) {
        setState(() {
          _isSending = false;
        });
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request sent successfully!'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      developer.log('Request error: $e');
      if (mounted) {
        setState(() {
          _isSending = false;
        });
        
        String errorMessage = e.toString();
        // Clean up error message for display
        if (errorMessage.contains('Exception:')) {
          errorMessage = errorMessage.split('Exception:').last.trim();
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request failed: $errorMessage'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _formatJsonButton() {
    final currentText = _jsonBodyController.text.trim();
    if (currentText.isEmpty) return;
    
    try {
      final decoded = json.decode(currentText);
      const encoder = JsonEncoder.withIndent('  ');
      final formatted = encoder.convert(decoded);
      setState(() {
        _jsonBodyController.text = formatted;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('JSON formatted successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot format invalid JSON: ${e.toString()}'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Color _getMethodColor(String method) {
    switch (method) {
      case 'GET':
        return const Color(0xFF0B5E7C);
      case 'POST':
        return const Color(0xFF117E6B);
      case 'PUT':
        return const Color(0xFF8A6E4B);
      case 'DELETE':
        return const Color(0xFFA33A3A);
      case 'PATCH':
        return const Color(0xFF7B4F9C);
      default:
        return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // LEFT PANEL - REQUEST BUILDER
          Expanded(
            flex: 5,
            child: Container(
              color: Colors.white,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'API Request Builder',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Build and test your API requests',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Request Section
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Request',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade500,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Method and URL row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // HTTP Method Dropdown
                              Container(
                                width: 90,
                                height: 40,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedMethod,
                                    isExpanded: true,
                                    icon: Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Icon(Icons.arrow_drop_down, size: 20, color: Colors.grey.shade700),
                                    ),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _getMethodColor(_selectedMethod),
                                    ),
                                    onChanged: (String? newValue) {
                                      if (newValue != null) {
                                        setState(() {
                                          _selectedMethod = newValue;
                                        });
                                      }
                                    },
                                    items: _httpMethods.map<DropdownMenuItem<String>>((String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Padding(
                                          padding: const EdgeInsets.only(left: 12),
                                          child: Text(
                                            value,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: _getMethodColor(value),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              
                              // URL Input
                              Expanded(
                                child: Container(
                                  height: 40,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      const SizedBox(width: 12),
                                      Icon(Icons.link, size: 16, color: Colors.grey.shade500),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          controller: _urlController,
                                          decoration: InputDecoration(
                                            hintText: 'http://localhost:8081/api/v1/auth/login',
                                            border: InputBorder.none,
                                            hintStyle: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade400,
                                            ),
                                          ),
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              
                              // Send Button
                              SizedBox(
                                width: 80,
                                height: 40,
                                child: ElevatedButton(
                                  onPressed: _isSending ? null : _sendRequest,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0B5E7C),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isSending
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : const Text(
                                          'Send',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // PARAMS SECTION
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Params',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade900,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, size: 16, color: Colors.grey.shade500),
                                const SizedBox(width: 8),
                                Text(
                                  'No query parameters',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // HEADERS SECTION
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () {
                              setState(() {
                                _isHeadersExpanded = !_isHeadersExpanded;
                              });
                            },
                            child: Row(
                              children: [
                                Text(
                                  'Headers',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade900,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  _isHeadersExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                                  size: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ],
                            ),
                          ),
                          if (_isHeadersExpanded) ...[
                            const SizedBox(height: 16),
                            // Content-Type header
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 120,
                                    child: Text(
                                      'Content-Type',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'application/json',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade700,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Authorization header
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 120,
                                    child: Text(
                                      'Authorization',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      _bearerTokenController.text.isNotEmpty
                                          ? 'Bearer ${_bearerTokenController.text}'
                                          : 'Bearer token123',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade700,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // BODY SECTION
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () {
                              setState(() {
                                _isBodyExpanded = !_isBodyExpanded;
                              });
                            },
                            child: Row(
                              children: [
                                Text(
                                  'Body',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade900,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  _isBodyExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                                  size: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ],
                            ),
                          ),
                          if (_isBodyExpanded) ...[
                            const SizedBox(height: 16),
                            // Format selector with Format button
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade900,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'JSON',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Form Data',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Raw',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                // Format JSON button
                                TextButton.icon(
                                  onPressed: _formatJsonButton,
                                  icon: Icon(Icons.format_align_left, size: 14, color: Colors.grey.shade700),
                                  label: Text(
                                    'Format JSON',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // JSON Body Editor
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: TextField(
                                controller: _jsonBodyController,
                                maxLines: 12,
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.all(16),
                                  hintText: 'Enter JSON body...',
                                  hintStyle: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade400,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  color: Colors.grey.shade900,
                                ),
                              ),
                            ),
                            if (!_isValidJson(_jsonBodyController.text) && _jsonBodyController.text.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.error_outline, size: 14, color: Colors.red.shade700),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Invalid JSON format',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.red.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),

                    // AUTH SECTION
                    Container(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () {
                              setState(() {
                                _isAuthExpanded = !_isAuthExpanded;
                              });
                            },
                            child: Row(
                              children: [
                                Text(
                                  'Auth',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade900,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  _isAuthExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                                  size: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ],
                            ),
                          ),
                          if (_isAuthExpanded) ...[
                            const SizedBox(height: 16),
                            // Authorization Type
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Authorization Type',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade900,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'Bearer Token',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Basic Auth',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'API Key',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Token',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _bearerTokenController,
                                    decoration: InputDecoration(
                                      hintText: 'Enter your bearer token',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        borderSide: BorderSide(color: Colors.grey.shade900, width: 1.5),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // DIVIDER
          Container(
            width: 1,
            color: Colors.grey.shade200,
          ),

          // RIGHT PANEL - RESPONSE
          Expanded(
            flex: 5,
            child: Consumer<RequestProvider>(
              builder: (context, requestProvider, child) {
                final response = requestProvider.response;
                
                if (response == null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.bolt,
                            size: 32,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No response yet',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Send a request to see the response',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Container(
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Response Header
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Response',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade500,
                                letterSpacing: 0.8,
                              ),
                            ),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(response['statusCode']).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(response['statusCode']),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${response['statusCode']} ${_getStatusText(response['statusCode'])}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _getStatusColor(response['statusCode']),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    '${response['duration']}ms',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Response Body
                      Expanded(
                        child: Container(
                          color: Colors.grey.shade50,
                          padding: const EdgeInsets.all(20),
                          child: SingleChildScrollView(
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: SelectableText(
                                _formatJson(response['body'] ?? '{}'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  color: Colors.grey.shade900,
                                  height: 1.6,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatJson(String jsonString) {
    try {
      if (jsonString.isEmpty) return '{}';
      final decoded = json.decode(jsonString);
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(decoded);
    } catch (e) {
      return jsonString;
    }
  }

  Color _getStatusColor(int? statusCode) {
    if (statusCode == null) return Colors.grey;
    if (statusCode >= 200 && statusCode < 300) return const Color(0xFF117E6B);
    if (statusCode >= 300 && statusCode < 400) return const Color(0xFF0B5E7C);
    if (statusCode >= 400 && statusCode < 500) return const Color(0xFFA33A3A);
    if (statusCode >= 500) return const Color(0xFFA33A3A);
    return Colors.grey.shade600;
  }

  String _getStatusText(int? statusCode) {
    if (statusCode == null) return '';
    if (statusCode == 200) return 'OK';
    if (statusCode == 201) return 'Created';
    if (statusCode == 204) return 'No Content';
    if (statusCode == 400) return 'Bad Request';
    if (statusCode == 401) return 'Unauthorized';
    if (statusCode == 403) return 'Forbidden';
    if (statusCode == 404) return 'Not Found';
    if (statusCode == 500) return 'Internal Server Error';
    return '';
  }
}