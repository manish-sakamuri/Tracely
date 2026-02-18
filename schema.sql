-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

------------------------------------------------
-- USERS
------------------------------------------------
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL UNIQUE,
    password TEXT NOT NULL,
    name TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMP
);

------------------------------------------------
-- WORKSPACES
------------------------------------------------
CREATE TABLE workspaces (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    owner_id UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMP
);

------------------------------------------------
-- WORKSPACE MEMBERS
------------------------------------------------
CREATE TABLE workspace_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID NOT NULL REFERENCES workspaces(id),
    user_id UUID NOT NULL REFERENCES users(id),
    role TEXT NOT NULL DEFAULT 'member',
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMP,
    UNIQUE (workspace_id, user_id)
);

------------------------------------------------
-- COLLECTIONS
------------------------------------------------
CREATE TABLE collections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    workspace_id UUID NOT NULL REFERENCES workspaces(id),
    request_count INT DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMP
);

------------------------------------------------
-- REQUESTS
------------------------------------------------
CREATE TABLE requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    method TEXT NOT NULL,
    url TEXT NOT NULL,
    headers JSONB,
    query_params JSONB,
    body JSONB,
    description TEXT,
    collection_id UUID NOT NULL REFERENCES collections(id),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMP
);

------------------------------------------------
-- EXECUTIONS
------------------------------------------------
CREATE TABLE executions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID NOT NULL REFERENCES requests(id),
    status_code INT,
    response_time_ms BIGINT,
    response_body TEXT,
    response_headers JSONB,
    trace_id UUID,
    span_id UUID,
    parent_span_id UUID,
    error_message TEXT,
    timestamp TIMESTAMP NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMP
);

------------------------------------------------
-- TRACES
------------------------------------------------
CREATE TABLE traces (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID NOT NULL REFERENCES workspaces(id),
    service_name TEXT NOT NULL,
    span_count INT DEFAULT 0,
    total_duration_ms DOUBLE PRECISION,
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP,
    status TEXT NOT NULL DEFAULT 'success',
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMP
);

------------------------------------------------
-- SPANS
------------------------------------------------
CREATE TABLE spans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trace_id UUID NOT NULL REFERENCES traces(id),
    parent_span_id UUID REFERENCES spans(id),
    operation_name TEXT NOT NULL,
    service_name TEXT NOT NULL,
    start_time TIMESTAMP NOT NULL,
    duration_ms DOUBLE PRECISION,
    tags JSONB,
    logs JSONB,
    status TEXT DEFAULT 'ok',
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMP
);

------------------------------------------------
-- ANNOTATIONS
------------------------------------------------
CREATE TABLE annotations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    span_id UUID NOT NULL REFERENCES spans(id),
    user_id UUID NOT NULL REFERENCES users(id),
    comment TEXT NOT NULL,
    highlight BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMP
);

------------------------------------------------
-- POLICIES
------------------------------------------------
CREATE TABLE policies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID NOT NULL REFERENCES workspaces(id),
    name TEXT NOT NULL,
    description TEXT,
    enabled BOOLEAN DEFAULT TRUE,
    rules JSONB NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMP
);

------------------------------------------------
-- USER SETTINGS
------------------------------------------------
CREATE TABLE user_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES users(id),
    theme TEXT DEFAULT 'light',
    notifications_enabled BOOLEAN DEFAULT TRUE,
    email_notifications BOOLEAN DEFAULT TRUE,
    language TEXT DEFAULT 'en',
    timezone TEXT DEFAULT 'UTC',
    preferences JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMP
);

------------------------------------------------
-- REPLAYS
------------------------------------------------
CREATE TABLE replays (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID NOT NULL REFERENCES workspaces(id),
    name TEXT NOT NULL,
    description TEXT,
    source_trace_id UUID REFERENCES traces(id),
    source_request_id UUID REFERENCES requests(id),
    target_environment TEXT NOT NULL,
    configuration JSONB NOT NULL,
    status TEXT DEFAULT 'pending',
    created_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMP
);

------------------------------------------------
-- REPLAY EXECUTIONS
------------------------------------------------
CREATE TABLE replay_executions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    replay_id UUID NOT NULL REFERENCES replays(id),
    execution_trace_id UUID REFERENCES traces(id),
    status TEXT NOT NULL,
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP,
    duration_ms BIGINT,
    results JSONB,
    error_message TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMP
);

------------------------------------------------
-- MOCKS
------------------------------------------------
CREATE TABLE mocks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID NOT NULL REFERENCES workspaces(id),
    name TEXT NOT NULL,
    description TEXT,
    method TEXT NOT NULL,
    path_pattern TEXT NOT NULL,
    response_body JSONB,
    response_headers JSONB,
    status_code INT DEFAULT 200,
    latency INT DEFAULT 0,
    enabled BOOLEAN DEFAULT TRUE,
    source_trace_id UUID REFERENCES traces(id),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMP
);

------------------------------------------------
-- REFRESH TOKENS
------------------------------------------------
CREATE TABLE refresh_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    token TEXT NOT NULL UNIQUE,
    expires_at TIMESTAMP NOT NULL,
    revoked_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMP
);

------------------------------------------------
-- ENVIRONMENTS
------------------------------------------------
CREATE TABLE environments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID NOT NULL REFERENCES workspaces(id),
    name VARCHAR(255) NOT NULL,
    type VARCHAR(50) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMP
);

------------------------------------------------
-- ENVIRONMENT VARIABLES
------------------------------------------------
CREATE TABLE environment_variables (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    environment_id UUID NOT NULL REFERENCES environments(id),
    key VARCHAR(255) NOT NULL,
    value TEXT NOT NULL,
    type VARCHAR(50),
    description TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMP
);

------------------------------------------------
-- ENVIRONMENT SECRETS
------------------------------------------------
CREATE TABLE environment_secrets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    environment_id UUID NOT NULL REFERENCES environments(id),
    key VARCHAR(255) NOT NULL,
    value TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMP
);

------------------------------------------------
-- SERVICE TRACING CONFIG
------------------------------------------------
CREATE TABLE service_tracing_configs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID NOT NULL REFERENCES workspaces(id),
    service_name VARCHAR(255) NOT NULL,
    enabled BOOLEAN DEFAULT TRUE,
    sampling_rate DOUBLE PRECISION DEFAULT 1.0,
    log_trace_headers BOOLEAN DEFAULT TRUE,
    propagate_context BOOLEAN DEFAULT TRUE,
    capture_request_body BOOLEAN DEFAULT FALSE,
    capture_response_body BOOLEAN DEFAULT FALSE,
    max_body_size_bytes INT DEFAULT 10240,
    exclude_paths JSONB DEFAULT '[]'::jsonb,
    custom_tags JSONB DEFAULT '{}'::jsonb,
    description TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMP
);
