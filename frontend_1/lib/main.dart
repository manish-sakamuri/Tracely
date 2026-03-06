import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/landing_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/workspace_provider.dart';
import 'providers/collection_provider.dart';
import 'providers/governance_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/trace_provider.dart';
import 'providers/environment_provider.dart';
import 'providers/replay_provider.dart';
import 'providers/request_provider.dart';
import 'services/api_service.dart';
import 'providers/monitoring_provider.dart';
import 'providers/schema_validator_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/test_data_generator_provider.dart';
import 'providers/alert_provider.dart';
import 'providers/audit_provider.dart';
import 'providers/failure_injection_provider.dart';
import 'providers/load_test_provider.dart';
import 'providers/mock_provider.dart';
import 'providers/mutation_provider.dart';
import 'providers/percentile_provider.dart';
import 'providers/secrets_provider.dart';
import 'providers/tracing_config_provider.dart';
import 'providers/waterfall_provider.dart';
import 'providers/webhook_provider.dart';
import 'providers/workflow_provider.dart';


void main() async { 
  WidgetsFlutterBinding.ensureInitialized();
  
  final apiService = ApiService();
  await apiService.loadTokens();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => WorkspaceProvider()),
        ChangeNotifierProvider(create: (_) => CollectionProvider()),
        ChangeNotifierProvider(create: (_) => GovernanceProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => TraceProvider()),
        ChangeNotifierProvider(create: (_) => ReplayProvider()),
        ChangeNotifierProvider(create: (_) => RequestProvider()),
        ChangeNotifierProvider(create: (_) => EnvironmentProvider()),
        ChangeNotifierProvider(create: (_) => MonitoringProvider()),
        ChangeNotifierProvider(create: (_) => SchemaValidatorProvider()),
        ChangeNotifierProvider(create: (_) => TestDataGeneratorProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => AlertProvider()),
        ChangeNotifierProvider(create: (_) => AuditProvider()),
        ChangeNotifierProvider(create: (_) => FailureInjectionProvider()),
        ChangeNotifierProvider(create: (_) => LoadTestProvider()),
        ChangeNotifierProvider(create: (_) => MockProvider()),
        ChangeNotifierProvider(create: (_) => MutationProvider()),
        ChangeNotifierProvider(create: (_) => PercentileProvider()),
        ChangeNotifierProvider(create: (_) => SecretsProvider()),
        ChangeNotifierProvider(create: (_) => TracingConfigProvider()),
        ChangeNotifierProvider(create: (_) => WaterfallProvider()),
        ChangeNotifierProvider(create: (_) => WebhookProvider()),
        ChangeNotifierProvider(create: (_) => WorkflowProvider()),
      ],
      child: const TracelyApp(),
    ),
  );
}

class TracelyApp extends StatelessWidget {
  const TracelyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tracely',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'SF Pro Display',
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        colorScheme: ColorScheme.light(
          primary: Colors.grey.shade900,
          secondary: Colors.grey.shade700,
          surface: Colors.white,
        ),
      ),
      home: const TracelyRouter(),
    );
  }
}

/// Auth-aware router: manages the top-level screen based on auth state.
/// Landing (unauthenticated) → Auth → Home (authenticated)
class TracelyRouter extends StatefulWidget {
  const TracelyRouter({Key? key}) : super(key: key);

  @override
  State<TracelyRouter> createState() => _TracelyRouterState();
}

class _TracelyRouterState extends State<TracelyRouter> {
  // 0 = landing, 1 = auth, 2 = home (dashboard)
  int _currentView = 0;
  String? _prefillEmail;
  bool _isHydrating = false;

  void _goToLanding() => setState(() => _currentView = 0);
  void _goToAuth([String? email]) => setState(() {
    _prefillEmail = email;
    _currentView = 1;
  });

  /// Navigate to Home. Awaits hydration so workspace + user state are restored after refresh.
  Future<void> _goToHome() async {
    if (_currentView == 2 || _isHydrating) return;
    setState(() => _isHydrating = true);
    await _hydrateAppData();
    if (!mounted) return;
    setState(() {
      _isHydrating = false;
      _currentView = 2;
    });
  }

  void _handleLogout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
    setState(() => _currentView = 0);
  }

  Future<void> _hydrateAppData() async {
    final workspaceProv = Provider.of<WorkspaceProvider>(context, listen: false);
    final settingsProv = Provider.of<SettingsProvider>(context, listen: false);
    await Future.wait([
      workspaceProv.loadWorkspaces(),
      settingsProv.loadSettings(),
    ]);
  }

  @override
  void initState() {
    super.initState();
    // After first frame, if already authenticated (e.g. after refresh), hydrate and go to home
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isAuthenticated && _currentView < 2) {
        await _goToHome();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // If auth is still loading, show a splash
        if (authProvider.isLoading) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    color: Color(0xFFFF6B2C),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading Tracely...',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Auto-redirect if already authenticated but on landing/auth (e.g. after refresh)
        if (authProvider.isAuthenticated && _currentView < 2 && !_isHydrating) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await _goToHome();
          });
        }

        if (_isHydrating) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFFFF6B2C)),
                  const SizedBox(height: 16),
                  Text(
                    'Loading your workspace...',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        }

        switch (_currentView) {
          case 0:
            return LandingScreen(
              onGetStarted: _goToAuth,
              onGoToDashboard: _goToHome,
            );
          case 1:
            return AuthScreen(
              onAuthSuccess: _goToHome,
              onBackToLanding: _goToLanding,
              initialEmail: _prefillEmail,
            );
          case 2:
          default:
            return HomeScreen(
              onLogout: _handleLogout,
              onNavigateToAuth: _goToAuth,
            );
        }
      },
    );
  }
}