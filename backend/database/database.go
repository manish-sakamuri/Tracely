package database

import (
	"backend/config"
	"backend/models"
	"fmt"
	"log"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func InitDB(cfg *config.Config) (*gorm.DB, error) {
	var logLevel logger.LogLevel
	switch cfg.LogLevel {
	case "debug":
		logLevel = logger.Info
	case "info":
		logLevel = logger.Warn
	default:
		logLevel = logger.Error
	}

	db, err := gorm.Open(postgres.Open(cfg.DatabaseURL), &gorm.Config{
		Logger: logger.Default.LogMode(logLevel),
	})
	if err != nil {
		return nil, fmt.Errorf("failed to connect to database: %w", err)
	}

	sqlDB, err := db.DB()
	if err != nil {
		return nil, fmt.Errorf("failed to get database instance: %w", err)
	}

	// Set connection pool settings
	sqlDB.SetMaxIdleConns(10)
	sqlDB.SetMaxOpenConns(100)

	log.Println("Database connection established")
	return db, nil
}

func CloseDB(db *gorm.DB) {
	sqlDB, err := db.DB()
	if err != nil {
		log.Printf("Error getting database instance: %v", err)
		return
	}
	if err := sqlDB.Close(); err != nil {
		log.Printf("Error closing database: %v", err)
	}
	log.Println("Database connection closed")
}

func RunMigrations(db *gorm.DB) error {
	log.Println("Running database migrations...")

	// Enable UUID extension
	if err := db.Exec("CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";").Error; err != nil {
		return fmt.Errorf("failed to create uuid extension: %w", err)
	}

	// Auto migrate all models
	err := db.AutoMigrate(
		&models.User{},
		&models.Workspace{},
		&models.WorkspaceMember{},
		&models.Collection{},
		&models.Request{},
		&models.Execution{},
		&models.Trace{},
		&models.Span{},
		&models.Annotation{},
		&models.Policy{},
		&models.UserSettings{},
		&models.Replay{},
		&models.ReplayExecution{},
		&models.Mock{},
		&models.RefreshToken{},
		&models.Environment{},
		&models.EnvironmentVariable{},
		&models.EnvironmentSecret{},
		&models.TestRun{},
		&models.UserLog{},
		&models.DeviceToken{},
	)

	if err != nil {
		return fmt.Errorf("failed to run migrations: %w", err)
	}

	// Create indexes for better performance
	createIndexes(db)

	// Clean up stale traces that have no status code (recorded before columns were added)
	cleanupStaleTraces(db)

	log.Println("Database migrations completed successfully")
	return nil
}

// cleanupStaleTraces removes old trace records that were recorded before
// the http_method, endpoint, and status_code columns existed. These rows
// have status_code = 0 and empty http_method/endpoint, providing no
// useful information.
func cleanupStaleTraces(db *gorm.DB) {
	result := db.Exec("DELETE FROM traces WHERE status_code = 0 OR status_code IS NULL")
	if result.Error != nil {
		log.Printf("Warning: could not clean up stale traces: %v", result.Error)
	} else if result.RowsAffected > 0 {
		log.Printf("Cleaned up %d stale trace records (missing status_code)", result.RowsAffected)
	}
	// Also clean up orphaned spans whose trace was deleted
	result = db.Exec("DELETE FROM spans WHERE trace_id NOT IN (SELECT id FROM traces)")
	if result.Error != nil {
		log.Printf("Warning: could not clean up orphaned spans: %v", result.Error)
	} else if result.RowsAffected > 0 {
		log.Printf("Cleaned up %d orphaned span records", result.RowsAffected)
	}
}

func createIndexes(db *gorm.DB) {
	// User indexes
	db.Exec("CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);")

	// Workspace indexes
	db.Exec("CREATE INDEX IF NOT EXISTS idx_workspaces_owner_id ON workspaces(owner_id);")

	// Collection indexes
	db.Exec("CREATE INDEX IF NOT EXISTS idx_collections_workspace_id ON collections(workspace_id);")

	// Request indexes
	db.Exec("CREATE INDEX IF NOT EXISTS idx_requests_collection_id ON requests(collection_id);")

	// Execution indexes
	db.Exec("CREATE INDEX IF NOT EXISTS idx_executions_request_id ON executions(request_id);")
	db.Exec("CREATE INDEX IF NOT EXISTS idx_executions_trace_id ON executions(trace_id);")
	db.Exec("CREATE INDEX IF NOT EXISTS idx_executions_span_id ON executions(span_id);")
	db.Exec("CREATE INDEX IF NOT EXISTS idx_executions_parent_span_id ON executions(parent_span_id);")
	db.Exec("CREATE INDEX IF NOT EXISTS idx_executions_timestamp ON executions(timestamp);")

	// Trace indexes
	db.Exec("CREATE INDEX IF NOT EXISTS idx_traces_workspace_id ON traces(workspace_id);")
	db.Exec("CREATE INDEX IF NOT EXISTS idx_traces_service_name ON traces(service_name);")
	db.Exec("CREATE INDEX IF NOT EXISTS idx_traces_start_time ON traces(start_time);")
	db.Exec("CREATE INDEX IF NOT EXISTS idx_traces_status ON traces(status);")

	// Span indexes
	db.Exec("CREATE INDEX IF NOT EXISTS idx_spans_trace_id ON spans(trace_id);")
	db.Exec("CREATE INDEX IF NOT EXISTS idx_spans_parent_span_id ON spans(parent_span_id);")
	db.Exec("CREATE INDEX IF NOT EXISTS idx_spans_service_name ON spans(service_name);")

	// Policy indexes
	db.Exec("CREATE INDEX IF NOT EXISTS idx_policies_workspace_id ON policies(workspace_id);")

	// Replay indexes
	db.Exec("CREATE INDEX IF NOT EXISTS idx_replays_workspace_id ON replays(workspace_id);")
	db.Exec("CREATE INDEX IF NOT EXISTS idx_replays_status ON replays(status);")

	// Mock indexes
	db.Exec("CREATE INDEX IF NOT EXISTS idx_mocks_workspace_id ON mocks(workspace_id);")
	db.Exec("CREATE INDEX IF NOT EXISTS idx_mocks_enabled ON mocks(enabled);")

	// TestRun indexes
	db.Exec("CREATE INDEX IF NOT EXISTS idx_test_runs_user_id ON test_runs(user_id);")
	db.Exec("CREATE INDEX IF NOT EXISTS idx_test_runs_created_at ON test_runs(created_at);")

	// UserLog indexes
	db.Exec("CREATE INDEX IF NOT EXISTS idx_user_logs_user_id ON user_logs(user_id);")
	db.Exec("CREATE INDEX IF NOT EXISTS idx_user_logs_level ON user_logs(level);")
	db.Exec("CREATE INDEX IF NOT EXISTS idx_user_logs_created_at ON user_logs(created_at);")

	// Alert indexes
	db.Exec("CREATE INDEX IF NOT EXISTS idx_alerts_workspace_id ON alerts(workspace_id);")
	db.Exec("CREATE INDEX IF NOT EXISTS idx_alerts_status ON alerts(status);")
	db.Exec("CREATE INDEX IF NOT EXISTS idx_alert_rules_workspace_id ON alert_rules(workspace_id);")

	log.Println("Database indexes created")
}
