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
- `dataset_name`
- `artifact_path`
- `status`

Los artefactos binarios (`*.joblib`, `*.pkl`) no se versionan en Git.

## Promocion

1. Entrenar o copiar el artefacto en `models/`.
2. Registrar metadata en `models/registry/`.
3. Validar que la version sea unica.
4. Configurar `MODEL_PATH` y `MODEL_METADATA_PATH`.
5. Desplegar la imagen o montar el artefacto segun ambiente.

## Futuro

La ruta natural para produccion es mover artefactos a S3 o MLflow y mantener
este JSON como contrato minimo de metadata.

