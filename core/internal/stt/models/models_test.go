package models

import (
	"slices"
	"testing"

	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

func TestDefaultCatalogArtifact(t *testing.T) {
	catalog := Catalog()
	if len(catalog) == 0 {
		t.Fatal("empty catalog")
	}
	e := catalog[0]
	const archive = "sherpa-onnx-nemotron-3.5-asr-streaming-0.6b-560ms-int8-2026-06-11"
	if e.ID != stt.DefaultModelID || e.Archive != archive || e.Name == "" ||
		e.URL != "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/"+archive+".tar.bz2" ||
		e.SizeBytes != 475271763 || e.SHA256 != "c6bf5e0df765f9d5b43bc9e0536d4b4b3e7d40bdf5ecf13e45f134c51c05ae3a" ||
		e.License != "OpenMDW 1.1" || e.LicenseURL != "https://huggingface.co/nvidia/nemotron-3.5-asr-streaming-0.6b" || !e.LanguageOption {
		t.Fatalf("default artifact differs from spike t-01: %+v", e)
	}
	wantFiles := ModelFiles{Encoder: "encoder.int8.onnx", Decoder: "decoder.int8.onnx", Joiner: "joiner.int8.onnx", Tokens: "tokens.txt"}
	if e.Files != wantFiles || !slices.Contains(e.Languages, "es") {
		t.Fatalf("model capabilities = %+v", e)
	}
	catalog[0].Languages[0] = "changed"
	catalog[0].ID = "changed"
	if fresh := Catalog()[0]; fresh.ID != stt.DefaultModelID || fresh.Languages[0] != "es" {
		t.Fatal("catalog shares mutable data")
	}
}
