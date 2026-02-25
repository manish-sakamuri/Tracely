import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/workspace_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedTab = 0;
  final List<Map<String, dynamic>> _tabs = [
    {'icon': Icons.person_outline, 'label': 'Profile'},
    {'icon': Icons.tune, 'label': 'Preferences'},
    {'icon': Icons.security, 'label': 'Security'},
    {'icon': Icons.info_outline, 'label': 'About'},
  ];

  // Controllers for profile editing
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();
      _populateProfileFields();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _populateProfileFields() {
    final auth = context.read<AuthProvider>();
    _nameController.text = auth.user?['name'] ?? '';
    _emailController.text = auth.user?['email'] ?? '';
  }

  Future<void> _loadSettings() async {
    await context.read<SettingsProvider>().loadSettings();
  }

  Future<void> _saveSettings(Map<String, dynamic> updates) async {
    setState(() => _isSaving = true);
    final success = await context.read<SettingsProvider>().updateSettings(updates);
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '✅ Settings saved' : '❌ Failed to save settings'),
          backgroundColor: success ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, SettingsProvider>(
      builder: (context, authProvider, settingsProvider, child) {
        return Container(
          color: const Color(0xFFF8F9FA),
          child: Row(
            children: [
              // Settings sidebar
              Container(
                width: 220,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(right: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // User info header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.grey.shade900,
                            child: Text(
                              authProvider.user?['name']?.toString().substring(0, 1).toUpperCase() ?? 'U',
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  authProvider.user?['name'] ?? 'User',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade900),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  authProvider.user?['email'] ?? '',
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Tab items
                    ...List.generate(_tabs.length, (index) {
                      final isActive = _selectedTab == index;
                      return InkWell(
                        onTap: () => setState(() => _selectedTab = index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: isActive ? Colors.grey.shade100 : Colors.transparent,
                            border: Border(
                              left: BorderSide(
                                color: isActive ? Colors.grey.shade900 : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _tabs[index]['icon'] as IconData,
                                size: 16,
                                color: isActive ? Colors.grey.shade900 : Colors.grey.shade500,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _tabs[index]['label'] as String,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                                  color: isActive ? Colors.grey.shade900 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              // Content area
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: _buildTabContent(authProvider, settingsProvider),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabContent(AuthProvider authProvider, SettingsProvider settingsProvider) {
    switch (_selectedTab) {
      case 0:
        return _buildProfileTab(authProvider);
      case 1:
        return _buildPreferencesTab(settingsProvider);
      case 2:
        return _buildSecurityTab();
      case 3:
        return _buildAboutTab();
      default:
        return const SizedBox();
    }
  }

  // ========== PROFILE TAB ==========
  Widget _buildProfileTab(AuthProvider authProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.grey.shade900)),
            const Spacer(),
            if (!_isEditing)
              _actionButton('Edit Profile', Icons.edit, () => setState(() => _isEditing = true)),
          ],
        ),
        const SizedBox(height: 24),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar + Name
              Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.grey.shade900,
                    child: Text(
                      authProvider.user?['name']?.toString().substring(0, 1).toUpperCase() ?? 'U',
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authProvider.user?['name'] ?? 'User',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          authProvider.user?['email'] ?? '',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_isEditing) ...[
                const SizedBox(height: 24),
                Divider(color: Colors.grey.shade200),
                const SizedBox(height: 20),
                _inputField('Full Name', _nameController),
                const SizedBox(height: 16),
                _inputField('Email', _emailController),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        _populateProfileFields();
                        setState(() => _isEditing = false);
                      },
                      child: Text('Cancel', style: TextStyle(color: Colors.grey.shade700)),
                    ),
                    const SizedBox(width: 8),
                    _primaryButton('Save Changes', _isSaving, () {
                      _saveSettings({
                        'name': _nameController.text.trim(),
                        'email': _emailController.text.trim(),
                      });
                      setState(() => _isEditing = false);
                    }),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Workspace info
        _card(
          child: Consumer<WorkspaceProvider>(
            builder: (context, workspaceProvider, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Workspace', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade900)),
                  const SizedBox(height: 12),
                  _infoRow('Active Workspace', workspaceProvider.selectedWorkspace?['name'] ?? 'None'),
                  _infoRow('Total Workspaces', '${workspaceProvider.workspaces.length}'),
                  _infoRow('Workspace ID', workspaceProvider.selectedWorkspaceId ?? 'N/A'),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // ========== PREFERENCES TAB ==========
  Widget _buildPreferencesTab(SettingsProvider settingsProvider) {
    final settings = settingsProvider.settings ?? {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Preferences', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.grey.shade900)),
        const SizedBox(height: 24),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('General', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade900)),
              const SizedBox(height: 16),
              _toggleRow('Dark Mode', 'Use dark theme across the app', settings['dark_mode'] ?? false, (val) {
                _saveSettings({...settings, 'dark_mode': val});
              }),
              const SizedBox(height: 12),
              _toggleRow('Auto-save Requests', 'Automatically save request changes', settings['auto_save'] ?? true, (val) {
                _saveSettings({...settings, 'auto_save': val});
              }),
              const SizedBox(height: 12),
              _toggleRow('Real-time Trace Updates', 'Poll for new traces automatically', settings['realtime_traces'] ?? true, (val) {
                _saveSettings({...settings, 'realtime_traces': val});
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Request Defaults', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade900)),
              const SizedBox(height: 16),
              _toggleRow('Follow Redirects', 'Automatically follow HTTP redirects', settings['follow_redirects'] ?? true, (val) {
                _saveSettings({...settings, 'follow_redirects': val});
              }),
              const SizedBox(height: 12),
              _toggleRow('SSL Verification', 'Verify SSL certificates', settings['ssl_verification'] ?? true, (val) {
                _saveSettings({...settings, 'ssl_verification': val});
              }),
              const SizedBox(height: 12),
              _toggleRow('Send Cookies', 'Include cookies with requests', settings['send_cookies'] ?? false, (val) {
                _saveSettings({...settings, 'send_cookies': val});
              }),
            ],
          ),
        ),
        if (settingsProvider.isLoading)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey.shade600)),
          ),
      ],
    );
  }

  // ========== SECURITY TAB ==========
  Widget _buildSecurityTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Security', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.grey.shade900)),
        const SizedBox(height: 24),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Change Password', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade900)),
              const SizedBox(height: 16),
              _inputField('Current Password', _currentPasswordController, isPassword: true),
              const SizedBox(height: 12),
              _inputField('New Password', _newPasswordController, isPassword: true),
              const SizedBox(height: 12),
              _inputField('Confirm Password', _confirmPasswordController, isPassword: true),
              const SizedBox(height: 20),
              _primaryButton('Update Password', _isSaving, () {
                if (_newPasswordController.text != _confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Passwords do not match'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
                  );
                  return;
                }
                _saveSettings({
                  'current_password': _currentPasswordController.text,
                  'new_password': _newPasswordController.text,
                });
                _currentPasswordController.clear();
                _newPasswordController.clear();
                _confirmPasswordController.clear();
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Session', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade900)),
              const SizedBox(height: 16),
              _infoRow('Session Status', 'Active'),
              _infoRow('Token Type', 'JWT'),
              const SizedBox(height: 12),
              Consumer<AuthProvider>(
                builder: (context, auth, _) => Text(
                  'Logged in as: ${auth.user?['email'] ?? 'Unknown'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ========== ABOUT TAB ==========
  Widget _buildAboutTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('About Tracely', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.grey.shade900)),
        const SizedBox(height: 24),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bolt, color: Color(0xFFFF6B2C), size: 28),
                  const SizedBox(width: 10),
                  Text('Tracely', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.grey.shade900)),
                ],
              ),
              const SizedBox(height: 16),
              _infoRow('Version', '1.0.0'),
              _infoRow('Backend', 'localhost:8081'),
              _infoRow('Framework', 'Flutter Web + Go/Gin'),
              _infoRow('Database', 'PostgreSQL'),
              _infoRow('Auth', 'JWT + Bcrypt'),
              const SizedBox(height: 16),
              Text(
                'Unified API debugging, distributed tracing, and scenario automation platform.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.5),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _pill('Request Studio'), _pill('Distributed Tracing'), _pill('Replay Engine'),
                  _pill('Mock Service'), _pill('Load Testing'), _pill('Schema Validator'),
                  _pill('Governance'), _pill('Workflows'), _pill('Secrets Vault'),
                  _pill('Alerting'), _pill('Monitoring'), _pill('Audit Logs'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ========== REUSABLE WIDGETS ==========
  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }

  Widget _inputField(String label, TextEditingController controller, {bool isPassword = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
        const SizedBox(height: 6),
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  Widget _toggleRow(String title, String desc, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey.shade900)),
              Text(desc, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.grey.shade900,
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade900)),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton(String label, bool loading, VoidCallback onPressed) {
    return InkWell(
      onTap: loading ? null : onPressed,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: loading ? Colors.grey.shade400 : Colors.grey.shade900,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: loading
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
              : Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _actionButton(String label, IconData icon, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey.shade700),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.grey.shade700)),
    );
  }
}