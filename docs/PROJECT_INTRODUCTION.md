# Introduction to the Project

## What is it?

**Tracely** is a **Unified API Debugging, Distributed Tracing, and Scenario Automation Platform**. It is a full-stack application that helps developers and teams:

- **Debug and test APIs** — Build, run, and organize HTTP requests; capture responses and history.
- **Observe distributed systems** — Trace requests across services, view waterfalls and critical paths, and monitor latency and errors.
- **Automate scenarios** — Replay captured traffic, use mocks for dependencies, run load tests, and trigger alerts.

The platform gives you one place to test APIs, see how requests flow through your services, and automate regression and monitoring workflows.

---

## Who is it for?

- **Backend / API developers** — Build and execute requests, inspect traces, and debug slow or failing calls.
- **QA engineers** — Use replay and test generation for regression testing and scenario automation.
- **DevOps / SRE** — Configure tracing, monitor dashboards, set up alerts, and integrate with Slack, PagerDuty, Prometheus, or CI/CD.

Anyone with basic technical familiarity can use the Flutter UI (web or mobile) to work with workspaces, collections, traces, and automation.

---

## What does it do? (High-level features)

| Area | Capabilities |
|------|----------------|
| **Authentication & organization** | JWT-based login/register, multi-tenant workspaces, roles (admin/member/viewer), user settings. |
| **API testing & requests** | Request builder (method, headers, body, query params), real-time execution, response capture, collections, execution history, PII masking. |
| **Distributed tracing** | Trace and span collection, propagation (HTTP / gRPC / GraphQL), per-service config (sampling, exclusions), waterfall view, critical path, annotations. |
| **Monitoring** | Dashboards (counts, success/failure, latency, error rate), service topology, per-service latencies (P50/P95/P99), load testing, failure injection. |
| **Alerting** | Rules (e.g. latency or error-rate thresholds), active alerts, acknowledge/resolve, notifications (Slack, email, PagerDuty — stubs). |
| **Automation** | Replay captured requests, mocks for dependencies, workflows, environments and variables, governance policies, secrets management. |
| **Integrations** | Slack, PagerDuty, Prometheus, CloudWatch, CI/CD webhooks, Postman import. |

---

## Tech stack

- **Backend:** Go (Gin), PostgreSQL (GORM), JWT, middleware for trace propagation.
- **Frontend:** Flutter (Dart) — web, iOS, Android, desktop; Provider for state; single API base URL with platform-specific config for mobile.
- **Deployment:** Docker Compose for local run; backend and DB can be containerized; frontend can be built for web or mobile.

---

## One-line summary

**Tracely is an API observability and automation platform: you test and execute APIs, trace requests across services with waterfalls and metrics, and automate replay, mocks, load tests, and alerts — all through a Go backend and a Flutter web/mobile app.**

---

## Quick start (for readers who want to run it)

1. **Backend:** `cd backend && go run main.go` (requires PostgreSQL and `.env`; see `DEV_DOCS.md`).
2. **Frontend:** `cd frontend_1 && flutter run -d chrome` (or a device/emulator for mobile).
3. **Login:** Use the AUTH screen with default credentials (e.g. `admin@tracely.com` / `admin123` if seeded).
4. **Explore:** Create or open a workspace, add collections and requests, run them, and use the Tracing and Monitoring sections to view traces and dashboards.

For full setup, configuration, and troubleshooting, see **DEV_DOCS.md** and **README.md**.
