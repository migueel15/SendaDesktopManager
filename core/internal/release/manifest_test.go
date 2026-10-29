package release

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
)

func serveManifest(t *testing.T, path, body string) *httptest.Server {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != path {
			http.NotFound(w, r)
			return
		}
		w.Write([]byte(body))
	}))
	t.Cleanup(srv.Close)
	return srv
}

func TestLatestTagReadsStableManifest(t *testing.T) {
	srv := serveManifest(t, "/latest/download/latest.json", `{"tag":"v1.2.3","releases":[]}`)
	tag, err := LatestTagForChannel(context.Background(), srv.URL, false)
	if err != nil || tag != "v1.2.3" {
		t.Fatalf("LatestTagForChannel() = %q, %v", tag, err)
	}
}

func TestLatestTagReadsNightlyManifest(t *testing.T) {
	srv := serveManifest(t, "/download/nightly/latest.json", `{"tag":"nightly-20261023180000-abc1234"}`)
	tag, err := LatestTagForChannel(context.Background(), srv.URL, true)
	if err != nil || tag != "nightly-20261023180000-abc1234" {
		t.Fatalf("LatestTagForChannel() = %q, %v", tag, err)
	}
}

func TestLatestTagRejectsTagOfOtherChannel(t *testing.T) {
	srv := serveManifest(t, "/download/nightly/latest.json", `{"tag":"v1.2.3"}`)
	if _, err := LatestTagForChannel(context.Background(), srv.URL, true); err == nil {
		t.Fatal("nightly channel accepted a stable tag")
	}
}

func TestLatestTagRejectsInvalidTag(t *testing.T) {
	for _, tag := range []string{"1.2.3", "v1.2", "v1.2.3-beta", "v1.2.3/../x", ""} {
		srv := serveManifest(t, "/latest/download/latest.json", `{"tag":"`+tag+`"}`)
		if _, err := LatestTagForChannel(context.Background(), srv.URL, false); err == nil {
			t.Errorf("accepted tag %q", tag)
		}
	}
}

func TestLatestTagReportsHTTPError(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, "missing", http.StatusNotFound)
	}))
	defer srv.Close()
	if _, err := LatestTagForChannel(context.Background(), srv.URL, false); err == nil {
		t.Fatal("succeeded on HTTP 404")
	}
}

func TestChangesKeepsUserFacingCommitsNewerThanCurrent(t *testing.T) {
	m := Manifest{Tag: "v0.5.1", Releases: []ManifestRelease{
		{Tag: "v0.5.1", Commits: []string{"perf(bar)!: reduce redibujados", "chore(deps): actualiza"}},
		{Tag: "v0.5.0", Commits: []string{"fix: corrige el borrado", "Merge pull request #41 from x/y", "feat(themes): exporta el tema a kitty\n\ncuerpo"}},
		{Tag: "v0.4.9", Commits: []string{"feat: ya instalado"}},
	}}
	got := m.Changes("v0.4.9")
	want := []Change{{"feat", "themes", "exporta el tema a kitty"}, {"fix", "", "corrige el borrado"}, {"perf", "bar", "reduce redibujados"}}
	if len(got) != len(want) {
		t.Fatalf("%+v", got)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("%d: %+v, want %+v", i, got[i], want[i])
		}
	}
	if len(m.Changes("v0.5.1")) != 0 {
		t.Fatal("current release reported changes")
	}
}
