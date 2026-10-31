package main

import (
	"bytes"
	"context"
	"encoding/json"
	"path/filepath"
	"strings"
	"testing"

	"github.com/migueel15/SendaDesktopManager/core/internal/stt"
	"github.com/migueel15/SendaDesktopManager/core/internal/stt/postprocess"
)

func TestPostprocessConfig(t *testing.T) {
	for _, input := range []string{
		`{"SENDA_STT_POSTPROCESS":"true","SENDA_STT_POSTPROCESS_MODEL":"/tmp/local model.gguf"}`,
		`{"SENDA_STT_POSTPROCESS":"false","SENDA_STT_POSTPROCESS_MODEL":""}`,
	} {
		values, err := readChanges(strings.NewReader(input))
		if err != nil {
			t.Fatal(err)
		}
		s := stt.LoadSettings(values)
		if s.Postprocess != (values[stt.KeyPostprocess] == "true") || s.PostprocessModel != values[stt.KeyPostprocessModel] {
			t.Fatal(s)
		}
	}
	for _, input := range []string{
		`{"SENDA_STT_POSTPROCESS":"yes"}`,
		`{"SENDA_STT_POSTPROCESS_MODEL":"https://example.org/model.gguf"}`,
		`{"SENDA_STT_POSTPROCESS_MODEL":"relative.gguf"}`,
		`{"SENDA_STT_POSTPROCESS_MODEL":"/tmp/model.onnx"}`,
		`{"SENDA_STT_POSTPROCESS_MODEL":"/tmp/model\n.gguf"}`,
	} {
		if _, err := readChanges(strings.NewReader(input)); err == nil {
			t.Fatal("accepted", input)
		}
	}
}

func TestPostprocessStatusAndCancelledInstall(t *testing.T) {
	store := postprocess.NewStore(filepath.Join(t.TempDir(), "postprocess"))
	cmd := newSTTPostprocessCmd(func() *postprocess.Store { return store })
	cmd.SetArgs([]string{"status", "--json"})
	var out bytes.Buffer
	cmd.SetOut(&out)
	if err := cmd.Execute(); err != nil {
		t.Fatal(err)
	}
	var status postprocess.InstallStatus
	if err := json.Unmarshal(out.Bytes(), &status); err != nil || status.Ready || status.SizeBytes == 0 {
		t.Fatal(out.String(), err)
	}
	cmd = newSTTPostprocessCmd(func() *postprocess.Store { return store })
	cmd.SetArgs([]string{"install"})
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	cmd.SetContext(ctx)
	if err := cmd.Execute(); err == nil {
		t.Fatal("cancelled install succeeded")
	}
}
