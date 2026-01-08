package config

import (
	"fmt"
	"os"
)

type Config struct {
	DBURL          string
	LogLevel       string
	IdentitySecret string
	BootstrapEmail string
	BootstrapPass  string
}

func Load() (*Config, error) {
	c := &Config{
		DBURL:          os.Getenv("OPENTRUSTY_DB_URL"),
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
	if c.DBURL == "" {
		return fmt.Errorf("OPENTRUSTY_DB_URL is required")
	}
	if c.IdentitySecret == "" {
		return fmt.Errorf("OPENTRUSTY_IDENTITY_SECRET is required")
	}
	return nil
}
