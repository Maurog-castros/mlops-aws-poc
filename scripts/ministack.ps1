param(
    [ValidateSet('model', 'build', 'start', 'stop', 'restart', 'logs', 'status', 'smoke', 'clean')]
    [string] $Action = 'status'
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$ComposeFile = Join-Path $ProjectRoot 'compose.ministack.yml'
$Python = Join-Path $ProjectRoot '.venv\Scripts\python.exe'

function Invoke-Compose {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $ComposeArgs
    )

    & docker compose -f $ComposeFile @ComposeArgs
}

function Invoke-Smoke {
    Wait-Health

    $health = Invoke-RestMethod `
        -Uri 'http://localhost:8000/health' `
        -Method Get `
        -TimeoutSec 10

    $prediction = Invoke-RestMethod `
        -Uri 'http://localhost:8000/predict' `
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

function Wait-Health {
    $deadline = (Get-Date).AddSeconds(30)

    do {
        try {
            Invoke-RestMethod `
                -Uri 'http://localhost:8000/health' `
                -Method Get `
                -TimeoutSec 3 | Out-Null
            return
        } catch {
            Start-Sleep -Seconds 1
        }
    } while ((Get-Date) -lt $deadline)

    throw 'Ministack API did not become healthy within 30 seconds.'
}

Set-Location $ProjectRoot

switch ($Action) {
    'model' {
        if (-not (Test-Path $Python)) {
            throw 'Local virtualenv not found. Run: python -m venv .venv; .\.venv\Scripts\pip install -r requirements.txt'
        }

        & $Python scripts\create_smoke_model.py
    }
    'build' {
        Invoke-Compose @('build')
    }
    'start' {
        Invoke-Compose @('up', '-d', '--no-build')
        Wait-Health
    }
    'stop' {
        Invoke-Compose @('down')
    }
    'restart' {
        Invoke-Compose @('down')
        Invoke-Compose @('up', '-d', '--no-build')
        Wait-Health
    }
    'logs' {
        Invoke-Compose @('logs', '-f', 'api')
    }
    'status' {
        Invoke-Compose @('ps')
    }
    'smoke' {
        Invoke-Smoke
    }
    'clean' {
        Invoke-Compose @('down', '--remove-orphans')
    }
}
