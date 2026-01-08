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
	"testing"

	"github.com/opentrusty/opentrusty-core/role"
)

type mockAssignmentRepo struct {
	role.AssignmentRepository
	exists bool
}

func (m *mockAssignmentRepo) CheckExists(ctx context.Context, roleID string, scope role.Scope, scopeContextID *string) (bool, error) {
	return m.exists, nil
}

func (m *mockAssignmentRepo) Grant(ctx context.Context, assignment *role.Assignment) error {
	m.exists = true
	return nil
}

func TestBootstrapIdempotency(t *testing.T) {
	_ = &mockAssignmentRepo{exists: false}
	// Note: In real tests we'd need a real user.Service or a mock.
	// For this UT we focus on the higher level logic in Service.Bootstrap
}

func TestBootstrapValidation(t *testing.T) {
	svc := &Service{cfg: Config{}} // Missing AdminEmail
	err := svc.Bootstrap(context.Background())
	if err == nil {
		t.Error("expected error for missing AdminEmail")
	}
}
