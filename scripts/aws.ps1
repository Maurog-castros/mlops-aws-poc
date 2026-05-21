param(
    [ValidateSet('check', 'validate-template', 'package', 'deploy-local', 'outputs')]
    [string] $Action = 'check',
    [string] $Region = 'us-east-1',
    [string] $StackName = 'mlops-aws-poc-poc',
    [string] $RepositoryName = 'mlops-aws-poc',
    [string] $EnvironmentName = 'poc',
    [string] $AllowedHttpCidr = '0.0.0.0/0'
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$TemplateFile = Join-Path $ProjectRoot 'infra\aws\ecs-fargate.yml'

function Resolve-DefaultNetwork {
    $vpcId = aws ec2 describe-vpcs `
        --region $Region `
        --filters 'Name=is-default,Values=true' `
        --query 'Vpcs[0].VpcId' `
        --output text

    if ([string]::IsNullOrWhiteSpace($vpcId) -or $vpcId -eq 'None') {
        throw "Default VPC not found in $Region."
    }

    $subnetIds = aws ec2 describe-subnets `
        --region $Region `
        --filters "Name=vpc-id,Values=$vpcId" 'Name=map-public-ip-on-launch,Values=true' `
        --query 'Subnets[].SubnetId' `
        --output text

    $subnetCsv = ($subnetIds -split '\s+' | Where-Object { $_ }) -join ','

    if ([string]::IsNullOrWhiteSpace($subnetCsv)) {
        throw "Public subnets not found in $vpcId."
    }

    [pscustomobject]@{
        VpcId = $vpcId
        PublicSubnetIds = $subnetCsv
    }
}

function Invoke-LocalDeploy {
    Set-Location $ProjectRoot

    $accountId = aws sts get-caller-identity --query Account --output text
    $registry = "$accountId.dkr.ecr.$Region.amazonaws.com"
    $imageTag = "local-$(Get-Date -Format 'yyyyMMddHHmmss')"
    $imageUri = "$registry/${RepositoryName}:$imageTag"
    $network = Resolve-DefaultNetwork

    aws ecr describe-repositories `
        --region $Region `
        --repository-names $RepositoryName *> $null

    if ($LASTEXITCODE -ne 0) {
        aws ecr create-repository `
            --region $Region `
            --repository-name $RepositoryName `
            --image-scanning-configuration scanOnPush=true
    }

    aws ecr get-login-password --region $Region |
        docker login --username AWS --password-stdin $registry

    docker build -t $imageUri .
    docker push $imageUri

    aws cloudformation deploy `
        --region $Region `
        --stack-name $StackName `
        --template-file $TemplateFile `
        --capabilities CAPABILITY_IAM `
        --parameter-overrides `
            EnvironmentName=$EnvironmentName `
            ImageUri=$imageUri `
            VpcId=$($network.VpcId) `
            PublicSubnetIds=$($network.PublicSubnetIds) `
            AllowedHttpCidr=$AllowedHttpCidr
}

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
    'deploy-local' {
        Invoke-LocalDeploy
    }
    'outputs' {
        aws cloudformation describe-stacks `
            --region $Region `
            --stack-name $StackName `
            --query 'Stacks[0].Outputs' `
            --output table
    }
}
