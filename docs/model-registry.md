# Model Registry

## Convencion

Los modelos se nombran con esta forma:

```text
<model_name>_<model_version>
```

Ejemplo:

```text
baseline_regressor_v1
```

## Metadata

Cada modelo debe tener un archivo JSON en `models/registry/`.

Campos obligatorios:

- `model_name`
- `model_version`
- `trained_at`
- `metric_name`
- `metric_value`
- `secondary_metrics`
- `dataset_name`
- `artifact_path`
- `status`
- `features`

Los artefactos binarios (`*.joblib`, `*.pkl`) no se versionan en Git.

## Promocion

1. Entrenar con `python -m src.train`.
2. Registrar metadata en `models/registry/`.
3. Validar que la version sea unica.
4. Subir `model.joblib` y metadata a S3.
5. Configurar `MODEL_S3_URI` y `MODEL_PATH=/tmp/model.joblib`.
6. Desplegar la imagen o montar el artefacto segun ambiente.

## Futuro

La ruta natural para produccion es mover artefactos a S3 o MLflow y mantener
este JSON como contrato minimo de metadata.
