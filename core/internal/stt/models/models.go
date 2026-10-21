// Package models provides the verified catalog and manages installed models.
package models

import (
	"context"
	"errors"
	"net/http"

	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
)

type Entry struct {
	ID, Name, Archive, URL, SHA256, License, LicenseURL string
	SizeBytes                                           int64
	Languages                                           []string
	Files                                               ModelFiles
	LanguageOption                                      bool
}
type ModelFiles struct{ Encoder, Decoder, Joiner, Tokens string }
type Status struct {
	Entry
	Installed, Active bool
}

// Catalog contains the artifact verified by spike t-01. Spanish was tested;
// the multilingual model also supports other languages.
func Catalog() []Entry {
	const archive = "sherpa-onnx-nemotron-3.5-asr-streaming-0.6b-560ms-int8-2026-06-11"
	return []Entry{{
		ID: stt.DefaultModelID, Name: "Nemotron 3.5 Streaming 0.6B INT8", Archive: archive,
		URL:       "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/" + archive + ".tar.bz2",
		SHA256:    "c6bf5e0df765f9d5b43bc9e0536d4b4b3e7d40bdf5ecf13e45f134c51c05ae3a",
		SizeBytes: 475271763, License: "OpenMDW 1.1",
		LicenseURL: "https://huggingface.co/nvidia/nemotron-3.5-asr-streaming-0.6b",
		Languages:  []string{"es"}, LanguageOption: true,
		Files: ModelFiles{Encoder: "encoder.int8.onnx", Decoder: "decoder.int8.onnx", Joiner: "joiner.int8.onnx", Tokens: "tokens.txt"},
	}}
}

type Store struct {
	Dir     string
	Catalog []Entry
	Client  *http.Client
}

func NewStore(dir string) *Store {
	return &Store{Dir: dir, Catalog: Catalog(), Client: http.DefaultClient}
}
func (*Store) List(string) ([]Status, error) { return nil, stt.ErrNotImplemented }
func (*Store) Install(context.Context, string, func(int64, int64)) error {
	return stt.ErrNotImplemented
}
func (*Store) Remove(string) error { return stt.ErrNotImplemented }

// Installed and ModelDir return zero values until model storage is implemented.
func (*Store) Installed(string) bool  { return false }
func (*Store) ModelDir(string) string { return "" }

var ErrUnknownModel = errors.New("modelo desconocido")
var ErrChecksum = errors.New("la suma de comprobación del modelo no coincide")
