# ADR 013: Ciclo de vida lazy de las interfaces

- Estado: aceptada por indicación del usuario; implementación pendiente de validación gráfica.
- Fecha: 2026-10-31

## Contexto

La sesión medida tenía aproximadamente 844 MiB de PSS en Quickshell. El árbol construía paneles por monitor y todas las páginas de Ajustes aunque estuvieran ocultos. La medida no identifica una fuga ni atribuye memoria a cada componente. El usuario establece que las vistas ocultas, innecesarias y reconstruibles deben cargarse de forma lazy.

Se mantiene la separación de servicios y vistas y el contrato de bloqueo del ADR 0006. La búsqueda de Ajustes consulta las filas reales y los paneles deben terminar sus animaciones antes de destruirse.

## Decisión

Crear las vistas reconstruibles cuando se solicitan y destruirlas después de su cierre efectivo, en el monitor correspondiente. Conservar estado duradero, IPC y operaciones en sus servicios; retener temporalmente las vistas que contengan entrada sin guardar o resultados pendientes que no puedan reconstruirse.

## Consecuencias

Los componentes que se cargan bajo demanda deben preparar su primera apertura después de construir sus hijos. La geometría de un panel no debe ser sustituida por el tamaño de su Loader. Los efectos e imágenes auxiliares siguen el ciclo de vida de la vista que los necesita.

Ajustes carga otras páginas temporalmente al buscar, y las descarga al terminar si no tienen borradores. Las páginas nuevas deben declarar el estado que exige retención. El menor número de objetos residentes requiere comprobación en sesión y medición comparable de memoria, no solo lint.

Véase [Memoria y carga de interfaces](../memory.md) para la implementación y su validación pendiente.
