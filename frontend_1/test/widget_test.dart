// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend_1/main.dart';
import 'package:frontend_1/providers/auth_provider.dart';
import 'package:frontend_1/providers/workspace_provider.dart';
import 'package:frontend_1/providers/collection_provider.dart';
import 'package:frontend_1/providers/governance_provider.dart';
import 'package:frontend_1/providers/dashboard_provider.dart';
import 'package:frontend_1/providers/trace_provider.dart';
import 'package:frontend_1/providers/environment_provider.dart';
import 'package:frontend_1/providers/replay_provider.dart';
import 'package:frontend_1/providers/request_provider.dart';
import 'package:frontend_1/providers/monitoring_provider.dart';
import 'package:frontend_1/providers/schema_validator_provider.dart';
import 'package:frontend_1/providers/settings_provider.dart';
import 'package:frontend_1/providers/test_data_generator_provider.dart';
import 'package:frontend_1/providers/alert_provider.dart';
import 'package:frontend_1/providers/audit_provider.dart';
import 'package:frontend_1/providers/failure_injection_provider.dart';
import 'package:frontend_1/providers/load_test_provider.dart';
import 'package:frontend_1/providers/mock_provider.dart';
import 'package:frontend_1/providers/mutation_provider.dart';
import 'package:frontend_1/providers/percentile_provider.dart';
import 'package:frontend_1/providers/secrets_provider.dart';
import 'package:frontend_1/providers/tracing_config_provider.dart';
import 'package:frontend_1/providers/waterfall_provider.dart';
import 'package:frontend_1/providers/webhook_provider.dart';
import 'package:frontend_1/providers/workflow_provider.dart';

void main() {
  testWidgets('TracelyApp smoke test builds with providers', (WidgetTester tester) async {
    await tester.pumpWidget(
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

    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(TracelyApp), findsOneWidget);
  });
}
