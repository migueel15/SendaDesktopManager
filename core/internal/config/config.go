// Package config reads Senda's KEY=VALUE settings file.
package config

import (
	"bufio"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"strconv"
	"strings"
)

// Load parses the settings file at path. A missing file is not an error: it
// returns an empty map so that every setting falls back to its default.
func Load(path string) (map[string]string, error) {
	values := map[string]string{}

	file, err := os.Open(path)
	if err != nil {
		if errors.Is(err, fs.ErrNotExist) {
			return values, nil
		}
		return nil, err
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for lineNumber := 1; scanner.Scan(); lineNumber++ {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		line = strings.TrimPrefix(line, "export ")
		key, value, ok := strings.Cut(line, "=")
		key = strings.TrimSpace(key)
		if !ok || key == "" {
			return nil, fmt.Errorf("%s:%d: expected KEY=VALUE", path, lineNumber)
		}
		values[key] = parseValue(value)
	}

	if err := scanner.Err(); err != nil {
		return nil, err
	}
	return values, nil
}

func parseValue(value string) string {
	value = strings.TrimSpace(value)
	if value == "" {
		return ""
	}

	if len(value) >= 2 && value[0] == '\'' && value[len(value)-1] == '\'' {
		return value[1 : len(value)-1]
	}

	if strings.HasPrefix(value, "\"") {
		if quoted, err := strconv.QuotedPrefix(value); err == nil {
			if unquoted, err := strconv.Unquote(quoted); err == nil {
				return unquoted
			}
		}
	}

	if commentIndex := strings.Index(value, " #"); commentIndex >= 0 {
		value = value[:commentIndex]
	}

	return strings.TrimSpace(value)
}
