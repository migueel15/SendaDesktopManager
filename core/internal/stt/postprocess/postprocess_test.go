package postprocess

import (
	"context"
	"errors"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// These are proposed model outputs, not claims about model quality. Each pair
// documents exactly which edits the deterministic guard may accept.
func TestSpanishFidelity(t *testing.T) {
	for _, tc := range []struct {
		name, input, output string
		accept              bool
	}{
		{"pregunta", "hola como estas", "Hola, ¿cómo estás?", true},
		{"exclamacion", "que bien", "¡Qué bien!", true},
		{"apertura-obligatoria", "como estas", "Cómo estás?", false},
		{"tildes-mayusculas", "tambien estoy aqui", "También estoy aquí.", true},
		{"ortografia", "holaa nesecito ayuda grasias", "Hola necesito ayuda gracias.", true},
		{"puntuacion-existente", "hola, que tal", "Hola qué tal.", false},
		{"separacion-evidente", "enton ces tam bien", "Entonces también.", true},
		{"union-ambigua", "por que vas", "Porque vas.", false},
		{"coloquial", "pues vale tio", "Pues vale, tio.", true},
		{"formalizacion", "pues vale tio", "De acuerdo, amigo.", false},
		{"repeticion-ambigua", "porque porque quiero", "Porque quiero.", false},
		{"repeticion-enfasis", "no no no", "No.", false},
		{"repeticion-conservada", "que que bien", "Que, que bien.", true},
		{"vacilacion-ambigua", "mmm no", "No.", false},
		{"palabra-suelta", "yo patata voy", "Yo voy.", false},
		{"tecnico", "uso sherpa y Qwen", "Uso sherpa y Qwen.", false},
		{"tecnico-conservado", "uso sherpa y Qwen", "uso sherpa y Qwen.", true},
		{"nombre", "hablo con miguel", "Hablo con Miguel.", false},
		{"identificador", "usa foo_bar", "usa foo bar", false},
		{"codigo", "ejecuta fmt.Println(42)", "Ejecuta fmt.Println(42).", false},
		{"numero", "tengo 25 euros", "Tengo 26 euros.", false},
		{"orden", "yo voy y tu vienes", "Tú vienes y yo voy.", false},
		{"informacion", "yo no voy", "Yo voy.", false},
		{"ampliacion", "yo voy", "Yo voy mañana.", false},
		{"parrafos", "hola que tal", "Hola.\n¿Qué tal?", false},
		{"tilde-inventada", "hola", "Holá.", false},
		{"tilde-existente", "sí", "Si.", false},
		{"mayusculas-enfasis", "hola", "HOLA.", false},
		{"explicacion", "hola", "Texto corregido: Hola.", false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			if got := Accept(tc.input, tc.output); got != tc.accept {
				t.Fatalf("%q -> %q: accepted=%v", tc.input, tc.output, got)
			}
		})
	}
}

func TestProcessFallbackAndLocalInvocation(t *testing.T) {
	model := filepath.Join(t.TempDir(), "model.gguf")
	if err := os.WriteFile(model, []byte("fake for injected runner"), 0600); err != nil {
		t.Fatal(err)
	}
	for _, tc := range []struct {
		name, output string
		err          error
		want         string
	}{
		{"corrected", "Hola, ¿cómo estás?", nil, "Hola, ¿cómo estás?"},
		{"rewrite", "Saludos, ¿qué tal?", nil, "hola como estas"},
		{"unavailable", "", errors.New("missing runtime"), "hola como estas"},
		{"truncated", "Hola", nil, "hola como estas"},
		{"empty", "", nil, "hola como estas"},
		{"oversized", strings.Repeat("a", maxOutput+1), nil, "hola como estas"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			p := Processor{Model: model, Run: func(ctx context.Context, input io.Reader, args ...string) ([]byte, error) {
				prompt, _ := io.ReadAll(input)
				joined := strings.Join(args, " ")
				if !strings.Contains(string(prompt), "hola como estas") || strings.Contains(joined, "hola") || !strings.Contains(joined, "--offline") || !strings.Contains(joined, "/dev/stdin") {
					t.Fatal("unsafe invocation", joined)
				}
				if _, ok := ctx.Deadline(); !ok {
					t.Fatal("no deadline")
				}
				return []byte(tc.output), tc.err
			}}
			got, err := p.Process(context.Background(), "hola como estas")
			if err != nil || got != tc.want {
				t.Fatalf("got %q, %v", got, err)
			}
		})
	}
	p := Processor{Model: model, Run: func(context.Context, io.Reader, ...string) ([]byte, error) {
		t.Fatal("must skip protected/oversized input")
		return nil, nil
	}}
	for _, input := range []string{"", "fmt.Println(42)", "son 25 euros", strings.Repeat("x", maxInput+1)} {
		got, _ := p.Process(context.Background(), input)
		if got != input {
			t.Fatal("changed skipped input")
		}
	}
	p.Model = filepath.Join(t.TempDir(), "missing.gguf")
	if got, _ := p.Process(context.Background(), "hola"); got != "hola" {
		t.Fatal(got)
	}
	p.Model = model
	p.Run = func(ctx context.Context, _ io.Reader, _ ...string) ([]byte, error) {
		<-ctx.Done()
		return []byte("Hola."), nil
	}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if got, _ := p.Process(ctx, "hola"); got != "hola" {
		t.Fatal(got)
	}
}

func TestBoundedOutput(t *testing.T) {
	var b limitedBuffer
	if _, err := b.Write(make([]byte, maxOutput+1)); err == nil || b.Len() != 0 {
		t.Fatal("unbounded output")
	}
}

func TestMissingRuntimeFallsBack(t *testing.T) {
	model := filepath.Join(t.TempDir(), "model.gguf")
	if err := os.WriteFile(model, []byte("fixture"), 0600); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", t.TempDir())
	got, err := (Processor{Model: model}).Process(context.Background(), "hola")
	if err != nil || got != "hola" {
		t.Fatalf("%q, %v", got, err)
	}
}

func TestLocalProcessEnvironmentAndStdin(t *testing.T) {
	dir := t.TempDir()
	// No real model is loaded. This fixture tests the actual exec adapter.
	fixture := "#!/bin/sh\n[ -z \"$LLAMA_ARG_RPC$LLAMA_ARG_MODEL_URL$GGML_RPC_SERVERS\" ] || exit 1\nread -r line\n[ \"$line\" = private-input ] || exit 2\nprintf 'Hola.'\n"
	if err := os.WriteFile(filepath.Join(dir, "llama-completion"), []byte(fixture), 0700); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", dir)
	t.Setenv("LLAMA_ARG_RPC", "remote")
	t.Setenv("LLAMA_ARG_MODEL_URL", "https://example.org/model")
	t.Setenv("GGML_RPC_SERVERS", "remote")
	out, err := localRun(context.Background(), strings.NewReader("private-input\n"), "--offline")
	if err != nil || string(out) != "Hola." {
		t.Fatalf("%q, %v", out, err)
	}
}
