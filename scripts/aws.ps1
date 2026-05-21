param(
    [ValidateSet('check', 'validate-template', 'package', 'outputs')]
    [string] $Action = 'check',
    [string] $Region = 'us-east-1',
    [string] $StackName = 'mlops-aws-poc-poc'
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$TemplateFile = Join-Path $ProjectRoot 'infra\aws\ecs-fargate.yml'

switch ($Action) {
    'check' {
        aws sts get-caller-identity
        aws ecr describe-repositories --region $Region
    }
    'validate-template' {
        aws cloudformation validate-template `
            --region $Region `
            --template-body "file://$TemplateFile"
    }
    'package' {
        Set-Location $ProjectRoot
        docker build -t mlops-aws-poc:local .
    }
    'outputs' {
        aws cloudformation describe-stacks `
            --region $Region `
            --stack-name $StackName `
            --query 'Stacks[0].Outputs' `
            --output table
    }
}

