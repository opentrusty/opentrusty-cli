// Copyright 2026 The OpenTrusty Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"os"
	"time"

	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/opentrusty/opentrusty-cli/internal/bootstrap"
	"github.com/opentrusty/opentrusty-cli/internal/config"
	"github.com/opentrusty/opentrusty-core/audit"
	"github.com/opentrusty/opentrusty-core/store/postgres"
	"github.com/opentrusty/opentrusty-core/user"
)

var version = "dev"

func ensureDatabaseExists(cfg *config.Config) error {
	dsn := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=postgres sslmode=%s",
		cfg.DBHost, cfg.DBPort, cfg.DBUser, cfg.DBPassword, cfg.DBSSLMode)

	db, err := sql.Open("pgx", dsn)
	if err != nil {
		return err
	}
	defer db.Close()

	if err := db.Ping(); err != nil {
		return fmt.Errorf("failed to connect to postgres server: %w", err)
	}

	var exists bool
	query := `SELECT EXISTS(SELECT datname FROM pg_catalog.pg_database WHERE datname = $1)`
	if err := db.QueryRow(query, cfg.DBName).Scan(&exists); err != nil {
		return fmt.Errorf("failed to check if database exists: %w", err)
	}

	if !exists {
		fmt.Printf("Database %q does not exist, creating it...\n", cfg.DBName)
		quotedDBName := fmt.Sprintf(`"%s"`, cfg.DBName)
		if _, err := db.Exec(fmt.Sprintf("CREATE DATABASE %s", quotedDBName)); err != nil {
			return fmt.Errorf("failed to create database: %w", err)
		}
	}

	return nil
}

func main() {
	if len(os.Args) > 1 && os.Args[1] == "--version" {
		println(version)
		os.Exit(0)
	}

	if len(os.Args) < 2 {
		fmt.Printf("OpenTrusty CLI version %s\n", version)
		fmt.Println("Usage: opentrusty <command> [args]")
		os.Exit(1)
	}

	cmd := os.Args[1]
	ctx := context.Background()

	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("failed to load configuration: %v", err)
	}

	// Auto-create database if running setup commands
	if cmd == "migrate" || cmd == "bootstrap" {
		if err := ensureDatabaseExists(cfg); err != nil {
			log.Fatalf("pre-flight database check failed: %v", err)
		}
	}

	// Database
	db, err := postgres.New(ctx, postgres.Config{
		Host:     cfg.DBHost,
		Port:     cfg.DBPort,
		User:     cfg.DBUser,
		Password: cfg.DBPassword,
		Database: cfg.DBName,
		SSLMode:  cfg.DBSSLMode,
	})

	if err != nil {
		log.Fatalf("failed to connect to database: %v", err)
	}
	defer db.Close()

	switch cmd {
	case "migrate":
		if err := db.Migrate(ctx, postgres.InitialSchema); err != nil {
			log.Fatalf("Migration failed: %v", err)
		}
		fmt.Println("Migrations completed successfully.")

	case "bootstrap":
		// Wire up services with real repositories
		auditLogger := audit.NewSlogLogger()
		userRepo := postgres.NewUserRepository(db)
		assignmentRepo := postgres.NewAssignmentRepository(db)
		auditRepo := postgres.NewAuditRepository(db)

		hasher := user.NewPasswordHasher(65536, 1, 1, 16, 32)
		userService := user.NewService(userRepo, hasher, auditLogger, 5, 15*time.Minute, cfg.IdentitySecret)

		email := cfg.BootstrapEmail
		if email == "" {
			email = "admin@opentrusty.org"
		}

		bootstrapSvc := bootstrap.NewService(
			userService,
			assignmentRepo,
			auditRepo,
			bootstrap.Config{
				AdminEmail:    email,
				AdminPassword: cfg.BootstrapPass,
			},
		)

		if err := bootstrapSvc.Bootstrap(ctx); err != nil {
			log.Fatalf("Bootstrap failed: %v", err)
		}

	default:
		fmt.Printf("Unknown command: %s\n", cmd)
		os.Exit(1)
	}
}
