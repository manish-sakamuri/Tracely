import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/footer_widget.dart';

class LandingScreen extends StatefulWidget {
  final VoidCallback onGetStarted;
  final VoidCallback onGoToDashboard;

  const LandingScreen({
    Key? key,
    required this.onGetStarted,
    required this.onGoToDashboard,
  }) : super(key: key);

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> with TickerProviderStateMixin {
  // Typing animation
  final String _fullText = 'APIs, Without\nthe Chaos.';
  String _displayedText = '';
  int _charIndex = 0;
  Timer? _typingTimer;
  bool _showCursor = true;
  Timer? _cursorTimer;

  // Fade-in animations
  late AnimationController _fadeController;
  late Animation<double> _subtitleFade;
  late Animation<double> _buttonFade;
  late Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _subtitleFade = CurvedAnimation(parent: _fadeController, curve: const Interval(0.0, 0.6, curve: Curves.easeOut));
    _buttonFade = CurvedAnimation(parent: _fadeController, curve: const Interval(0.3, 1.0, curve: Curves.easeOut));
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic));

    _startTyping();
    _cursorTimer = Timer.periodic(const Duration(milliseconds: 530), (_) {
      if (mounted) setState(() => _showCursor = !_showCursor);
    });
  }

  void _startTyping() {
    _typingTimer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
      if (_charIndex < _fullText.length) {
        setState(() {
          _displayedText = _fullText.substring(0, _charIndex + 1);
          _charIndex++;
        });
      } else {
        timer.cancel();
        // Start fade-in of subtitle and buttons after typing finishes
        _fadeController.forward();
      }
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _cursorTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(authProvider),
                _buildHeroSection(authProvider),
                _buildWhatIsTracely(),
                _buildFeatureCards(),
                const SizedBox(height: 80),
                _buildServicesShowcase(),
                const SizedBox(height: 80),
                _buildCredibilitySection(),
                const SizedBox(height: 80),
                _buildCTASection(authProvider),
                const SizedBox(height: 60),
                const FooterWidget(),
                const SizedBox(height: 80),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(AuthProvider authProvider) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          // Logo with bolt icon
          Row(
            children: [
              const Icon(Icons.bolt, color: Color(0xFFFF6B2C), size: 28),
              const SizedBox(width: 4),
              Text('Tracely', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.grey.shade900, letterSpacing: -0.5)),
            ],
          ),
          const SizedBox(width: 60),
          _buildNavLink('Platform'),
          _buildNavLink('Docs'),
          _buildNavLink('Pricing'),
          const Spacer(),
          if (authProvider.isAuthenticated) ...[
            Text('Welcome, ${authProvider.user?['name'] ?? 'User'}', style: TextStyle(fontSize: 14, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: widget.onGoToDashboard,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(color: Colors.grey.shade900, borderRadius: BorderRadius.circular(20)),
                child: const Text('Dashboard →', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
          ] else ...[
            GestureDetector(
              onTap: widget.onGetStarted,
              child: Text('Sign In', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey.shade700)),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: widget.onGetStarted,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(color: Colors.grey.shade900, borderRadius: BorderRadius.circular(20)),
                child: const Text('Get Started Free', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeroSection(AuthProvider authProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 80),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (authProvider.isAuthenticated) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade700, size: 16),
                        const SizedBox(width: 8),
                        Text("You're logged in!", style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                // ===== TYPING ANIMATION =====
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: _displayedText,
                        style: TextStyle(
                          fontSize: 60,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey.shade900,
                          height: 1.1,
                          letterSpacing: -2,
                        ),
                      ),
                      TextSpan(
                        text: _showCursor ? '|' : ' ',
                        style: TextStyle(
                          fontSize: 60,
                          fontWeight: FontWeight.w300,
                          color: const Color(0xFFFF6B2C),
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                // Subtitle fades in after typing
                SlideTransition(
                  position: _slideUp,
                  child: FadeTransition(
                    opacity: _subtitleFade,
                    child: Text(
                      'Tracely helps teams design, test, govern, and monitor APIs in one collaborative workspace. '
                      'Capture traffic, generate tests, replay traces, and automate scenarios — beyond Postman.',
                      style: TextStyle(fontSize: 18, color: Colors.grey.shade600, height: 1.6, letterSpacing: -0.2),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                // Buttons fade in
                FadeTransition(
                  opacity: _buttonFade,
                  child: authProvider.isAuthenticated
                      ? GestureDetector(
                          onTap: widget.onGoToDashboard,
                          child: _heroButton('Go to Dashboard →', Colors.grey.shade900, Colors.white),
                        )
                      : Row(
                          children: [
                            GestureDetector(
                              onTap: widget.onGetStarted,
                              child: _heroButton('Get Started Free →', Colors.grey.shade900, Colors.white),
                            ),
                            const SizedBox(width: 16),
                            GestureDetector(
                              onTap: widget.onGetStarted,
                              child: Container(
                                height: 52,
                                padding: const EdgeInsets.symmetric(horizontal: 32),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(26),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Center(
                                  child: Text('Sign In', style: TextStyle(color: Colors.grey.shade900, fontWeight: FontWeight.w600, fontSize: 16)),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 60),
          // Right side — animated terminal preview
          Expanded(
            flex: 4,
            child: _buildTerminalPreview(),
          ),
        ],
      ),
    );
  }

  Widget _heroButton(String text, Color bg, Color fg) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(26)),
      child: Center(child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 16))),
    );
  }

  Widget _buildTerminalPreview() {
    return Container(
      height: 420,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 30, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Terminal title bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D3F),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFFF5F57), shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFFFBD2E), shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF28C840), shape: BoxShape.circle)),
                const Spacer(),
                Text('tracely — terminal', style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontFamily: 'monospace')),
                const Spacer(),
              ],
            ),
          ),
          // Terminal content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _termLine('\$ tracely trace --service checkout', const Color(0xFF89B4FA)),
                  const SizedBox(height: 6),
                  _termLine('📡 Capturing spans for service: checkout', const Color(0xFFA6E3A1)),
                  _termLine('   ├─ [200ms] POST /api/v1/orders', const Color(0xFFF9E2AF)),
                  _termLine('   ├─ [45ms]  GET  /api/v1/inventory', const Color(0xFFF9E2AF)),
                  _termLine('   ├─ [310ms] POST /api/v1/payments', const Color(0xFFFAB387)),
                  _termLine('   ├─ [12ms]  POST /api/v1/notifications', const Color(0xFFF9E2AF)),
                  _termLine('   └─ [8ms]   POST /api/v1/audit-log', const Color(0xFFA6E3A1)),
                  const SizedBox(height: 8),
                  _termLine('✅ Trace ID: order_abc123 — 5 spans captured', const Color(0xFFA6E3A1)),
                  _termLine('⏱  Total: 575ms | P99: 310ms (payment)', const Color(0xFFCBA6F7)),
                  const SizedBox(height: 8),
                  _termLine('\$ tracely replay order_abc123 --env staging', const Color(0xFF89B4FA)),
                  _termLine('🔄 Replaying trace on staging.api.com...', const Color(0xFFA6E3A1)),
                  _termLine('✅ All 5 spans passed. No regressions.', const Color(0xFFA6E3A1)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _termLine(String text, Color color) {
    return Text(text, style: TextStyle(fontFamily: 'monospace', fontSize: 11.5, color: color, height: 1.6));
  }

  Widget _buildNavLink(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey.shade700)),
    );
  }

  Widget _buildWhatIsTracely() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What is Tracely?', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: Colors.grey.shade900, letterSpacing: -0.5)),
          const SizedBox(height: 20),
          Text(
            'Tracely is an end-to-end API lifecycle platform that unifies design, testing, documentation, monitoring, and governance. '
            'It sits between the user and backend services to capture real-world usage data, convert it into test data, and provide full distributed tracing.',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCards() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 80),
      child: Column(
        children: [
          Row(children: [
            Expanded(flex: 3, child: _buildFeatureCard('API Toolkit', 'Build, test, simulate, and document APIs. Request Studio, Schema Validator, and Test Data Generator.', Icons.build_circle, const Color(0xFF6366F1))),
            const SizedBox(width: 24),
            Expanded(flex: 2, child: _buildFeatureCard('Distributed Tracing', 'Visualize request flows via waterfall charts. Correlate logs with traces for unified debugging.', Icons.timeline, const Color(0xFF06B6D4))),
          ]),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(flex: 2, child: _buildFeatureCard('Replay & Mocking', 'Replay historical traces to reproduce bugs. Mock downstream dependencies automatically.', Icons.replay_circle_filled, const Color(0xFFF59E0B))),
            const SizedBox(width: 24),
            Expanded(flex: 3, child: _buildFeatureCard('Governance & Security', 'Enforce standards, mask PII, manage secrets, and audit all actions. Enterprise-grade governance.', Icons.shield, const Color(0xFF10B981))),
          ]),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(String title, String description, IconData icon, Color accent) {
    return Container(
      height: 280,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: accent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 24, color: accent),
          ),
          const SizedBox(height: 20),
          Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.grey.shade900)),
          const SizedBox(height: 12),
          Text(description, style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.6)),
        ],
      ),
    );
  }

  Widget _buildServicesShowcase() {
    final categories = [
      {
        'title': '🔍 Observability',
        'services': ['Trace Service', 'Waterfall View', 'Tracing Config', 'Percentile Calculator', 'Monitoring'],
      },
      {
        'title': '🧪 Testing & Simulation',
        'services': ['Replay Engine', 'Test Data Generator', 'Mock Service', 'Load Testing', 'Failure Injection'],
      },
      {
        'title': '⚙️ Automation',
        'services': ['Workflow Engine', 'Request Studio', 'Schema Validator', 'Mutation Testing', 'Alerting'],
      },
      {
        'title': '🔐 Management & Security',
        'services': ['Workspaces', 'Auth Service', 'Secrets Vault', 'Webhooks', 'Audit Logs'],
      },
      {
        'title': '🌐 Governance & Environments',
        'services': ['Environment Manager', 'Governance Engine', 'Session Service', 'Settings', 'Collections'],
      },
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('25 Integrated Services', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: Colors.grey.shade900, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          Text(
            'A closed-loop ecosystem: detect issues with Tracing, reproduce them with Replay, prevent recurrence with Automation.',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600, height: 1.5),
          ),
          const SizedBox(height: 32),
          ...categories.map((cat) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cat['title'] as String, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (cat['services'] as List<String>).map((s) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(s, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade800)),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCredibilitySection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 80),
      padding: const EdgeInsets.all(60),
      decoration: BoxDecoration(color: Colors.grey.shade900, borderRadius: BorderRadius.circular(32)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatBox('25', 'Backend Services'),
          _buildStatBox('100%', 'API Coverage'),
          _buildStatBox('<1s', 'Trace Capture'),
          _buildStatBox('∞', 'Replay Capacity'),
        ],
      ),
    );
  }

  Widget _buildStatBox(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey.shade400)),
      ],
    );
  }

  Widget _buildCTASection(AuthProvider authProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 60),
      child: Column(
        children: [
          Text(
            authProvider.isAuthenticated ? 'Continue your journey' : 'Start building with Tracely',
            style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: Colors.grey.shade900),
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: authProvider.isAuthenticated ? widget.onGoToDashboard : widget.onGetStarted,
            child: _heroButton(
              authProvider.isAuthenticated ? 'Open Dashboard →' : 'Get Started Free →',
              Colors.grey.shade900,
              Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
