package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/opentrusty/opentrusty-cli/internal/bootstrap"
	"github.com/opentrusty/opentrusty-cli/internal/config"
	"github.com/opentrusty/opentrusty-core/audit"
	"github.com/opentrusty/opentrusty-core/store/postgres"
	"github.com/opentrusty/opentrusty-core/user"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: opentrusty <command> [args]")
		os.Exit(1)
	}

	cmd := os.Args[1]
	ctx := context.Background()

	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("failed to load configuration: %v", err)
	}

	db, err := postgres.Open(ctx, cfg.DBURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
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
