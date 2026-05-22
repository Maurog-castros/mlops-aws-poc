param(
    [ValidateSet('check', 'model', 'build', 'deploy', 'restart', 'status', 'logs', 'smoke', 'port-forward', 'clean')]
    [string] $Action = 'status',

    [string] $Profile = 'minikube',

    [string] $Namespace = 'mlops-aws-poc',

    [int] $LocalPort = 8000
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$K8sDir = Join-Path $ProjectRoot 'infra\k8s'
$Python = Join-Path $ProjectRoot '.venv\Scripts\python.exe'
$ModelFile = Join-Path $ProjectRoot 'models\minikube-smoke-model.joblib'

function Assert-Command {
    param([string] $Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $Name"
    }
}

function Assert-Tooling {
    Assert-Command 'minikube'
    Assert-Command 'kubectl'
    Assert-Command 'docker'
}

function Ensure-Namespace {
    kubectl apply -f (Join-Path $K8sDir 'namespace.yml') | Out-Host
}

function Ensure-SmokeModel {
    if (-not (Test-Path $Python)) {
        throw 'Local virtualenv not found. Run: python -m venv .venv; .\.venv\Scripts\pip install -r requirements.txt'
    }

    & $Python scripts\create_smoke_model.py --output $ModelFile
}

function Ensure-ModelSecret {
    if (-not (Test-Path $ModelFile)) {
        Ensure-SmokeModel
    }

    Ensure-Namespace

    kubectl create secret generic mlops-aws-poc-model `
        --namespace $Namespace `
        --from-file "model.joblib=$ModelFile" `
        --dry-run=client `
        -o yaml |
        kubectl apply -f - | Out-Host
}

function Invoke-MinikubeDockerBuild {
    Assert-Tooling

    minikube -p $Profile status | Out-Host
    minikube -p $Profile docker-env --shell powershell | Invoke-Expression
    docker build -t mlops-aws-poc:local .
}

function Invoke-Deploy {
    Assert-Tooling
    Ensure-ModelSecret

    kubectl apply -k $K8sDir | Out-Host
    kubectl rollout status deployment/mlops-aws-poc-api `
        --namespace $Namespace `
        --timeout 120s | Out-Host
}

function Wait-Health {
    param([int] $Port)

    $deadline = (Get-Date).AddSeconds(45)

    do {
        try {
            Invoke-RestMethod `
                -Uri "http://localhost:$Port/health" `
                -Method Get `
                -TimeoutSec 3 | Out-Null
            return
        } catch {
            Start-Sleep -Seconds 1
        }
    } while ((Get-Date) -lt $deadline)

    throw "Minikube API did not become healthy on localhost:$Port within 45 seconds."
}

function Invoke-Smoke {
    Assert-Tooling

    $portForward = Start-Process `
        -FilePath 'kubectl' `
        -ArgumentList @(
            'port-forward',
            '--namespace', $Namespace,
            'svc/mlops-aws-poc-api',
            "${LocalPort}:8000"
        ) `
        -WindowStyle Hidden `
        -PassThru

    try {
        Wait-Health -Port $LocalPort

        $health = Invoke-RestMethod `
            -Uri "http://localhost:$LocalPort/health" `
            -Method Get `
            -TimeoutSec 10

        $model = Invoke-RestMethod `
            -Uri "http://localhost:$LocalPort/model" `
            -Method Get `
            -TimeoutSec 10

        $prediction = Invoke-RestMethod `
            -Uri "http://localhost:$LocalPort/predict" `
            -Method Post `
            -ContentType 'application/json' `
            -Body '{"tenure":12,"monthly_charges":89.5,"support_tickets":3}' `
            -TimeoutSec 10

        [pscustomobject]@{
            health = $health.status
            model_name = $model.model_name
            model_version = $model.model_version
            prediction = $prediction.prediction
            model_path = $prediction.model_path
        } | ConvertTo-Json
    } finally {
        if ($portForward -and -not $portForward.HasExited) {
            Stop-Process -Id $portForward.Id -Force
        }
    }
}

Set-Location $ProjectRoot

switch ($Action) {
    'check' {
        Assert-Tooling
        minikube -p $Profile status
        kubectl version --client
    }
    'model' {
        Ensure-SmokeModel
        Ensure-ModelSecret
    }
    'build' {
        Invoke-MinikubeDockerBuild
    }
    'deploy' {
        Invoke-Deploy
    }
    'restart' {
        Invoke-Deploy
        kubectl rollout restart deployment/mlops-aws-poc-api --namespace $Namespace | Out-Host
        kubectl rollout status deployment/mlops-aws-poc-api --namespace $Namespace --timeout 120s | Out-Host
    }
    'status' {
        Assert-Tooling
        kubectl get all --namespace $Namespace
    }
    'logs' {
        Assert-Tooling
        kubectl logs --namespace $Namespace --selector app.kubernetes.io/name=mlops-aws-poc-api --tail 100 -f
    }
    'smoke' {
        Invoke-Smoke
    }
    'port-forward' {
        Assert-Tooling
        kubectl port-forward --namespace $Namespace svc/mlops-aws-poc-api "${LocalPort}:8000"
    }
    'clean' {
        Assert-Tooling
        kubectl delete namespace $Namespace --ignore-not-found
    }
}
