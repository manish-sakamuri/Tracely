import 'dart:async';
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tracely/core/config/env_config.dart';
import 'package:tracely/screens/auth/signup_screen.dart';
import 'package:tracely/services/api_service.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;

  const LoginScreen({super.key, this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _listenForDeepLinks();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _linkSubscription?.cancel();
    super.dispose();
  }

  /// Listen for incoming deep links (used for GitHub OAuth callback).
  void _listenForDeepLinks() {
    _linkSubscription = _appLinks.uriLinkStream.listen((Uri uri) {
      debugPrint('[Login] Deep link received: $uri');
      if (uri.scheme == 'tracely' && uri.path.contains('github/callback')) {
        _handleGitHubDeepLink(uri);
      }
    });
  }

  /// Process the deep link from GitHub OAuth callback.
  Future<void> _handleGitHubDeepLink(Uri uri) async {
    final accessToken = uri.queryParameters['access_token'];
    final refreshToken = uri.queryParameters['refresh_token'];

    if (accessToken != null && refreshToken != null) {
      await ApiService().saveTokens(accessToken, refreshToken);
      if (mounted) widget.onLoginSuccess?.call();
    } else {
      if (mounted) {
        setState(() {
          _errorMessage = 'GitHub login failed: missing tokens';
          _isLoading = false;
        });
      }
    }
  }

  // ================= EMAIL / PASSWORD LOGIN =================

  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      await ApiService()
          .login(_emailController.text.trim(), _passwordController.text);

      if (mounted) widget.onLoginSuccess?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  // ================= GOOGLE SIGN IN =================

  Future<void> _signInWithGoogle() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      // On Android, serverClientId (Web client ID) is REQUIRED to get an idToken.
      // Without it, auth.idToken will always be null.
      final googleSignIn = GoogleSignIn(
        serverClientId: EnvConfig.googleClientId,
      );

      final account = await googleSignIn.signIn();
      if (account == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;

      if (idToken == null) {
        throw Exception('Google sign-in failed: missing ID token');
      }

      await ApiService().googleAuth(idToken);

      if (mounted) widget.onLoginSuccess?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  // ================= GITHUB SIGN IN =================

  Future<void> _signInWithGitHub() async {
    if (!EnvConfig.hasGitHubAuth) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GitHub login not configured')),
        );
      }
      return;
    }

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      final clientId = EnvConfig.githubClientId;
      // Build the backend callback URL for GitHub to redirect to
      final backendCallbackUrl =
          '${EnvConfig.baseUrl}/auth/github/callback';

      final random = Random.secure();
      final stateBytes = List<int>.generate(32, (_) => random.nextInt(256));
      final state =
          stateBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      debugPrint('[Login] GitHub OAuth state: $state');

      final authUrl = Uri.parse(
        'https://github.com/login/oauth/authorize'
        '?client_id=$clientId'
        '&redirect_uri=${Uri.encodeComponent(backendCallbackUrl)}'
        '&scope=user:email'
        '&state=$state',
      );

      final launched =
          await launchUrl(authUrl, mode: LaunchMode.externalApplication);
      if (!launched) {
        throw Exception(
            'Could not open GitHub login page. Please check your browser settings.');
      }

      // The deep link listener (_listenForDeepLinks) will capture the
      // callback from the backend and complete the login automatically.
      // Keep loading state active while waiting for the redirect.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  // ================= SIGNUP =================

  void _navigateToSignup() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SignupScreen(
          onSignupSuccess: () {
            // Pop the signup screen, then trigger login success
            Navigator.of(context).pop();
            widget.onLoginSuccess?.call();
          },
        ),
      ),
    );
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                _buildLogo(theme),
                const SizedBox(height: 24),
                _buildEmailField(theme),
                const SizedBox(height: 16),
                _buildPasswordField(theme),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  _buildErrorBanner(theme),
                ],
                const SizedBox(height: 24),
                _buildSignInButton(theme),
                const SizedBox(height: 12),
                _buildSignupButton(theme),
                const SizedBox(height: 24),
                _buildDivider(theme),
                const SizedBox(height: 24),
                _buildSocialButtons(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(ThemeData theme) {
    return Center(
      child: Text(
        'Tracely',
        style: theme.textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    ).animate().fadeIn();
  }

  Widget _buildEmailField(ThemeData theme) {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: const InputDecoration(labelText: 'Email'),
      validator: (v) => v == null || v.isEmpty ? 'Enter email' : null,
    );
  }

  Widget _buildPasswordField(ThemeData theme) {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: 'Password',
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
          ),
          onPressed: () =>
              setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      validator: (v) => v == null || v.isEmpty ? 'Enter password' : null,
    );
  }

  Widget _buildErrorBanner(ThemeData theme) {
    return Text(
      _errorMessage!,
      style: TextStyle(color: theme.colorScheme.error),
    );
  }

  Widget _buildSignInButton(ThemeData theme) {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleLogin,
      child: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('Sign in'),
    );
  }

  Widget _buildSignupButton(ThemeData theme) {
    return TextButton(
      onPressed: _isLoading ? null : _navigateToSignup,
      child: const Text('Don\'t have an account? Sign up'),
    );
  }

  Widget _buildDivider(ThemeData theme) {
    return const Divider();
  }

  Widget _buildSocialButtons(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading ? null : _signInWithGoogle,
            child: const Text('Google'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading ? null : _signInWithGitHub,
            child: const Text('GitHub'),
          ),
        ),
      ],
    );
  }
}
