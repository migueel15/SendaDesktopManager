package release

import (
	"context"
	"fmt"
	"regexp"
	"strings"
)

const comparePath = "/repos/migueel15/SendaDesktopManager/compare/"

// Change is one user-facing commit between two releases.
type Change struct {
	Type    string `json:"type"`
	Scope   string `json:"scope"`
	Summary string `json:"summary"`
}

// changeTypes lists the Conventional Commit types shown to users. Chores,
// tests, docs and merges are left out.
var changeTypes = map[string]bool{"feat": true, "fix": true, "perf": true}

var subjectPattern = regexp.MustCompile(`^([a-z]+)(?:\(([^)]*)\))?!?: (.+)$`)

// Changelog returns the feat, fix and perf commits from base (exclusive) to
// head, oldest first, using GitHub's compare API. Both are release tags.
func Changelog(ctx context.Context, baseURL, base, head string) ([]Change, error) {
	for _, tag := range []string{base, head} {
		if !tagPattern.MatchString(tag) && !nightlyTagPattern.MatchString(tag) {
			return nil, fmt.Errorf("etiqueta de versión no válida: %q", tag)
		}
	}
	var compare struct {
		Commits []struct {
			Commit struct {
				Message string `json:"message"`
			} `json:"commit"`
		} `json:"commits"`
	}
	if err := getJSON(ctx, baseURL+comparePath+base+"..."+head, &compare); err != nil {
		return nil, err
	}
	changes := []Change{}
	for _, commit := range compare.Commits {
		subject, _, _ := strings.Cut(commit.Commit.Message, "\n")
		match := subjectPattern.FindStringSubmatch(strings.TrimSpace(subject))
		if match == nil || !changeTypes[match[1]] {
			continue
		}
		changes = append(changes, Change{Type: match[1], Scope: match[2], Summary: match[3]})
	}
	return changes, nil
}
