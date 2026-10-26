package release

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestChangelogKeepsUserFacingCommits(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/repos/migueel15/SendaDesktopManager/compare/v0.4.9...v0.5.0" {
			http.NotFound(w, r)
			return
		}
		w.Write([]byte(`{"commits":[
			{"commit":{"message":"feat(themes): exporta el tema a kitty\n\ncuerpo"}},
			{"commit":{"message":"Merge pull request #41 from x/y"}},
			{"commit":{"message":"fix: corrige el borrado"}},
			{"commit":{"message":"chore(deps): actualiza"}},
			{"commit":{"message":"perf(bar)!: reduce redibujados"}}]}`))
	}))
	defer srv.Close()

	changes, err := Changelog(context.Background(), srv.URL, "v0.4.9", "v0.5.0")
	if err != nil {
		t.Fatal(err)
	}
	want := []Change{{"feat", "themes", "exporta el tema a kitty"}, {"fix", "", "corrige el borrado"}, {"perf", "bar", "reduce redibujados"}}
	if len(changes) != len(want) {
		t.Fatalf("%+v", changes)
	}
	for i := range want {
		if changes[i] != want[i] {
			t.Fatalf("%d: %+v, want %+v", i, changes[i], want[i])
		}
	}
}

func TestChangelogRejectsInvalidTags(t *testing.T) {
	if _, err := Changelog(context.Background(), "http://127.0.0.1:1", "dev", "v0.5.0"); err == nil {
		t.Fatal("expected error")
	}
}
