package postprocess

import (
	"archive/tar"
	"bytes"
	"compress/gzip"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

func runtimeArchive(t *testing.T, extra ...tar.Header) []byte {
	t.Helper()
	var b bytes.Buffer
	gz := gzip.NewWriter(&b)
	tw := tar.NewWriter(gz)
	data := "#!/bin/sh\nexit 0\n"
	entries := []tar.Header{{Name: "fixture", Typeflag: tar.TypeDir, Mode: 0700},
		{Name: "fixture/llama-completion", Typeflag: tar.TypeReg, Mode: 0700, Size: int64(len(data))},
		{Name: "fixture/libggml.so.0", Typeflag: tar.TypeReg, Mode: 0600, Size: 0},
		{Name: "fixture/libggml.so", Typeflag: tar.TypeSymlink, Linkname: "libggml.so.0"}}
	entries = append(entries, extra...)
	for _, h := range entries {
		if err := tw.WriteHeader(&h); err != nil {
			t.Fatal(err)
		}
		if h.Size > 0 {
			if _, err := tw.Write([]byte(data)); err != nil {
				t.Fatal(err)
			}
		}
	}
	if err := tw.Close(); err != nil {
		t.Fatal(err)
	}
	if err := gz.Close(); err != nil {
		t.Fatal(err)
	}
	return b.Bytes()
}

func testArtifact(url string, data []byte) Artifact {
	hash := sha256.Sum256(data)
	return Artifact{URL: url, Size: int64(len(data)), SHA256: hex.EncodeToString(hash[:])}
}

func fixtureStore(t *testing.T) (*Store, *atomic.Int32) {
	t.Helper()
	archive, model := runtimeArchive(t), []byte("GGUFfixture-model")
	var requests atomic.Int32
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requests.Add(1)
		switch r.URL.Path {
		case "/runtime":
			w.Write(archive)
		case "/model":
			w.Write(model)
		default:
			http.NotFound(w, r)
		}
	}))
	t.Cleanup(server.Close)
	s := NewStore(filepath.Join(t.TempDir(), "postprocess"))
	s.Supported = true
	s.ArchiveRoot = "fixture"
	s.Client = server.Client()
	s.Runtime, s.Model = testArtifact(server.URL+"/runtime", archive), testArtifact(server.URL+"/model", model)
	return s, &requests
}

func TestManagedInstallAndReadiness(t *testing.T) {
	s, requests := fixtureStore(t)
	if s.Status(context.Background()).Ready {
		t.Fatal("missing bundle is ready")
	}
	var phases []string
	var last int64
	err := s.Install(context.Background(), func(phase string, done, total int64) {
		if done < last || done > total {
			t.Errorf("invalid progress %d/%d after %d", done, total, last)
		}
		last = done
		phases = append(phases, phase)
	})
	if err != nil {
		t.Fatal(err)
	}
	if !s.Status(context.Background()).Ready || last != s.Runtime.Size+s.Model.Size || len(phases) < 2 {
		t.Fatal("bundle/progress not ready", phases, last)
	}
	if err := s.Install(context.Background(), nil); err != nil {
		t.Fatal(err)
	}
	if requests.Load() != 2 {
		t.Fatal("redownloaded ready bundle", requests.Load())
	}
	if _, err := os.Stat(filepath.Join(s.Dir, "runtime.tar.gz")); !os.IsNotExist(err) {
		t.Fatal("kept archive")
	}
	if err := os.Remove(s.ModelPath()); err != nil {
		t.Fatal(err)
	}
	if s.Status(context.Background()).Ready {
		t.Fatal("missing model still ready")
	}
}

func TestInstallFailuresPreservePreviousBundle(t *testing.T) {
	for _, mode := range []string{"hash", "size", "http", "runtime", "cancelled", "unsupported"} {
		t.Run(mode, func(t *testing.T) {
			s, _ := fixtureStore(t)
			if err := os.MkdirAll(s.Dir, 0700); err != nil {
				t.Fatal(err)
			}
			sentinel := filepath.Join(s.Dir, "previous")
			if err := os.WriteFile(sentinel, []byte("preserve"), 0600); err != nil {
				t.Fatal(err)
			}
			ctx, cancel := context.WithCancel(context.Background())
			defer cancel()
			switch mode {
			case "hash":
				s.Model.SHA256 = strings.Repeat("0", 64)
			case "size":
				s.Model.Size--
			case "http":
				s.Model.URL += "-missing"
			case "runtime":
				s.CheckRuntime = func(context.Context, string) error { return fmt.Errorf("not executable") }
			case "cancelled":
				cancel()
			case "unsupported":
				s.Supported = false
			}
			if err := s.Install(ctx, nil); err == nil {
				t.Fatal("expected error")
			}
			if b, err := os.ReadFile(sentinel); err != nil || string(b) != "preserve" {
				t.Fatal("lost previous installation", err)
			}
			entries, err := os.ReadDir(filepath.Dir(s.Dir))
			if err != nil {
				t.Fatal(err)
			}
			if len(entries) != 1 {
				t.Fatal("left staging files", entries)
			}
		})
	}
}

func TestCancelDownloadAndRetry(t *testing.T) {
	s, _ := fixtureStore(t)
	ctx, cancel := context.WithCancel(context.Background())
	err := s.Install(ctx, func(phase string, done, total int64) {
		if phase == "Descargando modelo" {
			cancel()
		}
	})
	if err == nil {
		t.Fatal("cancelled install succeeded")
	}
	if s.Status(context.Background()).Ready {
		t.Fatal("partial install ready")
	}
	if err := s.Install(context.Background(), nil); err != nil {
		t.Fatal("retry failed", err)
	}
	if !s.Status(context.Background()).Ready {
		t.Fatal("retry not ready")
	}
	if err := os.Remove(s.Binary()); err != nil {
		t.Fatal(err)
	}
	if s.Status(context.Background()).Ready {
		t.Fatal("missing runtime ready")
	}
}

func TestRuntimeArchiveRejectsUnsafePathsAndLinks(t *testing.T) {
	for _, h := range []tar.Header{
		{Name: "../escape", Typeflag: tar.TypeReg},
		{Name: "/escape", Typeflag: tar.TypeReg},
		{Name: "fixture/../escape", Typeflag: tar.TypeReg},
		{Name: "fixture/sub/libllama.so", Typeflag: tar.TypeReg},
		{Name: "fixture/libllama.so", Typeflag: tar.TypeSymlink, Linkname: "../../escape"},
		{Name: "fixture/libllama.so", Typeflag: tar.TypeLink, Linkname: "libggml.so.0"},
		{Name: "fixture/libllama.so", Typeflag: tar.TypeSymlink, Linkname: "libllama.so"},
	} {
		t.Run(strings.ReplaceAll(h.Name, "/", "-"), func(t *testing.T) {
			dir := t.TempDir()
			file := filepath.Join(dir, "runtime.tar.gz")
			if err := os.WriteFile(file, runtimeArchive(t, h), 0600); err != nil {
				t.Fatal(err)
			}
			if err := extractRuntime(context.Background(), file, filepath.Join(dir, "runtime"), "fixture"); err == nil {
				t.Fatal("accepted unsafe archive", h)
			}
		})
	}
}

// Opt-in: the validation harness prepares a real bundle in a temporary XDG
// tree. Normal tests never download models or touch the user's installation.
func TestPreparedBundleRealInference(t *testing.T) {
	dir := os.Getenv("SENDA_TEST_POSTPROCESS_BUNDLE")
	if dir == "" {
		t.Skip("no temporary real bundle supplied")
	}
	s := NewStore(dir)
	if !s.Status(context.Background()).Ready {
		t.Fatal("real bundle not ready")
	}
	var raw []byte
	var runErr error
	p := Processor{Model: s.ModelPath(), Run: func(ctx context.Context, in io.Reader, args ...string) ([]byte, error) {
		raw, runErr = executeLocal(ctx, in, s.Binary(), args...)
		return raw, runErr
	}}
	before := time.Now()
	got, err := p.Process(context.Background(), "hola como estas")
	if err != nil || runErr != nil || got == "hola como estas" || !Accept("hola como estas", got) {
		t.Fatalf("real inference: result=%q raw=%q error=%v runtime=%v elapsed=%s", got, raw, err, runErr, time.Since(before))
	}
	t.Logf("real inference: %q -> %q in %s", "hola como estas", got, time.Since(before))
}

// Opt-in coverage for roughly ninety seconds of continuous dictation. Report
// fallback explicitly: preserving the original is safe, but is not a correction.
func TestPreparedBundleLongDictation(t *testing.T) {
	dir := os.Getenv("SENDA_TEST_POSTPROCESS_BUNDLE")
	if dir == "" {
		t.Skip("no temporary real bundle supplied")
	}
	s := NewStore(dir)
	if !s.Status(context.Background()).Ready {
		t.Fatal("real bundle not ready")
	}
	cases := []struct{ name, input string }{
		{"planes", `hoy quiero organizar un poco lo que tengo pendiente porque esta semana he ido dejando varias cosas para despues y ahora me cuesta saber por donde empezar primero voy a revisar los mensajes que llegaron ayer y luego quiero preparar una lista con las tareas que de verdad necesitan una respuesta no quiero pasar toda la mañana contestando cosas pequeñas y acabar el dia con lo importante sin hacer tambien tengo que llamar para confirmar la visita de mañana aunque todavia no se si me viene mejor ir por la mañana o despues de comer si puedo terminar pronto me gustaria salir a dar un paseo y comprar algo para la cena pero antes necesito dejar la cocina recogida porque ayer sali con prisa y se quedo todo a medias por la tarde quiero dedicar un rato a leer y otro a preparar la ropa de la semana que viene parece una tonteria pero cuando lo dejo hecho estoy mucho mas tranquilo y no tengo que pensar en ello nada mas levantarme en fin la idea es hacerlo con calma sin intentar resolverlo todo de golpe y dejar un poco de tiempo libre por si aparece algun imprevisto`},
		{"preguntas", `queria comentarte una cosa sobre la reunion de mañana porque no tengo claro como vamos a organizar la conversacion vamos a empezar repasando lo que hicimos la semana pasada o prefieres que vayamos directamente a lo que queda pendiente a mi me parece bien cualquiera de las opciones pero estaria bien decidirlo antes para que todo el mundo pueda preparar lo que necesita tambien queria saber quien va a tomar notas porque la ultima vez hablamos de muchas cosas y despues cada uno recordaba una version un poco distinta no hace falta escribir cada palabra pero si estaria bien dejar claras las decisiones y lo que tiene que hacer cada persona despues cuando terminemos podemos mandar un mensaje corto con lo que hemos acordado y asi evitamos volver a discutir lo mismo dentro de unos dias por cierto sabes si vamos a tener tiempo para las preguntas del final me gustaria preguntar como vamos a repartir el trabajo cuando alguien este de vacaciones porque ahora mismo hay varias tareas que dependen siempre de la misma persona y creo que nos vendria bien aprender a hacerlas entre todos dime que te parece y lo dejamos preparado esta tarde`},
		{"coloquial", `pues mira yo creo que al final lo que nos pasa es que queremos hacer demasiadas cosas a la vez y claro luego nos agobiamos porque vemos que no llegamos a todo ayer por ejemplo sali de casa pensando que iba a hacer la compra recoger un paquete pasar por casa de mi hermano y volver con tiempo para cocinar pero entre una cosa y otra se me fue la mañana y cuando llegue ya no tenia ganas de hacer nada entonces entonces me sente un rato y dije bueno vamos a parar un momento porque asi no tiene mucho sentido tampoco pasa nada por dejar algo para mañana si no es urgente lo que quiero es encontrar una forma de organizarme que pueda mantener de verdad sin estar mirando el reloj todo el dia y sin sentir que voy siempre tarde tambien me gustaria descansar mejor porque cuando duermo poco cualquier cosa se me hace mucho mas pesada no se igual lo primero es acostarme antes y preparar por la noche lo que voy a necesitar al dia siguiente pero bueno voy a probar poco a poco y ya vere que cosas me funcionan y cuales tengo que cambiar`},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			var raw []byte
			var runErr error
			p := Processor{Model: s.ModelPath(), Run: func(ctx context.Context, in io.Reader, args ...string) ([]byte, error) {
				raw, runErr = executeLocal(ctx, in, s.Binary(), args...)
				return raw, runErr
			}}
			before := time.Now()
			got, err := p.Process(context.Background(), tc.input)
			t.Logf("words=%d bytes=%d elapsed=%s corrected=%v runtime=%v error=%v\nraw=%q\nresult=%q", len(strings.Fields(tc.input)), len(tc.input), time.Since(before), got != tc.input, runErr, err, raw, got)
			if got == tc.input {
				t.Error("original preserved; no correction delivered")
			} else if !Accept(tc.input, got) {
				t.Error("correction violated fidelity guard")
			}
		})
	}
}
