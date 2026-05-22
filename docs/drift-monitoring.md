# Drift Monitoring

## Alcance

Esta PoC separa dos tipos de monitoreo:

- Monitoreo tecnico: disponibilidad, latencia, errores HTTP, CPU y memoria.
- Monitoreo de modelo: cambios en distribucion de features y degradacion de
  calidad.

## Datos monitoreados

No se registra el payload completo de inferencia. Para reducir riesgo operativo,
solo se registra un resumen:

- `tenure`
- `monthly_charges`
- `support_tickets`

## Metricas iniciales

| Metrica | Uso | Umbral inicial |
| --- | --- | --- |
| Cambio de contrato de features | Detectar payload incompatible | cualquier cambio |
| Cambio relativo de media por feature | Detectar drift simple | `>= 0.25` |
| Cambio relativo de desviacion estandar por feature | Detectar dispersion distinta | `>= 0.50` |

## Flujo

1. Calcular baseline desde datos de entrenamiento.
2. Guardar baseline como JSON.
3. Agregar resumenes de inferencia a JSONL.
4. Comparar inferencia reciente contra baseline.
5. Escalar a alertas cuando los umbrales se superen.

## Evolucion

- Evidently para reportes automaticos de drift.
- Great Expectations para validaciones de calidad de datos.
- SageMaker Model Monitor si el servicio se mueve a SageMaker.
- S3 como almacenamiento de muestras y reportes.
