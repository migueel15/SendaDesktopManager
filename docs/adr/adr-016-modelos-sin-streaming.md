# ADR 016: Modelos sin streaming en lugar de corrección posterior

- Estado: aceptada
- Fecha: 2026-11-01

## Contexto

La corrección con Qwen3 de los ADR 014 y 015 añadía otro modelo y un filtro que descartaba muchas propuestas. La calidad del texto puede venir directamente de un modelo que transcribe el audio completo.

## Decisión

Eliminar la corrección y su descarga. El catálogo distingue modelos con y sin streaming, y añade Parakeet TDT 0.6B V3 INT8 mediante `OfflineRecognizer` de sherpa-onnx. Los modelos sin streaming no emiten parciales: guardan el audio en memoria y lo decodifican al parar. Ningún modelo se instala automáticamente.

## Consecuencias

Con esos modelos no hay texto en vivo, y la espera final crece con la duración del dictado. No hay segunda pasada con un modelo de streaming.
