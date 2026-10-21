// Package models provides the verified catalog and manages installed models.
package models

import (
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
	},
		{ID: "nemotron-speech-streaming-en-0.6b-int8", Name: "Nemotron Speech Streaming EN 0.6B INT8", Archive: "sherpa-onnx-nemotron-speech-streaming-en-0.6b-560ms-int8-2026-04-25",
			URL: "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-nemotron-speech-streaming-en-0.6b-560ms-int8-2026-04-25.tar.bz2", SHA256: "78e2b79fcf7271553a74402a76b771b09ea40117a39566a79f52235b23db6358", SizeBytes: 463945051,
			License: "NVIDIA Open Model License", LicenseURL: "https://huggingface.co/nvidia/nemotron-speech-streaming-en-0.6b", Languages: []string{"en"},
			Files: ModelFiles{Encoder: "encoder.int8.onnx", Decoder: "decoder.int8.onnx", Joiner: "joiner.int8.onnx", Tokens: "tokens.txt"}},
		{ID: "zipformer-en-20m-int8", Name: "Streaming Zipformer EN 20M INT8", Archive: "sherpa-onnx-streaming-zipformer-en-20M-2023-02-17",
			URL: "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-streaming-zipformer-en-20M-2023-02-17.tar.bz2", SHA256: "9c559283e8498d3fe95913c79ca1cb454bb26281ac2b102b41306c7d752765d9", SizeBytes: 127887156,
			License: "Apache 2.0", LicenseURL: "https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-en-20M-2023-02-17", Languages: []string{"en"},
			Files: ModelFiles{Encoder: "encoder-epoch-99-avg-1.int8.onnx", Decoder: "decoder-epoch-99-avg-1.int8.onnx", Joiner: "joiner-epoch-99-avg-1.int8.onnx", Tokens: "tokens.txt"}},
		{ID: "zipformer-zh-en-int8", Name: "Streaming Zipformer ZH/EN INT8", Archive: "sherpa-onnx-streaming-zipformer-bilingual-zh-en-2023-02-20",
			URL: "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-streaming-zipformer-bilingual-zh-en-2023-02-20.tar.bz2", SHA256: "27ffbd9ee24ad186d99acc2f6354d7992b27bcab490812510665fa8f9389c5f8", SizeBytes: 511274346,
			License: "Apache 2.0", LicenseURL: "https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-bilingual-zh-en-2023-02-20", Languages: []string{"zh", "en"},
			Files: ModelFiles{Encoder: "encoder-epoch-99-avg-1.int8.onnx", Decoder: "decoder-epoch-99-avg-1.int8.onnx", Joiner: "joiner-epoch-99-avg-1.int8.onnx", Tokens: "tokens.txt"}},
	}
}

type Store struct {
	Dir     string
	Catalog []Entry
	Client  *http.Client
}

func NewStore(dir string) *Store {
	return &Store{Dir: dir, Catalog: Catalog(), Client: http.DefaultClient}
}

var ErrUnknownModel = errors.New("modelo desconocido")
var ErrChecksum = errors.New("la suma de comprobación del modelo no coincide")
