

This module does two things:

1. **Distributed Tracing** – When a request goes through many services (API → Auth → Database → Cache), we record each step as a **span** under one **trace**. So we can see the full journey of a request and find where time is spent or where it failed.
2. **Monitoring** – We show dashboards (request counts, success/fail, latency), **service topology** (which service calls which), **latency percentiles** (P50, P95, P99), **load testing**, and **alerts** when something goes wrong.

---

## 2. High-level flow (what you can say)

- **HTTP/gRPC/GraphQL** requests get **trace IDs and span IDs** via middlewares so that all services can correlate their work.
- **Tracing config** is per workspace and per service: we can enable/disable tracing, set sampling rate, exclude paths, and control whether we propagate context to downstream calls.
- **Traces and spans** are stored in the DB; we can list traces, get trace details with spans, add **annotations** on spans, compute the **critical path** (longest chain), and generate **waterfall** view for the UI.
- **Monitoring** uses execution and trace data to build dashboard stats, topology graph, and per-service latencies (with a **percentile calculator**).
- **Load testing** runs a saved request with concurrency and total requests, then records success/failure and response time percentiles.
- **Alerts** are rules (e.g. latency or error rate above threshold); when triggered they create an alert and can notify via Slack/Email/PagerDuty (stub implementations).
- **Failure injection** (in services) can simulate timeout, error, latency, or unavailability for testing resilience.

---

## 3. Handlers (HTTP API layer)

| Handler | File | What it does |
|--------|------|----------------|
| **TraceHandler** | `handlers/trace_handler.go` | `GetTraces` – list traces (filter by service, time, pagination). `GetTraceDetails` – one trace + its spans. `AddAnnotation` – add comment/highlight on a span. `GetCriticalPath` – longest chain of spans. `GetWaterfall` – tree of spans for waterfall chart. |
| **TracingConfigHandler** | `handlers/tracing_config_handler.go` | CRUD for tracing config per service: Create, Update, Delete, GetByID, GetByServiceName, GetAll. Toggle (enable/disable one config), BulkToggle (many services). GetEnabledServices, GetDisabledServices, Check (is tracing enabled for a service?). |
| **MonitoringHandler** | `handlers/monitoring_handler.go` | `GetDashboard` – total/success/fail requests, avg response time, error rate, top endpoints, services. `GetTopology` – nodes and edges for service dependency graph. `GetServiceLatencies` – per-service count, avg, P50/P95/P99. `GetMetrics` – placeholder. |
| **LoadTestHandler** | `handlers/loadtest_handler.go` | `Create` – create a load test (name, request_id, concurrency, total_requests, ramp_up); starts execution in background and returns the load test record. |
| **AlertHandler** | `handlers/alert_handler.go` | `CreateRule` – create alert rule (name, condition, threshold, time_window, channel). `GetActiveAlerts` – list active alerts for workspace. `AcknowledgeAlert` – mark alert as acknowledged. |

---

## 4. Services (business logic)

| Service | File | What it does |
|---------|------|----------------|
| **TraceService** | `services/trace_service.go` | CreateTrace, AddSpan (with parent_span_id for hierarchy). GetTraces (with workspace access check, filters). GetTraceDetails. AddAnnotation. GetCriticalPath – finds longest chain of parent-child spans. |
| **WaterfallService** | `services/waterfall_service.go` | Builds a **tree** from a trace’s spans (root = no parent). Each node has span_id, name, service_name, start/end, duration, offset from trace start, depth, children, tags. Used for UI waterfall chart. |
| **MonitoringService** | `services/monitoring_service.go` | GetDashboard – from Executions: total/success/fail, error rate, avg response time; from Traces: services list. GetTopology – from Spans: which service calls which (parent span’s service → child span’s service). GetServiceLatencies – aggregate span durations by service, use PercentileCalculator for P50/P95/P99. |
| **LoadTestService** | `services/load_test_service.go` | CreateLoadTest – inserts LoadTest (pending), then runs executeLoadTest in a goroutine. executeLoadTest – runs concurrent workers that call RequestService.Execute for the given request_id, collects success/fail and response times, then updates LoadTest with status, success_count, failure_count, avg/P95/P99. |
| **FailureInjectionService** | `services/failure_injection_service.go` | InjectFailure – for a workspace, loads enabled rules, applies by probability; types: timeout (sleep 35s), error (from config status_code/message), latency (sleep delay_ms), unavailable (503). CreateRule – store a new rule. |
| **PercentileCalculator** | `services/percentile_calculator.go` | Calculate(values, percentile) – sort values, compute percentile index with linear interpolation. CalculatePercentiles(values, []float64) – returns map e.g. p50, p95, p99. Used by MonitoringService and LoadTestService. |
| **AlertingService** | `services/alerting_service.go` | CreateRule – store AlertRule (condition e.g. latency_threshold/error_rate, threshold, time_window, channel). CheckLatencyThreshold / CheckErrorRate – evaluate rules, TriggerAlert if exceeded. TriggerAlert – create Alert, send to Slack/Email/PagerDuty (stubs). AcknowledgeAlert, ResolveAlert, GetActiveAlerts. |

*(TracingConfigHandler uses TracingConfigService in `services/tracing_config_service.go` – same module, CRUD + toggle + enabled/disabled lists + IsTracingEnabled.)*

---
