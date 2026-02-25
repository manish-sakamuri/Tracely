import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/workspace_provider.dart';
import '../providers/settings_provider.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onAuthSuccess;
  final VoidCallback onBackToLanding;

  const AuthScreen({
    Key? key,
    required this.onAuthSuccess,
    required this.onBackToLanding,
  }) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  bool _isLoading = false;
  
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError('Please fill in all fields');
      return;
    }

    if (!isLogin && _nameController.text.isEmpty) {
      _showError('Please enter your name');
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    bool success;

    try {
      if (isLogin) {
        success = await authProvider.login(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        success = await authProvider.register(
          _emailController.text.trim(),
          _passwordController.text,
          _nameController.text.trim(),
        );

        if (success) {
          success = await authProvider.login(
            _emailController.text.trim(),
            _passwordController.text,
          );
        }
      }

      if (success && mounted) {
        // Hydrate app data
        final settingsProv = Provider.of<SettingsProvider>(context, listen: false);
        final workspaceProv = Provider.of<WorkspaceProvider>(context, listen: false);

        await Future.wait([
          settingsProv.loadSettings(),
          workspaceProv.loadWorkspaces(),
        ]);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Authentication successful! Redirecting to dashboard...'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          // Navigate to home
          widget.onAuthSuccess();
        }
      } else if (mounted && authProvider.errorMessage != null) {
        _showError(authProvider.errorMessage!);
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: Container(
            color: Colors.white,
            child: Row(
              children: [
                // Left side - Value proposition
                Expanded(
                  flex: 5,
                  child: Container(
                    color: Colors.grey.shade900,
                    padding: const EdgeInsets.all(80),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: widget.onBackToLanding,
                          child: Row(
                            children: [
                              const Icon(Icons.arrow_back, color: Colors.white70, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Back to Home',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                        const Text(
                          'Tracely',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 40),
                        const Text(
                          'The modern way to build, test, and monitor APIs.',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Join thousands of development teams who trust Tracely for their API lifecycle management.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade400,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 48),
                        // Feature pills
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildPill('Request Studio'),
                            _buildPill('Distributed Tracing'),
                            _buildPill('Replay Engine'),
                            _buildPill('Mock Service'),
                            _buildPill('Load Testing'),
                            _buildPill('Schema Validator'),
                            _buildPill('Workflow Automation'),
                            _buildPill('Governance'),
                          ],
                        ),
                        
                        if (authProvider.isAuthenticated) ...[
                          const SizedBox(height: 40),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green.shade300),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'You are logged in!',
                                    style: TextStyle(
                                      color: Colors.green.shade300,
                                      fontWeight: FontWeight.w600,
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
                ),

                // Right side - Auth form
                Expanded(
                  flex: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (authProvider.isAuthenticated)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 30),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                                ),
                                child: Column(
                                  children: [
                                    const Text(
                                      "Session is active",
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                                    ),
                                    const SizedBox(height: 8),
                                    ElevatedButton(
                                      onPressed: widget.onAuthSuccess,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey.shade900,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text("Go to Dashboard →"),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          Text(
                            isLogin ? 'Welcome back' : 'Create account',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade900,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          isLogin
                              ? 'Sign in to your account'
                              : 'Start your API journey',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Name field (only for register)
                        if (!isLogin) ...[
                          _buildTextField(
                            'Full Name',
                            Icons.person_outline,
                            controller: _nameController,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Email field
                        _buildTextField(
                          'Email address',
                          Icons.email_outlined,
                          controller: _emailController,
                        ),
                        const SizedBox(height: 16),

                        // Password field
                        _buildTextField(
                          'Password',
                          Icons.lock_outline,
                          isPassword: true,
                          controller: _passwordController,
                        ),

                        const SizedBox(height: 24),

                        // Submit button
                        InkWell(
                          onTap: _isLoading ? null : _handleSubmit,
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: _isLoading ? Colors.grey.shade400 : Colors.grey.shade900,
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Center(
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Text(
                                      isLogin ? 'Sign in' : 'Create account',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Toggle link
                        Center(
                          child: TextButton(
                            onPressed: () {
                              setState(() {
                                isLogin = !isLogin;
                              });
                              authProvider.clearError();
                            },
                            child: Text(
                              isLogin
                                  ? 'Don\'t have an account? Sign up'
                                  : 'Already have an account? Sign in',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    IconData icon, {
    bool isPassword = false,
    required TextEditingController controller,
  }) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(icon, size: 20, color: Colors.grey.shade400),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: isPassword,
              decoration: InputDecoration(
                hintText: label,
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                ),
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _handleSubmit(),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}