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

	"github.com/joho/godotenv"
)

type Config struct {
	LogLevel       string
	IdentitySecret string
	BootstrapEmail string
	BootstrapPass  string

	// Database discrete configuration
	DBHost     string
	DBPort     string
	DBUser     string
	DBPassword string
	DBName     string
	DBSSLMode  string
}

func Load() (*Config, error) {
	// Try loading from default locations if not explicitly provided via env
	// 1. .env in CWD
	// 2. /etc/opentrusty/cli.env
	envFiles := []string{".env", "/etc/opentrusty/cli.env"}
	for _, f := range envFiles {
		if _, err := os.Stat(f); err == nil {
			_ = godotenv.Load(f)
		}
	}

	c := &Config{
		LogLevel:       os.Getenv("OPENTRUSTY_LOG_LEVEL"),
		IdentitySecret: os.Getenv("OPENTRUSTY_IDENTITY_SECRET"),
		BootstrapEmail: os.Getenv("OPENTRUSTY_BOOTSTRAP_ADMIN_EMAIL"),
		BootstrapPass:  os.Getenv("OPENTRUSTY_BOOTSTRAP_ADMIN_PASSWORD"),

		DBHost:     os.Getenv("OPENTRUSTY_DB_HOST"),
		DBPort:     os.Getenv("OPENTRUSTY_DB_PORT"),
		DBUser:     os.Getenv("OPENTRUSTY_DB_USER"),
		DBPassword: os.Getenv("OPENTRUSTY_DB_PASSWORD"),
		DBName:     os.Getenv("OPENTRUSTY_DB_NAME"),
		DBSSLMode:  os.Getenv("OPENTRUSTY_DB_SSLMODE"),
	}

	if c.LogLevel == "" {
		c.LogLevel = "info"
	}

	// Default DB Port and SSLMode if not specified
	if c.DBPort == "" {
		c.DBPort = "5432"
	}
	if c.DBSSLMode == "" {
		c.DBSSLMode = "disable"
	}

	if err := c.Validate(); err != nil {
		return nil, err
	}

	return c, nil
}

func (c *Config) Validate() error {
	// Discrete fields must be provided
	if c.DBHost == "" || c.DBUser == "" || c.DBName == "" {
		return fmt.Errorf("database configuration is required (provide discrete OPENTRUSTY_DB_* variables)")
	}
	if c.IdentitySecret == "" {
		return fmt.Errorf("OPENTRUSTY_IDENTITY_SECRET is required")
	}
	return nil
}
