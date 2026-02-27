import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/workspace_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/animations.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onAuthSuccess;
  final VoidCallback onBackToLanding;
  final String? initialEmail;

  const AuthScreen({
    Key? key,
    required this.onAuthSuccess,
    required this.onBackToLanding,
    this.initialEmail,
  }) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  bool isLogin = true;
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _obscurePassword = true;
  
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  late AnimationController _bgController;

  // Password strength
  double _passwordStrength = 0;
  String _strengthLabel = '';
  Color _strengthColor = Colors.grey.shade300;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _emailController.text = widget.initialEmail!;
      // Auto-switch to register if email provided from landing
      isLogin = false;
    }
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
    _passwordController.addListener(_evaluatePassword);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  void _evaluatePassword() {
    final password = _passwordController.text;
    double strength = 0;
    if (password.length >= 6) strength += 0.2;
    if (password.length >= 10) strength += 0.2;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength += 0.2;
    if (RegExp(r'[0-9]').hasMatch(password)) strength += 0.2;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength += 0.2;

    String label;
    Color color;
    if (strength <= 0.2) {
      label = 'Weak';
      color = Colors.red.shade400;
    } else if (strength <= 0.4) {
      label = 'Fair';
      color = Colors.orange.shade400;
    } else if (strength <= 0.6) {
      label = 'Good';
      color = Colors.amber.shade600;
    } else if (strength <= 0.8) {
      label = 'Strong';
      color = Colors.green.shade400;
    } else {
      label = 'Very Strong';
      color = Colors.green.shade700;
    }

    setState(() {
      _passwordStrength = strength;
      _strengthLabel = password.isEmpty ? '' : label;
      _strengthColor = color;
    });
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

    if (!isLogin && _passwordStrength < 0.4) {
      _showError('Password is too weak. Add uppercase, numbers, or symbols.');
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
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('Authentication successful! Redirecting...'),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.all(16),
            ),
          );
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
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
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
                // Left side - Value proposition with animated gradient
                Expanded(
                  flex: 5,
                  child: AnimatedBuilder(
                    animation: _bgController,
                    builder: (context, child) {
                      final t = _bgController.value;
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment(
                              -1 + math.sin(t * math.pi * 2) * 0.5,
                              -1 + math.cos(t * math.pi * 2) * 0.5,
                            ),
                            end: Alignment(
                              1 + math.cos(t * math.pi * 2) * 0.3,
                              1 + math.sin(t * math.pi * 2) * 0.3,
                            ),
                            colors: [
                              Colors.grey.shade900,
                              const Color(0xFF1a1a2e),
                              const Color(0xFF16213e),
                            ],
                          ),
                        ),
                        padding: const EdgeInsets.all(80),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FadeSlideIn(
                              child: GestureDetector(
                                onTap: widget.onBackToLanding,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: Row(
                                    children: [
                                      const Icon(Icons.arrow_back, color: Colors.white70, size: 18),
                                      const SizedBox(width: 8),
                                      Text('Back to Home', style: TextStyle(fontSize: 14, color: Colors.grey.shade400)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),
                            FadeSlideIn(
                              delay: const Duration(milliseconds: 100),
                              child: Row(
                                children: [
                                  const PulseWidget(
                                    duration: Duration(seconds: 2),
                                    minScale: 0.9,
                                    maxScale: 1.1,
                                    child: Icon(Icons.bolt, color: Color(0xFFFF6B2C), size: 36),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Tracely', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 40),
                            FadeSlideIn(
                              delay: const Duration(milliseconds: 200),
                              child: const Text(
                                'The modern way to build,\ntest, and monitor APIs.',
                                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w600, color: Colors.white, height: 1.3),
                              ),
                            ),
                            const SizedBox(height: 24),
                            FadeSlideIn(
                              delay: const Duration(milliseconds: 300),
                              child: Text(
                                'Join thousands of development teams who trust Tracely for their API lifecycle management.',
                                style: TextStyle(fontSize: 16, color: Colors.grey.shade400, height: 1.6),
                              ),
                            ),
                            const SizedBox(height: 48),
                            // Feature pills
                            FadeSlideIn(
                              delay: const Duration(milliseconds: 400),
                              child: Wrap(
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
                                        style: TextStyle(color: Colors.green.shade300, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
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
                                    const Text("Session is active", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
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

                          FadeSlideIn(
                            child: Text(
                              isLogin ? 'Welcome back' : 'Create account',
                              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.grey.shade900),
                            ),
                          ),
                          const SizedBox(height: 8),
                          FadeSlideIn(
                            delay: const Duration(milliseconds: 50),
                            child: Text(
                              isLogin ? 'Sign in to your account' : 'Start your API journey',
                              style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                            ),
                          ),
                          const SizedBox(height: 40),

                          // Name field (only for register)
                          if (!isLogin) ...[
                            FadeSlideIn(
                              delay: const Duration(milliseconds: 100),
                              child: _buildTextField('Full Name', Icons.person_outline, controller: _nameController),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Email field
                          FadeSlideIn(
                            delay: Duration(milliseconds: isLogin ? 100 : 150),
                            child: _buildTextField('Email address', Icons.email_outlined, controller: _emailController),
                          ),
                          const SizedBox(height: 16),

                          // Password field
                          FadeSlideIn(
                            delay: Duration(milliseconds: isLogin ? 150 : 200),
                            child: _buildTextField(
                              'Password',
                              Icons.lock_outline,
                              isPassword: true,
                              controller: _passwordController,
                            ),
                          ),

                          // Password strength indicator
                          if (!isLogin && _passwordController.text.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            FadeSlideIn(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      height: 4,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(2),
                                        color: Colors.grey.shade200,
                                      ),
                                      child: FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: _passwordStrength,
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 300),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(2),
                                            color: _strengthColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _strengthLabel,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _strengthColor),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),

                          // Remember me + Forgot password
                          FadeSlideIn(
                            delay: Duration(milliseconds: isLogin ? 200 : 250),
                            child: Row(
                              children: [
                                SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: Checkbox(
                                    value: _rememberMe,
                                    onChanged: (v) => setState(() => _rememberMe = v ?? false),
                                    activeColor: const Color(0xFFFF6B2C),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    side: BorderSide(color: Colors.grey.shade400),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('Remember me', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                                const Spacer(),
                                if (isLogin)
                                  Text('Forgot password?', style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Submit button
                          FadeSlideIn(
                            delay: Duration(milliseconds: isLogin ? 250 : 300),
                            child: MouseRegion(
                              cursor: _isLoading ? MouseCursor.defer : SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: _isLoading ? null : _handleSubmit,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  height: 50,
                                  decoration: BoxDecoration(
                                    gradient: _isLoading
                                        ? null
                                        : const LinearGradient(
                                            colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
                                          ),
                                    color: _isLoading ? Colors.grey.shade400 : null,
                                    borderRadius: BorderRadius.circular(25),
                                    boxShadow: _isLoading
                                        ? null
                                        : [
                                            BoxShadow(
                                              color: Colors.grey.shade900.withOpacity(0.2),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
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
                                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Toggle link
                          FadeSlideIn(
                            delay: Duration(milliseconds: isLogin ? 300 : 350),
                            child: Center(
                              child: TextButton(
                                onPressed: () {
                                  setState(() => isLogin = !isLogin);
                                  Provider.of<AuthProvider>(context, listen: false).clearError();
                                },
                                child: Text(
                                  isLogin ? 'Don\'t have an account? Sign up' : 'Already have an account? Sign in',
                                  style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
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
      child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
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
              obscureText: isPassword && _obscurePassword,
              decoration: InputDecoration(
                hintText: label,
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _handleSubmit(),
            ),
          ),
          if (isPassword)
            IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 18,
                color: Colors.grey.shade400,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}