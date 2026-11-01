# ADR 014: Postprocesamiento local conservador del dictado

- Estado: sustituida por el [ADR 016](adr-016-modelos-sin-streaming.md).
- Fecha: 2026-10-31

## Contexto

El [ADR 0004](0004-dictado-local-y-binds-de-hyprland.md) mantiene el reconocimiento en un proceso sherpa-onnx local. Se necesita mejorar la escritura española sin modificar los parciales ni reescribir el discurso. Los modelos de puntuación publicados por [sherpa-onnx](https://k2-fsa.github.io/sherpa/onnx/punctuation/pretrained_models.html) cubren inglés o chino/inglés, no español.

## Decisión

Añadir una fase opcional después de `Stream.Stop`, antes de emitir `final` y entregar. Usar Qwen3 1.7B GGUF cuantizado con `llama-completion` de llama.cpp, en CPU y modo offline, sin servidor ni dependencias Go/Python nuevas. La sesión limita la fase a ocho segundos, admite cancelación y entrega el original ante fallo, pánico o rechazo. El runtime y el GGUF se preparan explícitamente; no hay descargas durante el dictado.

La salida generativa es solo una propuesta. Un filtro determinista conserva la secuencia léxica y admite únicamente puntuación española equilibrada, cambios de caja/tildes de un vocabulario común y correcciones enumeradas. Las palabras desconocidas deben permanecer idénticas; con números o marcadores de código se omite toda la corrección. Se conservan repeticiones, sonidos de vacilación y palabras sueltas cuya intención no puede establecerse a partir del texto. El original se expone como `originalText` y se conserva en memoria en la shell.

## Consecuencias

No se añade latencia ni carga de modelo a los parciales. Al finalizar se carga y libera el modelo una vez por dictado; no hay otro proceso residente. El tiempo máximo de corrección incluye esa carga. Se evita introducir un gestor nuevo de modelos o servicios locales.

El filtro sacrifica cobertura: no corrige todos los errores ortográficos, no elimina posibles repeticiones accidentales ni muletillas, y mantiene un solo párrafo. Una propuesta mixta con un cambio inadmisible se descarta entera. No garantiza equivalencia semántica: la puntuación o una tilde también pueden cambiar el sentido. La calidad y latencia de Qwen3 deben validarse con dictados reales antes de recomendar su activación.

Alternativas: reutilizar la puntuación de sherpa no cubre español; un modelo multilingüe especializado exigiría otro adaptador y no cubriría por sí solo ortografía y separación. Qwen3 ofrece una integración opcional mediante un ejecutable local, pero no justifica confiar sin controles en su salida.
