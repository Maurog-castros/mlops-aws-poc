param(
    [ValidateSet('prepare', 'upload', 'deploy', 'smoke', 'all')]
    [string] $Action = 'prepare',
    [string] $Region = 'us-east-1',
    [string] $StackName = 'mlops-aws-poc-poc',
    [string] $RepositoryName = 'mlops-aws-poc',
    [string] $EnvironmentName = 'poc',
    [string] $BucketName = '',
    [string] $ModelName = 'baseline_regressor',
    [string] $ModelVersion = 'v1',
    [string] $ModelPath = 'models/model.joblib',
    [string] $MetadataPath = 'models/registry/baseline_regressor_v1.json',
    [string] $AllowedHttpCidr = '0.0.0.0/0'
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$TemplateFile = Join-Path $ProjectRoot 'infra\aws\ecs-fargate.yml'

function Resolve-BucketName {
    if (-not [string]::IsNullOrWhiteSpace($BucketName)) {
        return $BucketName
    }

    $accountId = aws sts get-caller-identity --query Account --output text
    return "mlops-aws-poc-models-$accountId-$Region"
}

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

function New-ModelBucket {
    $bucket = Resolve-BucketName

    aws s3api head-bucket --bucket $bucket 2>$null
    if ($LASTEXITCODE -ne 0) {
        if ($Region -eq 'us-east-1') {
            aws s3api create-bucket --bucket $bucket --region $Region
        } else {
            aws s3api create-bucket `
                --bucket $bucket `
                --region $Region `
                --create-bucket-configuration "LocationConstraint=$Region"
        }
    }

    aws s3api put-public-access-block `
        --bucket $bucket `
        --public-access-block-configuration `
            BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

    aws s3api put-bucket-versioning `
        --bucket $bucket `
        --versioning-configuration Status=Enabled

    Write-Host "Model bucket ready: s3://$bucket"
}

function Publish-ModelArtifact {
    Set-Location $ProjectRoot

    $bucket = Resolve-BucketName
    $resolvedModelPath = Resolve-Path $ModelPath
    $resolvedMetadataPath = Resolve-Path $MetadataPath
    $prefix = "models/$ModelName/$ModelVersion"
    $modelKey = "$prefix/model.joblib"
    $metadataKey = "$prefix/metadata.json"

    aws s3 cp $resolvedModelPath "s3://$bucket/$modelKey" --region $Region
    aws s3 cp $resolvedMetadataPath "s3://$bucket/$metadataKey" --region $Region

    [pscustomobject]@{
        model_s3_uri = "s3://$bucket/$modelKey"
        metadata_s3_uri = "s3://$bucket/$metadataKey"
    } | ConvertTo-Json
}

function Invoke-DeployWithS3Model {
    Set-Location $ProjectRoot

    $bucket = Resolve-BucketName
    $modelKey = "models/$ModelName/$ModelVersion/model.joblib"
    $modelS3Uri = "s3://$bucket/$modelKey"
    $accountId = aws sts get-caller-identity --query Account --output text
    $registry = "$accountId.dkr.ecr.$Region.amazonaws.com"
    $imageTag = "s3model-$(Get-Date -Format 'yyyyMMddHHmmss')"
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
            AllowedHttpCidr=$AllowedHttpCidr `
            ModelPath=/tmp/model.joblib `
            ModelS3Uri=$modelS3Uri `
            ModelS3Bucket=$bucket `
            ModelS3Key=$modelKey
}

function Invoke-Smoke {
    $url = aws cloudformation describe-stacks `
        --region $Region `
        --stack-name $StackName `
        --query "Stacks[0].Outputs[?OutputKey=='LoadBalancerUrl'].OutputValue" `
        --output text

    $health = Invoke-RestMethod -Uri "$url/health" -Method Get -TimeoutSec 20
    $prediction = Invoke-RestMethod `
        -Uri "$url/predict" `
        -Method Post `
        -ContentType 'application/json' `
        -Body '{"features":[1,2,3]}' `
        -TimeoutSec 20

    [pscustomobject]@{
        url = $url
        health = $health.status
        prediction = $prediction.prediction
        model_path = $prediction.model_path
    } | ConvertTo-Json
}

switch ($Action) {
    'prepare' {
        New-ModelBucket
    }
    'upload' {
        Publish-ModelArtifact
    }
    'deploy' {
        Invoke-DeployWithS3Model
    }
    'smoke' {
        Invoke-Smoke
    }
    'all' {
        New-ModelBucket
        Publish-ModelArtifact
        Invoke-DeployWithS3Model
        Invoke-Smoke
    }
}

