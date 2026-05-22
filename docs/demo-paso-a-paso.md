# PoC MLOps AWS - Paso a Paso

Este documento explica la PoC de forma simple, como guion para entenderla y
demostrarla en una entrevista.

La idea central es esta:

```text
Se entrena un modelo reproducible.
El modelo se guarda como artefacto.
El artefacto se sube a S3.
La API corre en Docker sobre ECS/Fargate.
La API descarga el modelo al iniciar.
La API responde predicciones por HTTP.
CloudWatch registra logs, errores y senales operativas.
```

## 1. Que problema resuelve

Esta PoC demuestra como pasar de un experimento local a una base MLOps operable:

- entrenamiento reproducible;
- artefacto de modelo versionable;
- contrato de inferencia estable;
- API empaquetada en Docker;
- despliegue en AWS;
- modelo servido desde S3;
- observabilidad con CloudWatch;
- base para CI/CD con GitHub Actions y AWS OIDC.

En una plataforma logistica, este patron podria usarse para predecir riesgo,
prioridad o costo esperado de un embarque.

El modelo actual usa datos sinteticos. No busca precision de negocio real; busca
demostrar el flujo completo de MLOps.

## 2. Features del modelo

El contrato productivo de inferencia usa tres variables nombradas:

| Feature | Significado de demo |
| --- | --- |
| `tenure` | Antiguedad del cliente o cuenta. |
| `monthly_charges` | Cargo mensual o costo asociado. |
| `support_tickets` | Cantidad de tickets o incidencias. |

Ejemplo de payload valido:

```json
{
  "tenure": 12,
  "monthly_charges": 89.5,
  "support_tickets": 3
}
```

El payload antiguo ya no es valido:

```json
{"features": [1.0, 2.0, 3.0]}
```

Ese formato debe responder HTTP `422`, porque la API ahora exige campos de
negocio.

## 3. Componentes principales

| Componente | Para que sirve |
| --- | --- |
| `src/train.py` | Entrena el modelo, calcula metricas y genera artefactos. |
| FastAPI | Expone `/health`, `/model` y `/predict`. |
| Pydantic | Valida el contrato de entrada y salida. |
| Docker | Empaqueta la API en una imagen reproducible. |
| ECR | Guarda la imagen Docker en AWS. |
| ECS/Fargate | Ejecuta la API sin administrar servidores. |
| S3 | Guarda el artefacto `model.joblib` y metadata. |
| CloudWatch | Guarda logs, metricas y alarmas. |
| GitHub Actions | Ejecuta CI y deja base para deploy con OIDC. |

## 4. Entrenar el modelo

Desde la raiz del repo:

```powershell
cd C:\DEV\mlops-aws-poc
.\.venv\Scripts\python.exe -m src.train
```

Esto genera:

```text
models/model.joblib
models/registry/baseline_regressor_v1.json
data/drift_baseline.json
```

Salida esperada aproximada:

```text
Model saved: C:\DEV\mlops-aws-poc\models\model.joblib
Metadata saved: C:\DEV\mlops-aws-poc\models\registry\baseline_regressor_v1.json
Drift baseline saved: C:\DEV\mlops-aws-poc\data\drift_baseline.json
MAE: 1.8184
R2: 0.9450
```

Interpretacion:

- `model.joblib` es el artefacto binario que usa la API.
- `baseline_regressor_v1.json` describe el modelo y sus metricas.
- `drift_baseline.json` guarda medias y desviaciones por feature para comparar
  drift futuro.

## 5. Endpoints de la API

### Salud

```http
GET /health
```

Respuesta:

```json
{"status": "ok"}
```

### Metadata del modelo

```http
GET /model
```

Respuesta esperada:

```json
{
  "model_name": "baseline_regressor",
  "model_version": "v1",
  "status": "candidate",
  "metric_name": "mae",
  "metric_value": 1.818355486678055,
  "secondary_metrics": {
    "r2": 0.9450339335430316
  },
  "dataset_name": "synthetic_logistics_regression",
  "artifact_path": "models/model.joblib",
  "metadata_path": "models/registry/baseline_regressor_v1.json",
  "features": [
    "tenure",
    "monthly_charges",
    "support_tickets"
  ]
}
```

### Prediccion

```http
POST /predict
```

Body:

```json
{
  "tenure": 12,
  "monthly_charges": 89.5,
  "support_tickets": 3
}
```

Respuesta esperada aproximada:

```json
{
  "prediction": 31.48250316146831,
  "model_path": "/tmp/model.joblib"
}
```

La prediccion exacta puede cambiar si se reentrena el modelo.

## 6. Ejecutar pruebas locales

```powershell
.\.venv\Scripts\python.exe -m pytest
```

Resultado esperado:

```text
6 passed
```

Que validan estas pruebas:

- `/health` responde correctamente.
- `/predict` acepta payload valido.
- `/predict` rechaza payload antiguo con HTTP `422`.
- error de modelo no disponible se maneja con HTTP `503`.
- parsing de URI S3 funciona.

## 7. Ejecutar API local sin Docker

```powershell
.\.venv\Scripts\uvicorn.exe app.main:app --reload
```

Probar:

```powershell
Invoke-RestMethod http://localhost:8000/health
Invoke-RestMethod http://localhost:8000/model
Invoke-RestMethod `
  -Uri http://localhost:8000/predict `
  -Method Post `
  -ContentType 'application/json' `
  -Body '{"tenure":12,"monthly_charges":89.5,"support_tickets":3}'
```

## 8. Ejecutar en Docker local

Construir imagen:

```powershell
docker build -t mlops-aws-poc:local .
```

Ejecutar contenedor:

```powershell
docker run --rm -p 8000:8000 mlops-aws-poc:local
```

Si quieres probar con el modelo local montado en `/tmp/model.joblib`:

```powershell
$modelPath = "C:\DEV\mlops-aws-poc\models\model.joblib"
docker run --rm -p 8000:8000 `
  -v "${modelPath}:/tmp/model.joblib:ro" `
  mlops-aws-poc:local
```

Validar:

```powershell
Invoke-RestMethod http://localhost:8000/health
Invoke-RestMethod http://localhost:8000/model
Invoke-RestMethod `
  -Uri http://localhost:8000/predict `
  -Method Post `
  -ContentType 'application/json' `
  -Body '{"tenure":12,"monthly_charges":89.5,"support_tickets":3}'
```

## 9. Ejecutar en Minikube

Minikube permite validar la misma imagen Docker como workload Kubernetes local.
No reemplaza AWS ECS; sirve para demostrar portabilidad y operacion declarativa.

Requisitos:

```powershell
minikube version
kubectl version --client
docker version
```

Si `minikube` no funciona en PowerShell, instalarlo manualmente:

```powershell
New-Item -Path 'C:\' -Name 'minikube' -ItemType Directory -Force

$ProgressPreference = 'SilentlyContinue'

Invoke-WebRequest `
  -OutFile 'C:\minikube\minikube.exe' `
  -Uri 'https://github.com/kubernetes/minikube/releases/latest/download/minikube-windows-amd64.exe' `
  -UseBasicParsing
```

Activarlo en la sesion actual:

```powershell
$env:Path += ';C:\minikube'
minikube version
```

Dejarlo permanente en el `PATH` del usuario:

```powershell
$oldPath = [Environment]::GetEnvironmentVariable('Path', 'User')

if ($oldPath -notlike '*C:\minikube*') {
    [Environment]::SetEnvironmentVariable(
        'Path',
        "$oldPath;C:\minikube",
        'User'
    )
}
```

Despues de eso, cerrar y abrir PowerShell.

Arrancar Minikube:

```powershell
minikube start
```

Construir la imagen dentro del Docker daemon de Minikube:

```powershell
.\scripts\minikube.ps1 -Action build
```

Crear `models/minikube-smoke-model.joblib` y montarlo como `Secret`
Kubernetes:

```powershell
.\scripts\minikube.ps1 -Action model
```

Desplegar:

```powershell
.\scripts\minikube.ps1 -Action deploy
```

Ver estado:

```powershell
.\scripts\minikube.ps1 -Action status
```

Probar `/health`, `/model` y `/predict`:

```powershell
.\scripts\minikube.ps1 -Action smoke
```

Resultado esperado aproximado:

```json
{
  "health": "ok",
  "model_name": "baseline_regressor",
  "model_version": "v1",
  "prediction": 18.5,
  "model_path": "/models/model.joblib"
}
```

Abrir un `port-forward` manual:

```powershell
.\scripts\minikube.ps1 -Action port-forward
```

Limpiar:

```powershell
.\scripts\minikube.ps1 -Action clean
```

Que demuestra esta fase:

```text
La imagen no depende de ECS.
La configuracion vive fuera del codigo.
El modelo se monta como artefacto read-only.
Kubernetes valida readiness/liveness probes.
El servicio puede moverse luego a EKS si hiciera falta.
```

## 10. Nota sobre CloudFormation en VS Code

Si VS Code muestra errores como:

```text
Unresolved tag: !Ref
Unresolved tag: !Sub
Unresolved tag: !GetAtt
```

no significa necesariamente que el template este malo. Es el validador YAML
generico de VS Code, que no siempre reconoce funciones propias de
CloudFormation.

La validacion real del template se hace con:

```powershell
.\.venv\Scripts\cfn-lint.exe infra\aws\ecs-fargate.yml
```

En este repo se agrego:

```text
.vscode/settings.json
```

para declarar `yaml.customTags` y evitar falsos positivos del editor. Si los
warnings siguen apareciendo:

```text
Ctrl+Shift+P -> Developer: Reload Window
```

o cerrar y abrir VS Code.

## 11. Ejecutar en Ubuntu LAN

Servidor LAN usado:

```text
192.168.1.12
```

Ver estado:

```powershell
.\scripts\lan.ps1 -Action status
```

Probar API:

```powershell
.\scripts\lan.ps1 -Action smoke
```

Resultado esperado aproximado:

```json
{
  "health": "ok",
  "prediction": 31.48250316146831,
  "model_path": "models/model.joblib"
}
```

## 12. Desplegar en AWS

La PoC usa:

```text
ECR + ECS/Fargate + ALB + S3 + CloudWatch
```

Validar credenciales AWS locales:

```powershell
aws sts get-caller-identity
```

Subir modelo a S3, construir imagen, subir a ECR, actualizar ECS y validar:

```powershell
.\scripts\s3-model-artifact.ps1 -Action all -Region us-east-1 -StackName mlops-aws-poc-poc
```

Esto hace:

1. Crea o valida el bucket S3 del modelo.
2. Sube `models/model.joblib`.
3. Sube metadata del modelo.
4. Construye nueva imagen Docker.
5. Sube imagen a ECR.
6. Actualiza ECS/Fargate con `MODEL_S3_URI`.
7. Valida `/health` y `/predict`.

Resultado esperado aproximado:

```json
{
  "url": "http://<load-balancer>",
  "health": "ok",
  "prediction": 31.48250316146831,
  "model_path": "/tmp/model.joblib"
}
```

## 13. Probar la API publica en AWS

Usar la URL del Load Balancer:

```powershell
$url = "http://mlops--LoadB-qBHxaBuKQ06C-1500585403.us-east-1.elb.amazonaws.com"
```

Probar salud:

```powershell
Invoke-RestMethod "$url/health"
```

Probar modelo:

```powershell
Invoke-RestMethod "$url/model"
```

Probar prediccion:

```powershell
Invoke-RestMethod `
  -Uri "$url/predict" `
  -Method Post `
  -ContentType 'application/json' `
  -Body '{"tenure":12,"monthly_charges":89.5,"support_tickets":3}'
```

Validar ECS:

```powershell
aws ecs describe-services `
  --cluster mlops-aws-poc-poc `
  --services mlops-aws-poc-poc `
  --region us-east-1 `
  --query "services[0].{desired:desiredCount,running:runningCount,status:status}" `
  --output json
```

Resultado esperado:

```json
{
  "desired": 1,
  "running": 1,
  "status": "ACTIVE"
}
```

## 14. Donde ver logs

Grupo de logs:

```text
/ecs/mlops-aws-poc/poc
```

Buscar eventos de descarga del modelo:

```powershell
aws logs filter-log-events `
  --region us-east-1 `
  --log-group-name /ecs/mlops-aws-poc/poc `
  --filter-pattern 'model_downloaded' `
  --max-items 5
```

Buscar eventos de prediccion:

```powershell
aws logs filter-log-events `
  --region us-east-1 `
  --log-group-name /ecs/mlops-aws-poc/poc `
  --filter-pattern 'prediction_completed' `
  --max-items 5
```

Eventos importantes:

```text
application_started
model_downloaded
request_completed
prediction_completed
model_unavailable
prediction_failed
```

Cada request registra:

```text
method
path
status_code
duration_ms
```

Cada prediccion registra un resumen controlado:

```text
tenure
monthly_charges
support_tickets
```

No se registra el payload crudo ni informacion personal.

## 15. Drift baseline

El baseline de drift queda en:

```text
data/drift_baseline.json
```

Estructura conceptual:

```json
{
  "features": [
    "tenure",
    "monthly_charges",
    "support_tickets"
  ],
  "feature_means": {
    "tenure": 36.17375,
    "monthly_charges": 70.179530409217,
    "support_tickets": 1.98125
  },
  "feature_stds": {
    "tenure": 21.166485359537847,
    "monthly_charges": 29.47199265926911,
    "support_tickets": 1.3748355011110425
  }
}
```

Probar comparacion de drift con un archivo temporal:

```powershell
$current = "$env:TEMP\current-drift.json"
'{"features":["tenure","monthly_charges","support_tickets"],"feature_means":{"tenure":36.0,"monthly_charges":70.0,"support_tickets":2.0},"feature_stds":{"tenure":20.0,"monthly_charges":29.0,"support_tickets":1.4}}' |
  Set-Content -Path $current -Encoding utf8

.\.venv\Scripts\python.exe scripts\check_drift.py `
  --baseline data\drift_baseline.json `
  --current $current
```

Respuesta esperada:

```json
{
  "status": "ok",
  "alerts": []
}
```

## 16. CI/CD con GitHub Actions y OIDC

El workflow de deploy ya no debe usar access keys permanentes en GitHub.

La configuracion recomendada es:

1. Crear un IAM Identity Provider para GitHub:

```text
https://token.actions.githubusercontent.com
```

2. Crear un IAM Role que permita `sts:AssumeRoleWithWebIdentity` solo desde el
   repo:

```text
Maurog-castros/mlops-aws-poc
```

3. Guardar el ARN del rol en GitHub Secrets:

```text
AWS_ROLE_TO_ASSUME
```

4. Ejecutar el workflow `Deploy AWS`.

Esto evita guardar `AWS_ACCESS_KEY_ID` y `AWS_SECRET_ACCESS_KEY` como secrets de
larga vida.

## 17. Decisiones de seguridad

La PoC aplica estas decisiones:

- no commitear secretos;
- no subir `models/model.joblib` a Git;
- usar OIDC para GitHub Actions;
- usar `aws configure` solo para ejecucion manual local;
- ejecutar contenedor como usuario no-root;
- descargar el modelo desde S3 a `/tmp/model.joblib`;
- dar al task role solo lectura `s3:GetObject` sobre el artefacto;
- bloquear acceso publico al bucket de modelos;
- versionar el bucket S3;
- evitar logs con payload crudo o PII;
- mantener metadata y baseline como evidencia versionable.

## 18. Como presentar la demo

Guion corto:

```text
1. Esta PoC no intenta vender precision del modelo.
2. Demuestra el camino operativo completo de MLOps.
3. Entreno un modelo reproducible con contrato de negocio.
4. Genero artefacto, metadata y baseline de drift.
5. Empaqueto la API en Docker.
6. Subo el modelo a S3 y la imagen a ECR.
7. ECS descarga el modelo al iniciar.
8. /predict hace inferencia real.
9. CloudWatch deja evidencia operativa.
10. El siguiente paso es usar datos logisticos reales y endurecer IAM.
```

Frase clave:

```text
El valor de esta PoC no esta en el modelo sintetico; esta en que el flujo desde
entrenamiento hasta inferencia en AWS ya es repetible, observable y desplegable.
```

## 19. Mejoras recomendadas

Despues de revisar los documentos de referencia MLOps, estas son las mejoras que
mas valor agregan a esta PoC para una entrevista.

### 19.1 Quality gates del modelo

Hoy `src.train` entrena, evalua y guarda metadata. El siguiente paso es hacer que
el entrenamiento falle si el modelo no cumple umbrales minimos.

Ejemplo de regla:

```text
MAE <= 3.0
R2 >= 0.90
```

Valor para entrevista:

```text
No cualquier modelo entrenado se publica. Primero debe pasar criterios minimos
de calidad.
```

Archivos sugeridos:

```text
src/train.py
tests/test_train.py
```

### 19.2 MLflow opcional para tracking

La PoC ya tiene metadata JSON, pero MLflow permitiria registrar ejecuciones de
entrenamiento de forma mas estandar.

Mejora propuesta:

- registrar parametros del modelo;
- registrar `mae` y `r2`;
- registrar `model.joblib` como artefacto;
- guardar `mlflow_run_id` en `baseline_regressor_v1.json`;
- documentar como abrir MLflow UI local.

Comando conceptual:

```powershell
mlflow ui --backend-store-uri .\mlruns
```

Valor para entrevista:

```text
Puedo comparar experimentos, saber que hiperparametros generaron cada modelo y
trazar de donde salio el artefacto desplegado.
```

### 19.3 Pipeline automatico de entrenamiento

Actualmente el entrenamiento se ejecuta manualmente:

```powershell
.\.venv\Scripts\python.exe -m src.train
```

Mejora propuesta:

- agregar `.github/workflows/train-model.yml`;
- ejecutar entrenamiento;
- ejecutar tests;
- validar que metadata y drift baseline se generen;
- publicar artefactos como evidencia de GitHub Actions.

Valor para entrevista:

```text
El flujo de entrenamiento no depende de mi maquina local; queda automatizado y
auditable.
```

### 19.4 Rollback de modelo

S3 ya guarda el artefacto del modelo y el bucket puede tener versioning. Falta
un script operacional para volver a una version anterior.

Mejora propuesta:

```text
scripts/rollback-model.ps1
```

Responsabilidades:

- listar versiones disponibles del modelo en S3;
- seleccionar una version anterior;
- actualizar ECS con el `MODEL_S3_URI` correspondiente;
- validar `/health`;
- validar `/predict`;
- dejar evidencia en logs.

Valor para entrevista:

```text
Si un modelo nuevo falla, puedo volver al modelo anterior sin cambiar codigo.
```

### 19.5 Runbook operacional

La PoC ya tiene comandos repartidos entre README, scripts y este documento. Una
mejora Day 2 seria crear un runbook dedicado.

Archivo sugerido:

```text
docs/operations-runbook.md
```

Debe incluir:

- revisar estado ECS;
- revisar health del ALB target group;
- buscar logs `model_downloaded`;
- buscar logs `prediction_completed`;
- diagnosticar `model_unavailable`;
- revisar alarmas CloudWatch;
- procedimiento de rollback;
- procedimiento de limpieza para evitar costos.

Valor para entrevista:

```text
No solo se desplegar; tambien se operar, diagnosticar y recuperar el servicio.
```

### 19.6 Responsible AI minimo

Aunque el modelo actual es sintetico, conviene declarar limites y riesgos.

Archivo sugerido:

```text
docs/responsible-ai.md
```

Debe cubrir:

- el modelo no debe usarse para decisiones reales;
- posibles sesgos si se usan datos historicos reales;
- necesidad de revision humana;
- explicabilidad minima;
- proteccion de datos personales;
- metricas por segmento cuando existan datos reales.

Valor para entrevista:

```text
Reconozco que MLOps no es solo desplegar modelos; tambien implica gobierno,
riesgo y uso responsable.
```

### 19.7 Diagrama de arquitectura

Los documentos de referencia piden arquitectura visible. La PoC ya tiene la
arquitectura implementada, pero falta un diagrama dedicado.

Archivo sugerido:

```text
docs/architecture.md
```

Diagrama conceptual:

```text
GitHub Actions -> ECR -> ECS/Fargate -> FastAPI
                         |
                         v
                        S3
                         |
                         v
                    CloudWatch
```

Valor para entrevista:

```text
Permite explicar el sistema completo en menos de un minuto.
```

### 19.8 Model registry mas completo

El registry actual vive en:

```text
models/registry/baseline_regressor_v1.json
```

Mejora propuesta:

- agregar `stage`: `candidate`, `staging`, `production`, `archived`;
- agregar `source_commit`;
- agregar `training_command`;
- agregar `dataset_hash`;
- agregar `promoted_at`;
- agregar `approved_by`.

Valor para entrevista:

```text
Puedo demostrar trazabilidad: que codigo, datos, metricas y aprobacion generaron
el modelo desplegado.
```

## 20. Roadmap recomendado

Orden sugerido para seguir mejorando sin inflar la PoC:

```text
1. Agregar quality gates en src.train.
2. Agregar tests de entrenamiento.
3. Agregar MLflow local opcional.
4. Agregar workflow train-model.yml.
5. Agregar rollback-model.ps1.
6. Crear docs/architecture.md.
7. Crear docs/operations-runbook.md.
8. Crear docs/responsible-ai.md.
9. Endurecer IAM con permisos minimos.
10. Reemplazar dataset sintetico por datos logisticos reales.
```

La combinacion mas potente para entrevista seria:

```text
train.py reproducible
+ quality gates
+ MLflow tracking
+ S3 model registry
+ ECS inference
+ CloudWatch observability
+ rollback script
```

## 21. Limitaciones actuales

Esta PoC todavia no es un producto final.

Falta:

- reemplazar datos sinteticos por datos logisticos reales;
- agregar pipeline automatico de entrenamiento programado;
- agregar quality gates del modelo;
- agregar MLflow o tracking equivalente;
- promover modelos con aprobacion formal;
- reducir aun mas permisos IAM;
- agregar autenticacion a la API;
- agregar HTTPS con dominio propio;
- mejorar monitoreo de drift con datos de produccion;
- agregar rollback automatico de modelo o task definition.

## 22. Checklist final

La PoC esta funcionando si:

- `python -m src.train` genera modelo, metadata y baseline.
- `pytest` responde `6 passed`.
- Docker build termina sin errores.
- `GET /health` responde `ok`.
- `GET /model` muestra `baseline_regressor v1`.
- `POST /predict` devuelve una prediccion.
- payload antiguo `{"features":[...]}` responde `422`.
- ECS tiene `running = 1` y `desired = 1`.
- CloudWatch muestra `model_downloaded`.
- CloudWatch muestra `prediction_completed` con features nombradas.
