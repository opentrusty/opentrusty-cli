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
