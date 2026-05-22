# MLOps AWS PoC

Prueba de concepto MLOps end-to-end usando Python, scikit-learn, FastAPI,
Docker, GitHub Actions y AWS.

El objetivo es construir una base simple pero mantenible para entrenar un
modelo local, exponerlo como API, contenerizarlo, automatizar validaciones y
dejarlo listo para un despliegue inicial en AWS.

## Objetivos

- Entrenar un modelo ML simple con Python y scikit-learn.
- Guardar el modelo como artefacto versionable.
- Exponer inferencia mediante una API con FastAPI.
- Ejecutar pruebas automatizadas con pytest.
- Contenerizar el servicio con Docker.
- Usar Ministack como entorno local de infraestructura para la PoC.
- Automatizar CI/CD con GitHub Actions.
- Usar una maquina Ubuntu Server en la LAN como ambiente intermedio de despliegue.
- Publicar imagen en AWS ECR.
- Desplegar el servicio en AWS ECS/Fargate o EC2.
- Agregar logs y observabilidad básica con CloudWatch.
- Definir una estrategia inicial de versionado y monitoreo de modelo.

## Stack

- Python
- FastAPI
- Uvicorn
- pandas
- numpy
- scikit-learn
- joblib
- pytest
- Docker
- Ministack
- Minikube
- Kubernetes
- Ubuntu Server LAN
- GitHub Actions
- AWS ECR
- AWS ECS/Fargate o EC2
- AWS CloudWatch

## Arquitectura

Pipeline de entrenamiento:

```text
Dataset -> preprocesamiento -> entrenamiento -> evaluacion -> artefacto del modelo
```

Pipeline de inferencia:

```text
Cliente -> FastAPI -> carga del modelo -> prediccion -> respuesta JSON
```

Estructura base:

```text
mlops-aws-poc/
├── app/
│   ├── __init__.py
│   └── main.py
├── data/
│   └── README.md
├── models/
│   └── README.md
├── src/
│   ├── __init__.py
│   ├── train.py
│   └── predict.py
├── tests/
│   └── test_api.py
├── .gitignore
├── README.md
└── requirements.txt
```

## Roadmap de la PoC

### Supuestos nuevos de infraestructura

Ademas del plan inicial, la PoC considera dos elementos operativos:

1. **Ministack** se usara como entorno local de infraestructura para validar
   servicios y dependencias antes de pasar a despliegues remotos.
2. **Ubuntu Server en LAN** se usara como ambiente intermedio de despliegue.
   La maquina disponible actualmente responde en `192.168.1.12` mediante SSH
   con el usuario `mauro`.

Flujo objetivo de ambientes:

```text
Local Windows -> Docker -> Ministack -> Minikube -> Ubuntu Server LAN -> AWS
```

### Fase 1: Repo base y modelo ML local

Objetivo:

Crear la estructura inicial del proyecto y dejar preparada la base para entrenar
un modelo local.

Pasos:

1. Crear el repositorio local `mlops-aws-poc`.
2. Inicializar Git.
3. Crear la estructura de carpetas `app/`, `src/`, `tests/`, `data/` y
   `models/`.
4. Crear `requirements.txt` con las dependencias base.
5. Crear `.gitignore` para excluir entorno virtual, cache, datasets locales y
   artefactos del modelo.
6. Crear una API minima en `app/main.py` con endpoint de salud.
7. Crear placeholders para entrenamiento e inferencia en `src/train.py` y
   `src/predict.py`.
8. Crear una prueba inicial en `tests/test_api.py`.
9. Validar que pytest corre correctamente.

Entregables:

- Repositorio con estructura inicial.
- `README.md` documentado.
- Endpoint `GET /health`.
- Test basico de salud de la API.

Comandos sugeridos:

```bash
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
pytest
```

Criterios de validacion:

- `pytest` debe pasar sin errores.
- `GET /health` debe responder `{"status": "ok"}`.
- No se deben versionar archivos `.csv`, `.joblib`, `.env` ni `.venv/`.

### Fase 2: API de inferencia con FastAPI

Objetivo:

Exponer un endpoint de prediccion que reciba datos por JSON, cargue el modelo
entrenado y devuelva una respuesta estable.

Pasos:

1. Definir el contrato de entrada usando modelos Pydantic.
2. Definir el contrato de salida de la prediccion.
3. Implementar la funcion de prediccion en `src/predict.py`.
4. Cargar el artefacto del modelo desde `models/`.
5. Agregar endpoint `POST /predict` en `app/main.py`.
6. Manejar errores cuando el modelo no exista o el payload sea invalido.
7. Agregar pruebas para inferencia valida e invalida.

Entregables:

- Endpoint `POST /predict`.
- Esquemas de request/response.
- Tests de inferencia.

Criterios de validacion:

- Payload valido retorna HTTP 200.
- Payload invalido retorna HTTP 422.
- Error de modelo no disponible se maneja de forma controlada.

### Fase 3: Dockerizacion

Objetivo:

Empaquetar la API en una imagen Docker reproducible para ejecutar la PoC sin
depender del entorno local. Esta fase tambien deja la base para ejecutar el
servicio en Ministack y en la maquina Ubuntu Server de la LAN.  ssh mauro@192.168.1.12

Pasos:

1. Crear `Dockerfile`.
2. Crear `.dockerignore`.
3. Instalar dependencias dentro de la imagen.
4. Exponer el puerto de la API.
5. Ejecutar Uvicorn como proceso principal.
6. Construir la imagen localmente.
7. Ejecutar el contenedor localmente.
8. Validar `/health` y `/predict` dentro del contenedor.
9. Validar que la imagen pueda ser usada por Ministack.
10. Documentar variables de entorno requeridas para ejecucion local y LAN.

Entregables:

- `Dockerfile`.
- `.dockerignore`.
- Imagen Docker local funcional.
- Base lista para ejecucion en Ministack.

Comandos sugeridos:

```bash
docker build -t mlops-aws-poc:local .
docker run --rm -p 8000:8000 mlops-aws-poc:local
```

Variables de entorno:

| Variable       | Default                 | Uso                                                   |
| -------------- | ----------------------- | ----------------------------------------------------- |
| `APP_HOST`   | `0.0.0.0`             | Interfaz donde escucha Uvicorn dentro del contenedor. |
| `APP_PORT`   | `8000`                | Puerto interno de la API.                             |
| `MODEL_PATH` | `models/model.joblib` | Ruta del artefacto `joblib` dentro del contenedor.  |

Ejecucion con modelo montado:

```bash
docker run --rm -p 8000:8000 \
  -v /ruta/modelos:/app/models:ro \
  -e MODEL_PATH=models/model.joblib \
  mlops-aws-poc:local
```

Para Ministack o Ubuntu Server LAN, la imagen no requiere cambios de codigo:
se debe publicar o copiar la misma imagen, montar el directorio de modelos en
`/app/models` y exponer el puerto `8000` segun el ambiente.

Criterios de validacion:

- El contenedor debe iniciar sin errores.
- `GET http://localhost:8000/health` debe responder correctamente.
- La imagen no debe incluir `.venv/`, `.git/`, caches ni datasets locales.
- La configuracion debe poder trasladarse a Ministack sin cambios de codigo.

### Fase 4: Entorno local con Ministack

Objetivo:

Usar Ministack como entorno local de infraestructura para validar la API y sus
dependencias antes de pasar al servidor Ubuntu LAN o AWS.

Pasos:

1. Definir que componentes de la PoC correran en Ministack.
2. Documentar requisitos locales de instalacion.
3. Configurar la ejecucion de la API dentro del entorno Ministack.
4. Validar variables de entorno y puertos.
5. Ejecutar healthcheck desde el host Windows.
6. Probar inferencia contra el servicio expuesto por Ministack.
7. Documentar comandos de inicio, parada, logs y limpieza.
8. Definir que diferencias existen entre ejecucion local directa, Docker y
   Ministack.

Entregables:

- Guia de ejecucion con Ministack.
- Configuracion local reproducible.
- Validacion de `/health` y `/predict` desde Windows.

Criterios de validacion:

- El servicio debe iniciar dentro de Ministack.
- La API debe responder desde el host Windows.
- La configuracion debe poder reutilizar la misma imagen Docker.
- Las diferencias contra el despliegue LAN deben quedar documentadas.

Configuracion local:

- `compose.ministack.yml`: define el servicio `api` usando la misma imagen
  `mlops-aws-poc:local`.
- `ministack.env.example`: documenta variables de ejecucion.
- `scripts/ministack.ps1`: centraliza comandos operativos desde Windows.
- `scripts/create_smoke_model.py`: genera un modelo local de prueba para
  validar `/predict`.

Componentes que corren en Ministack:

| Componente  | Responsabilidad                                       | Puerto                    |
| ----------- | ----------------------------------------------------- | ------------------------- |
| `api`     | FastAPI + Uvicorn                                     | `HOST_PORT` -> `8000` |
| `models/` | Artefactos `joblib` montados como volumen read-only | N/A                       |

Variables de entorno:

| Variable       | Default                 | Uso                                    |
| -------------- | ----------------------- | -------------------------------------- |
| `APP_HOST`   | `0.0.0.0`             | Bind interno de Uvicorn.               |
| `APP_PORT`   | `8000`                | Puerto interno del contenedor.         |
| `HOST_PORT`  | `8000`                | Puerto expuesto en Windows.            |
| `MODEL_PATH` | `models/model.joblib` | Ruta del modelo dentro del contenedor. |

Comandos operativos:

```powershell
.\scripts\ministack.ps1 -Action model
.\scripts\ministack.ps1 -Action build
.\scripts\ministack.ps1 -Action start
.\scripts\ministack.ps1 -Action status
.\scripts\ministack.ps1 -Action smoke
.\scripts\ministack.ps1 -Action logs
.\scripts\ministack.ps1 -Action stop
.\scripts\ministack.ps1 -Action clean
```

Validacion manual desde Windows:

```powershell
Invoke-RestMethod http://localhost:8000/health
Invoke-RestMethod `
  -Uri http://localhost:8000/predict `
  -Method Post `
  -ContentType 'application/json' `
  -Body '{"tenure":12,"monthly_charges":89.5,"support_tickets":3}'
```

Diferencias por ambiente:

| Ambiente       | Uso                             | Modelo                       | Red                |
| -------------- | ------------------------------- | ---------------------------- | ------------------ |
| Local directo  | Desarrollo rapido con `.venv` | Archivo local en `models/` | `localhost`      |
| Docker directo | Validar imagen aislada          | Volumen manual `-v`        | `localhost:8000` |
| Ministack      | Operacion local reproducible    | Volumen Compose read-only    | `HOST_PORT`      |
| Minikube       | Validar Kubernetes local        | Secret read-only             | `port-forward`   |
| Ubuntu LAN     | Staging interno                 | Volumen o release remoto     | IP LAN del host    |

### Fase 4.5: Kubernetes local con Minikube

Objetivo:

Validar que la misma API Docker puede correr como workload Kubernetes antes de
llevarla a ambientes remotos. Minikube no reemplaza ECS; sirve como entorno
local para probar `Deployment`, `Service`, `ConfigMap`, `Secret`, probes y
configuracion declarativa.

Componentes:

| Archivo | Responsabilidad |
| --- | --- |
| `infra/k8s/namespace.yml` | Namespace aislado de la PoC. |
| `infra/k8s/configmap.yml` | Variables no secretas de ejecucion. |
| `infra/k8s/deployment.yml` | Pod de FastAPI, probes, recursos y hardening basico. |
| `infra/k8s/service.yml` | Service interno `ClusterIP`. |
| `infra/k8s/kustomization.yml` | Entrada unica para `kubectl apply -k`. |
| `scripts/minikube.ps1` | Wrapper operativo desde Windows. |

Requisitos:

```powershell
minikube version
kubectl version --client
docker version
```

Arranque:

```powershell
minikube start
```

Comandos operativos:

```powershell
.\scripts\minikube.ps1 -Action check
.\scripts\minikube.ps1 -Action model
.\scripts\minikube.ps1 -Action build
.\scripts\minikube.ps1 -Action deploy
.\scripts\minikube.ps1 -Action status
.\scripts\minikube.ps1 -Action smoke
.\scripts\minikube.ps1 -Action logs
.\scripts\minikube.ps1 -Action clean
```

Notas operativas:

- `build` construye `mlops-aws-poc:local` dentro del Docker daemon de Minikube.
- `model` genera `models/minikube-smoke-model.joblib` y lo monta como
  `Secret` read-only.
- `deploy` aplica los manifests Kubernetes y espera el rollout.
- `smoke` abre un `port-forward` temporal y valida `/health`, `/model` y
  `/predict`.
- Para AWS, el modelo productivo sigue viniendo desde S3 mediante
  `MODEL_S3_URI`.

### Fase 5: CI/CD con GitHub Actions

Objetivo:

Automatizar validaciones del repositorio en cada push o pull request.

Pasos:

1. Crear workflow en `.github/workflows/ci.yml`.
2. Instalar Python en el runner.
3. Instalar dependencias desde `requirements.txt`.
4. Ejecutar tests con `pytest`.
5. Agregar build de Docker como validacion.
6. Dejar preparado un workflow posterior para publicar en ECR.

Entregables:

- Workflow de CI.
- Validacion automatica de tests.
- Validacion automatica del build Docker.

Criterios de validacion:

- Cada push debe ejecutar el pipeline.
- El pipeline debe fallar si los tests fallan.
- El build Docker debe completarse correctamente.

Workflow:

- `.github/workflows/ci.yml` ejecuta `pytest` con Python 3.12.
- El build Docker corre solo si los tests pasan.
- La imagen se etiqueta como `mlops-aws-poc:${GITHUB_SHA}` dentro del runner.
- La publicacion a AWS ECR queda fuera de este workflow hasta configurar IAM,
  region, registry y permisos de despliegue.

Validacion local equivalente:

```powershell
.\.venv\Scripts\python.exe -m pytest
docker build -t mlops-aws-poc:local .
```

### Fase 6: Despliegue intermedio en Ubuntu Server LAN

Objetivo:

Usar la maquina Ubuntu Server disponible en la LAN como ambiente de staging
operativo antes de avanzar a AWS.

Host inicial:

```text
192.168.1.12
```

Usuario SSH:

```text
mauro
```

Pasos:

1. Validar acceso SSH estable hacia `mauro@192.168.1.12`.
2. Revisar version de Ubuntu, Docker y Docker Compose.
3. Instalar dependencias faltantes si corresponde.
4. Copiar o desplegar la imagen Docker de la API.
5. Ejecutar el contenedor en la maquina LAN.
6. Exponer el puerto interno para pruebas desde la red local.
7. Validar `/health` desde Windows.
8. Validar `/predict` desde Windows.
9. Documentar comandos de arranque, parada, logs y actualizacion.
10. Definir si este ambiente usara imagen local, Git pull o registry.

Entregables:

- API ejecutandose en Ubuntu Server LAN.
- Procedimiento documentado de despliegue interno.
- Comandos de operacion basicos: start, stop, logs, restart.

Comandos sugeridos:

```bash
ssh mauro@192.168.1.12
docker ps
docker logs <container_name>
curl http://localhost:8000/health
```

Criterios de validacion:

- SSH debe funcionar de forma estable.
- Docker debe poder ejecutar la imagen de la API.
- La API debe responder desde la LAN.
- Debe existir un procedimiento claro para reiniciar el servicio.

Estrategia de despliegue:

Para esta fase se usara transferencia de imagen local por SSH/SCP. No depende
de registry ni de Git pull en el servidor. El flujo queda preparado para cambiar
a ECR en la fase AWS.

Archivos:

- `compose.lan.yml`: ejecuta la API en el servidor LAN usando la imagen
  `mlops-aws-poc:local`.
- `lan.env.example`: documenta host, usuario, puerto y directorio remoto.
- `scripts/lan.ps1`: empaqueta, copia, despliega y opera el servicio remoto.

Directorio remoto por defecto:

```text
/home/mauro/mlops-aws-poc
```

Requisitos del servidor:

- Ubuntu Server accesible por SSH.
- Docker instalado.
- Docker Compose disponible como `docker compose`.
- Usuario con permisos para ejecutar Docker, o usar `-UseSudo`.

Comandos desde Windows:

```powershell
.\scripts\lan.ps1 -Action check
.\scripts\lan.ps1 -Action deploy
.\scripts\lan.ps1 -Action status
.\scripts\lan.ps1 -Action smoke
.\scripts\lan.ps1 -Action logs
.\scripts\lan.ps1 -Action restart
.\scripts\lan.ps1 -Action stop
```

Si Docker requiere sudo en Ubuntu:

```powershell
.\scripts\lan.ps1 -Action deploy -UseSudo
```

Validacion desde Windows:

```powershell
Invoke-RestMethod http://192.168.1.12:8000/health
Invoke-RestMethod `
  -Uri http://192.168.1.12:8000/predict `
  -Method Post `
  -ContentType 'application/json' `
  -Body '{"tenure":12,"monthly_charges":89.5,"support_tickets":3}'
```

Rollback operativo:

```powershell
.\scripts\lan.ps1 -Action stop
```

El modelo `models/model.joblib` se copia al servidor solo si existe localmente.
Si no existe, `/health` seguira funcionando y `/predict` devolvera el error
controlado de modelo no disponible.

### Fase 7: AWS deploy simple

Objetivo:

Desplegar la API en AWS usando una alternativa simple y mantenible:
ECR + ECS/Fargate o EC2.

Opcion recomendada:

- ECR para almacenar la imagen Docker.
- ECS/Fargate para ejecutar el contenedor sin administrar servidores.

Pasos:

1. Crear repositorio en AWS ECR.
2. Configurar credenciales seguras en GitHub Secrets.
3. Construir imagen Docker desde GitHub Actions.
4. Publicar imagen en ECR.
5. Crear cluster ECS.
6. Crear task definition.
7. Crear service ECS/Fargate.
8. Configurar security group y puerto HTTP.
9. Validar endpoint publico o privado segun el objetivo de la PoC.

Entregables:

- Imagen publicada en ECR.
- Servicio ejecutandose en ECS/Fargate o EC2.
- URL de validacion de la API.

Criterios de validacion:

- La imagen debe quedar versionada en ECR.
- El servicio debe responder `/health`.
- El despliegue debe poder repetirse desde CI/CD.

Implementacion:

- `infra/aws/ecs-fargate.yml`: CloudFormation para ECS/Fargate con ALB
  publico, security groups, task definition, service y logs.
- `.github/workflows/deploy-aws.yml`: workflow manual para construir, publicar
  en ECR y desplegar/actualizar ECS.
- `aws.env.example`: variables operativas esperadas.
- `scripts/aws.ps1`: validaciones locales de AWS CLI, template y build Docker.

Secret requerido en GitHub:

| Secret | Uso |
| --- | --- |
| `AWS_ROLE_TO_ASSUME` | IAM Role asumido por GitHub Actions mediante OIDC. |

Permisos minimos del role:

- ECR: crear repositorio si no existe, login, push de imagen.
- CloudFormation: crear/actualizar stack.
- ECS/Fargate: crear cluster, service y task definition.
- EC2/ELB: consultar VPC/subnets y crear ALB/security groups.
- IAM: crear task execution role.
- CloudWatch Logs: crear log group para ECS.

Ejecucion desde GitHub:

1. Ir a `Actions`.
2. Seleccionar `deploy-aws`.
3. Ejecutar `Run workflow`.
4. Confirmar `environment`, `aws_region`, `ecr_repository`, `stack_name` y
   `allowed_http_cidr`.

El workflow usa GitHub OIDC. No requiere access keys permanentes en GitHub.

Configuracion OIDC recomendada:

1. Crear un IAM Identity Provider para `https://token.actions.githubusercontent.com`.
2. Crear un IAM Role para el repositorio `Maurog-castros/mlops-aws-poc`.
3. Permitir `sts:AssumeRoleWithWebIdentity` solo desde ese repo y rama esperada.
4. Guardar el ARN del role en GitHub como `AWS_ROLE_TO_ASSUME`.
5. No guardar access keys permanentes en GitHub Actions.

Validacion local previa:

```powershell
.\scripts\aws.ps1 -Action package
.\scripts\aws.ps1 -Action validate-template -Region us-east-1
```

Despliegue desde la maquina local:

```powershell
.\scripts\aws.ps1 -Action deploy-local -Region us-east-1 -StackName mlops-aws-poc-poc
```

Cuando el stack termine, obtener la URL:

```powershell
.\scripts\aws.ps1 -Action outputs -Region us-east-1 -StackName mlops-aws-poc-poc
```

Validacion del servicio:

```powershell
Invoke-RestMethod http://<load-balancer-url>/health
```

Nota operacional: en esta fase el modelo no queda persistido en AWS. El
contenedor puede responder `/health`; `/predict` devolvera el error controlado
de modelo no disponible hasta definir almacenamiento de artefactos en una fase
posterior, por ejemplo S3 o EFS.

### Fase 8: Observabilidad con CloudWatch

Objetivo:

Agregar visibilidad operacional minima para diagnosticar errores, latencia y
comportamiento de inferencia.

Pasos:

1. Enviar logs del contenedor a CloudWatch Logs.
2. Registrar inicio de aplicacion.
3. Registrar errores de carga de modelo.
4. Registrar errores de inferencia.
5. Registrar latencia basica por request si aplica.
6. Definir alarmas simples para errores o servicio no saludable.

Entregables:

- Logs centralizados en CloudWatch.
- Grupo de logs por ambiente o servicio.
- Alarmas basicas.

Criterios de validacion:

- Cada request relevante debe dejar traza operativa.
- Los errores deben quedar visibles en CloudWatch.
- Debe existir una forma simple de detectar caidas del servicio.

Implementacion:

- `app/observability.py` configura logs JSON hacia stdout.
- Cada request agrega el header `X-Process-Time-Ms`.
- Cada request registra metodo, path, status code y duracion.
- `/predict` registra predicciones exitosas, modelo no disponible y errores de
  inferencia.
- ECS envia stdout/stderr a CloudWatch Logs mediante `awslogs`.
- CloudFormation crea alarmas para:
  - errores de aplicacion detectados en logs JSON;
  - targets no saludables en el ALB;
  - CPU alta del servicio ECS;
  - memoria alta del servicio ECS.

Validacion:

```powershell
Invoke-RestMethod http://<load-balancer-url>/health
Invoke-RestMethod `
  -Uri http://<load-balancer-url>/predict `
  -Method Post `
  -ContentType 'application/json' `
  -Body '{"tenure":12,"monthly_charges":89.5,"support_tickets":3}'
.\scripts\aws.ps1 -Action outputs -Region us-east-1 -StackName mlops-aws-poc-poc
```

### Fase 9: Model registry simple y versionado

Objetivo:

Ordenar los artefactos de modelo para saber que version se entreno, con que
metrica y cual esta desplegada.

Pasos:

1. Definir convencion de nombres para modelos.
2. Guardar metadata del entrenamiento.
3. Registrar version, fecha, metrica y dataset usado.
4. Separar modelo local de modelo publicado.
5. Preparar ruta futura hacia S3 o MLflow.

Entregables:

- Convencion de versionado.
- Archivo de metadata por modelo.
- Documentacion del ciclo de promocion de modelo.

Ejemplo de metadata:

```json
{
  "model_name": "baseline_classifier",
  "model_version": "v1",
  "trained_at": "2026-05-21T00:00:00Z",
  "metric_name": "accuracy",
  "metric_value": 0.91,
  "artifact_path": "models/baseline_classifier_v1.joblib"
}
```

Criterios de validacion:

- Cada modelo debe tener version unica.
- Cada modelo debe tener metadata asociada.
- Debe ser posible saber que modelo esta usando la API.

Implementacion:

- `models/registry/baseline_regressor_v1.json`: metadata versionada del modelo
  baseline.
- `src/model_registry.py`: carga metadata y resume features.
- `GET /model`: expone nombre, version, estado, metrica, dataset y ruta del
  artefacto esperado por la API.
- `scripts/register_model.py`: valida campos obligatorios y evita colisiones de
  version.
- `docs/model-registry.md`: documenta convencion, metadata y promocion.

Validacion:

```powershell
.\.venv\Scripts\python.exe scripts\register_model.py models\registry\baseline_regressor_v1.json
Invoke-RestMethod http://localhost:8000/model
```

### Fase 10: Drift y monitoring conceptual

Objetivo:

Definir una estrategia inicial para detectar degradacion del modelo o cambios
en los datos de entrada.

Pasos:

1. Registrar muestras de entrada de inferencia de forma controlada.
2. Comparar distribuciones entre entrenamiento e inferencia.
3. Definir metricas basicas de drift.
4. Documentar umbrales de alerta.
5. Separar monitoreo tecnico de monitoreo de calidad del modelo.
6. Proponer evolucion futura con Evidently, Great Expectations o SageMaker.

Entregables:

- Documento conceptual de drift.
- Lista de metricas iniciales.
- Criterios de alerta.

Criterios de validacion:

- Deben quedar claros los datos que se monitorean.
- Debe existir una distincion entre error tecnico y drift del modelo.
- Debe existir una propuesta para evolucionar el monitoreo.

Implementacion:

- `docs/drift-monitoring.md`: estrategia conceptual y umbrales iniciales.
- `data/drift_baseline.json`: baseline estadistico versionado.
- `/predict` registra resumen controlado de features nombradas en logs:
  `tenure`, `monthly_charges`, `support_tickets`.
- `scripts/check_drift.py`: compara un resumen actual contra el baseline y
  retorna codigo `2` si detecta drift.

Validacion:

```powershell
$tmp = Join-Path $env:TEMP 'mlops-current-drift.json'
'{"features":["tenure","monthly_charges","support_tickets"],"feature_means":{"tenure":36.0,"monthly_charges":70.0,"support_tickets":2.0},"feature_stds":{"tenure":20.0,"monthly_charges":29.0,"support_tickets":1.4}}' |
  Set-Content -Path $tmp -Encoding utf8
.\.venv\Scripts\python.exe scripts\check_drift.py --current $tmp
```

## Ejecucion local

Instalar dependencias:

```bash
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```

Ejecutar API:

```bash
uvicorn app.main:app --reload
```

Validar salud:

```bash
curl http://localhost:8000/health
```

Ejecutar pruebas:

```bash
pytest
```

## Politica de artefactos locales

Los datasets y modelos generados localmente no se versionan en Git.

Se ignoran:

- `data/*.csv`
- `models/*.joblib`
- `.env`
- `.venv/`
- caches de Python y pytest

Los archivos `data/README.md` y `models/README.md` si se versionan para mantener
la estructura del proyecto.

## Security decisions

- No se versionan secretos, `.env`, access keys ni artefactos binarios del
  modelo.
- GitHub Actions despliega con OIDC y un IAM Role asumido temporalmente.
- Los scripts locales usan credenciales configuradas fuera del repo con
  `aws configure`.
- ECS ejecuta la API como usuario no-root dentro del contenedor.
- El task role solo necesita lectura del artefacto de modelo en S3.
- El artefacto del modelo se guarda en S3 con bloqueo de acceso publico y
  versioning.
- Los logs registran resumenes operativos y de features, no payloads crudos ni
  PII.
- El modelo se descarga a `/tmp/model.joblib` en runtime y no queda embebido en
  la imagen Docker.

## Estado actual

Fases 1 a 10 implementadas para la PoC.

Siguiente hito recomendado:

Reemplazar el dataset sintetico por datos reales de negocio y endurecer IAM con
politicas mas acotadas por recurso.

## Artefactos de modelo en S3

Para publicar un modelo en S3 y actualizar ECS:

```powershell
.\scripts\s3-model-artifact.ps1 -Action all -Region us-east-1 -StackName mlops-aws-poc-poc
```

Acciones disponibles:

- `prepare`: crea/configura bucket S3 con versioning y bloqueo publico.
- `upload`: sube `model.joblib` y metadata.
- `deploy`: publica nueva imagen y actualiza ECS con `MODEL_S3_URI`.
- `smoke`: valida `/health` y `/predict` contra el Load Balancer.
- `all`: ejecuta todo el flujo.

Ruta S3 por convencion:

```text
s3://<bucket>/models/<model_name>/<model_version>/model.joblib
s3://<bucket>/models/<model_name>/<model_version>/metadata.json
```
