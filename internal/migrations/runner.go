package migrations

import (
"context"
"fmt"
"os"
"path/filepath"
"sort"
"github.com/opentrusty/opentrusty-cli/internal/database"
)

type Runner struct {
	db        *database.DB
	migDir    string
}

func NewRunner(db *database.DB, migDir string) *Runner {
	return &Runner{db: db, migDir: migDir}
}

func (r *Runner) MigrateUp(ctx context.Context) error {
	files, err := os.ReadDir(r.migDir)
	if err != nil {
		return fmt.Errorf("failed to read migrations: %w", err)
	}

	var sqlFiles []string
	for _, f := range files {
		if !f.IsDir() && filepath.Ext(f.Name()) == ".sql" {
			sqlFiles = append(sqlFiles, f.Name())
		}
	}
	sort.Strings(sqlFiles)

	for _, f := range sqlFiles {
		fmt.Printf("Executing migration: %s\n", f)
		content, err := os.ReadFile(filepath.Join(r.migDir, f))
		if err != nil {
			return fmt.Errorf("failed to read %s: %w", f, err)
		}
		if _, err := r.db.Pool.Exec(ctx, string(content)); err != nil {
			return fmt.Errorf("failed to execute %s: %w", f, err)
		}
	}
	return nil
}
