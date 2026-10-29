package release

import (
	"context"
	"fmt"
	"regexp"
	"strings"
)

// ManifestAsset is the file each release publishes with the latest release of
// its channel and the commits of the recent releases. It is read from the
// release download URLs, which are not subject to the GitHub API rate limit.
const ManifestAsset = "latest.json"

// Manifest is the content of ManifestAsset.
type Manifest struct {
	Tag string `json:"tag"`
	// Releases lists the recent releases of the channel, newest first.
	Releases []ManifestRelease `json:"releases"`
}

// ManifestRelease holds the commit subjects a release added over the previous one.
type ManifestRelease struct {
	Tag     string   `json:"tag"`
	Commits []string `json:"commits"`
}

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

// ManifestURL returns where the manifest of a channel lives under releasesURL
// (https://github.com/<owner>/<repo>/releases in production). Stable builds
// read it from the latest stable release; nightly builds from the release
// tagged "nightly", which the nightly workflow updates on every build.
func ManifestURL(releasesURL string, nightly bool) string {
	if nightly {
		return releasesURL + "/download/nightly/" + ManifestAsset
	}
	return releasesURL + "/latest/download/" + ManifestAsset
}

// FetchManifest downloads the manifest of a channel and validates its tag.
func FetchManifest(ctx context.Context, releasesURL string, nightly bool) (Manifest, error) {
	var manifest Manifest
	if err := getJSON(ctx, ManifestURL(releasesURL, nightly), &manifest); err != nil {
		return Manifest{}, err
	}
	pattern := tagPattern
	if nightly {
		pattern = nightlyTagPattern
	}
	if !pattern.MatchString(manifest.Tag) {
		return Manifest{}, fmt.Errorf("etiqueta de versión no válida: %q", manifest.Tag)
	}
	return manifest, nil
}

// LatestTagForChannel returns the newest release tag of the given channel.
func LatestTagForChannel(ctx context.Context, releasesURL string, nightly bool) (string, error) {
	manifest, err := FetchManifest(ctx, releasesURL, nightly)
	if err != nil {
		return "", err
	}
	return manifest.Tag, nil
}

// Changes returns the feat, fix and perf commits of the releases newer than
// current, oldest first. When current is no longer in the manifest, every
// listed release is included.
func (m Manifest) Changes(current string) []Change {
	var newer []ManifestRelease
	for _, r := range m.Releases {
		if r.Tag == current {
			break
		}
		newer = append(newer, r)
	}
	changes := []Change{}
	for i := len(newer) - 1; i >= 0; i-- {
		for j := len(newer[i].Commits) - 1; j >= 0; j-- {
			subject, _, _ := strings.Cut(newer[i].Commits[j], "\n")
			match := subjectPattern.FindStringSubmatch(strings.TrimSpace(subject))
			if match == nil || !changeTypes[match[1]] {
				continue
			}
			changes = append(changes, Change{Type: match[1], Scope: match[2], Summary: match[3]})
		}
	}
	return changes
}
