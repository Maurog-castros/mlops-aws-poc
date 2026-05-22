param(
    [ValidateSet('check', 'package', 'deploy', 'start', 'stop', 'restart', 'status', 'logs', 'smoke')]
    [string] $Action = 'check',
    [string] $HostName = '192.168.1.12',
    [string] $UserName = 'mauro',
    [string] $RemoteDir = '/home/mauro/mlops-aws-poc',
    [int] $HostPort = 8000,
    [switch] $UseSudo
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$ImageName = 'mlops-aws-poc:local'
$Remote = "${UserName}@${HostName}"
$BundlePath = Join-Path $env:TEMP 'mlops-aws-poc-image.tar'
$ComposeFile = Join-Path $ProjectRoot 'compose.lan.yml'
$ModelPath = Join-Path $ProjectRoot 'models\model.joblib'
$Docker = if ($UseSudo) { 'sudo docker' } else { 'docker' }

function Invoke-Remote {
    param([string] $Command)

    ssh $Remote $Command
}

function Copy-ToRemote {
    param(
        [string] $Source,
        [string] $Target
    )

    scp $Source "${Remote}:${Target}"
}

function Test-LanPort {
    $result = Test-NetConnection -ComputerName $HostName -Port 22

    if (-not $result.TcpTestSucceeded) {
        throw "SSH port 22 is not reachable on $HostName."
    }
}

function Invoke-Package {
    Set-Location $ProjectRoot
    docker build -t $ImageName .
    docker save -o $BundlePath $ImageName
    Write-Host "Created image bundle: $BundlePath"
}

function Invoke-Deploy {
    Invoke-Package

    Invoke-Remote "mkdir -p '$RemoteDir/models'"
    Copy-ToRemote $BundlePath '/tmp/mlops-aws-poc-image.tar'
    Copy-ToRemote $ComposeFile "$RemoteDir/compose.lan.yml"

    if (Test-Path $ModelPath) {
        Copy-ToRemote $ModelPath "$RemoteDir/models/model.joblib"
    } else {
        Write-Warning 'models/model.joblib not found. /predict will return 503 until a model is copied.'
    }

    Invoke-Remote "$Docker load -i /tmp/mlops-aws-poc-image.tar"
    Invoke-Remote "cd '$RemoteDir' && HOST_PORT=$HostPort $Docker compose -f compose.lan.yml up -d"
}

function Invoke-Smoke {
    $baseUrl = "http://${HostName}:${HostPort}"
    $health = Invoke-RestMethod -Uri "$baseUrl/health" -Method Get -TimeoutSec 10
    $prediction = Invoke-RestMethod `
        -Uri "$baseUrl/predict" `
        -Method Post `
        -ContentType 'application/json' `
        -Body '{"tenure":12,"monthly_charges":89.5,"support_tickets":3}' `
        -TimeoutSec 10

    [pscustomobject]@{
        health = $health.status
        prediction = $prediction.prediction
        model_path = $prediction.model_path
    } | ConvertTo-Json
}

switch ($Action) {
    'check' {
        Test-LanPort
        Invoke-Remote "uname -a && $Docker --version && $Docker compose version"
    }
    'package' {
        Invoke-Package
    }
    'deploy' {
        Test-LanPort
        Invoke-Deploy
    }
    'start' {
        Invoke-Remote "cd '$RemoteDir' && HOST_PORT=$HostPort $Docker compose -f compose.lan.yml up -d"
    }
    'stop' {
        Invoke-Remote "cd '$RemoteDir' && $Docker compose -f compose.lan.yml down"
    }
    'restart' {
        Invoke-Remote "cd '$RemoteDir' && $Docker compose -f compose.lan.yml restart api"
    }
    'status' {
        Invoke-Remote "cd '$RemoteDir' && $Docker compose -f compose.lan.yml ps"
    }
    'logs' {
        Invoke-Remote "cd '$RemoteDir' && $Docker compose -f compose.lan.yml logs --tail 100 api"
    }
    'smoke' {
        Invoke-Smoke
    }
}
