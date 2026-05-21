# MLOps AWS PoC

End-to-end MLOps proof of concept using Python, scikit-learn, FastAPI, Docker, GitHub Actions and AWS.

## Goals

- Train a simple ML model
- Expose inference through FastAPI
- Containerize the service with Docker
- Add CI/CD with GitHub Actions
- Deploy to AWS
- Add observability and basic model monitoring

## Architecture

Training pipeline:

```text
Dataset -> preprocessing -> training -> evaluation -> model artifact
```

Inference pipeline:

```text
Client -> FastAPI -> model artifact -> prediction response
```

## Stack

- Python
- scikit-learn
- FastAPI
- Docker
- GitHub Actions
- AWS ECR/ECS or EC2
- CloudWatch
