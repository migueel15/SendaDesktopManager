package stt

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

const ManifestFile = "manifest.json"

// Manifest names the files relative to the installed model directory.
type Manifest struct {
	ID                               string `json:"id"`
	Kind                             string `json:"kind"` // "transducer"
	Encoder, Decoder, Joiner, Tokens string
	LanguageOption                   bool `json:"languageOption"`
}

func ReadManifest(dir string) (Manifest, error) {
	var m Manifest
	data, err := os.ReadFile(filepath.Join(dir, ManifestFile))
	if err != nil {
		return m, fmt.Errorf("read STT manifest: %w", err)
	}
	if err := json.Unmarshal(data, &m); err != nil {
		return Manifest{}, fmt.Errorf("decode STT manifest: %w", err)
	}
	return m, nil
}

func WriteManifest(dir string, m Manifest) error {
	data, err := json.MarshalIndent(m, "", "  ")
	if err != nil {
		return err
	}
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return err
	}
	temp, err := os.CreateTemp(dir, ".manifest-*")
	if err != nil {
		return err
	}
	defer os.Remove(temp.Name())
	if _, err := temp.Write(append(data, '\n')); err != nil {
		temp.Close()
		return err
	}
	if err := temp.Close(); err != nil {
		return err
	}
	return os.Rename(temp.Name(), filepath.Join(dir, ManifestFile))
}
