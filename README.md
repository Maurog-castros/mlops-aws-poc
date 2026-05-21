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
Local Windows -> Ministack -> Ubuntu Server LAN -> AWS
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
  -Body '{"features":[1,2,3]}'
```

Diferencias por ambiente:

| Ambiente       | Uso                             | Modelo                       | Red                |
| -------------- | ------------------------------- | ---------------------------- | ------------------ |
| Local directo  | Desarrollo rapido con `.venv` | Archivo local en `models/` | `localhost`      |
| Docker directo | Validar imagen aislada          | Volumen manual `-v`        | `localhost:8000` |
| Ministack      | Operacion local reproducible    | Volumen Compose read-only    | `HOST_PORT`      |
| Ubuntu LAN     | Staging interno                 | Volumen o release remoto     | IP LAN del host    |

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

- `.github/workflows/ci.yml` ejecuta `pytest` con Python 3.13.
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

Usuario temporal - SSH / pass:

```text
mauro / Twelve12$
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

## Estado actual

Fase actual: **Fase 1 - Repo base y modelo ML local**.

Siguiente hito recomendado:

Implementar el primer entrenamiento local en `src/train.py`, generar un modelo
baseline en `models/` y conectar `src/predict.py` con el artefacto generado.
