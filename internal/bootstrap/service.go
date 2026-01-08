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

package bootstrap

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"fmt"
	"time"

	"github.com/opentrusty/opentrusty-core/audit"
	"github.com/opentrusty/opentrusty-core/id"
	"github.com/opentrusty/opentrusty-core/role"
	"github.com/opentrusty/opentrusty-core/user"
)

var ErrAlreadyBootstrapped = errors.New("system is already bootstrapped")

// Config holds bootstrap configuration.
//
// Purpose: Seed data for initializing the first platform administrator.
// Domain: Platform
type Config struct {
	AdminEmail    string
	AdminPassword string
}

// Service handles the initial system bootstrap process.
//
// Purpose: One-time initialization logic for a fresh installation.
// Domain: Platform
type Service struct {
	userService    *user.Service
	assignmentRepo role.AssignmentRepository
	auditRepo      audit.Repository
	cfg            Config
}

// NewService creates a new bootstrap service.
//
// Purpose: Constructor for the bootstrap logic.
// Domain: Platform
// Audited: No
// Errors: None
func NewService(us *user.Service, ar role.AssignmentRepository, audit audit.Repository, cfg Config) *Service {
	return &Service{
		userService:    us,
		assignmentRepo: ar,
		auditRepo:      audit,
		cfg:            cfg,
	}
}

// Bootstrap initializes the system if it hasn't been done already.
//
// Purpose: Creates the first platform administrator and initial security boundaries.
// Domain: Platform
// Security: Only succeeds if no platform admin assignment exists. Prints sensitive credentials to stdout.
// Audited: Indirectly (via UserCreated/RoleGranted)
// Errors: ErrAlreadyBootstrapped, System errors
func (s *Service) Bootstrap(ctx context.Context) error {
	if s.cfg.AdminEmail == "" {
		return fmt.Errorf("admin email not configured")
	}

	exists, err := s.assignmentRepo.CheckExists(ctx, role.RoleIDPlatformAdmin, role.ScopePlatform, nil)
	if err != nil {
		return err
	}
	if exists {
		return ErrAlreadyBootstrapped
	}

	password := s.cfg.AdminPassword
	if password == "" {
		b := make([]byte, 16)
		rand.Read(b)
		password = base64.RawURLEncoding.EncodeToString(b) + "!1aA"
	}

	profile := user.Profile{
		GivenName:  "Platform",
		FamilyName: "Admin",
		FullName:   "Platform Admin",
	}

	u, err := s.userService.ProvisionIdentity(ctx, s.cfg.AdminEmail, profile)
	if err != nil {
		return fmt.Errorf("failed to provision identity: %w", err)
	}

	if err := s.userService.AddPassword(ctx, u.ID, password); err != nil {
		return fmt.Errorf("failed to set password: %w", err)
	}

	assignment := &role.Assignment{
		ID:        id.NewUUIDv7(),
		UserID:    u.ID,
		RoleID:    role.RoleIDPlatformAdmin,
		Scope:     role.ScopePlatform,
		GrantedAt: time.Now(),
		GrantedBy: "", // System grant (NULL in DB)
	}

	if err := s.assignmentRepo.Grant(ctx, assignment); err != nil {
		return fmt.Errorf("failed to grant platform admin role: %w", err)
	}

	fmt.Printf("\n=== BOOTSTRAP SUCCESS ===\nEmail: %s\nPassword: %s\n=========================\n\n", s.cfg.AdminEmail, password)
	return nil
}
