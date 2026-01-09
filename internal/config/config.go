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

package config

import (
	"fmt"
	"os"
)

type Config struct {
	DatabaseURL    string
	LogLevel       string
	IdentitySecret string
	BootstrapEmail string
	BootstrapPass  string
}

func Load() (*Config, error) {
	c := &Config{
		DatabaseURL:    os.Getenv("OPENTRUSTY_DATABASE_URL"),
		LogLevel:       os.Getenv("OPENTRUSTY_LOG_LEVEL"),
		IdentitySecret: os.Getenv("OPENTRUSTY_IDENTITY_SECRET"),
		BootstrapEmail: os.Getenv("OPENTRUSTY_BOOTSTRAP_ADMIN_EMAIL"),
		BootstrapPass:  os.Getenv("OPENTRUSTY_BOOTSTRAP_ADMIN_PASSWORD"),
	}

	if c.LogLevel == "" {
		c.LogLevel = "info"
	}

	if err := c.Validate(); err != nil {
		return nil, err
	}

	return c, nil
}

func (c *Config) Validate() error {
	if c.DatabaseURL == "" {
		return fmt.Errorf("OPENTRUSTY_DATABASE_URL is required")
	}
	if c.IdentitySecret == "" {
		return fmt.Errorf("OPENTRUSTY_IDENTITY_SECRET is required")
	}
	return nil
}
