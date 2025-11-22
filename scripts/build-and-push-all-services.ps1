# Build and Push All Services to ECR
# Run this after Docker Desktop is started

$ErrorActionPreference = "Stop"

$awsAccountId = "943812325535"
$region = "ap-south-1"
$services = @("user-service", "driver-service", "ride-service", "payment-service")

Write-Host "`n=== Building and Pushing All Services ===" -ForegroundColor Green
Write-Host "AWS Account: $awsAccountId"
Write-Host "Region: $region"
Write-Host "Services: $($services -join ', ')"
Write-Host ""

# ECR Login
Write-Host "Logging into ECR..." -ForegroundColor Yellow
aws ecr get-login-password --region $region | docker login --username AWS --password-stdin "$awsAccountId.dkr.ecr.$region.amazonaws.com"

foreach ($service in $services) {
    Write-Host "`n=== Processing $service ===" -ForegroundColor Cyan
    
    $servicePath = "backend\$service"
    $ecrRepo = "$awsAccountId.dkr.ecr.$region.amazonaws.com/$service"
    
    if (-not (Test-Path $servicePath)) {
        Write-Host "ERROR: $servicePath not found!" -ForegroundColor Red
        continue
    }
    
    # Build
    Write-Host "Building $service..." -ForegroundColor Yellow
    Set-Location $servicePath
    docker build -t $service .
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Build failed for $service" -ForegroundColor Red
        Set-Location ..\..
        continue
    }
    
    # Tag
    Write-Host "Tagging $service..." -ForegroundColor Yellow
    docker tag "${service}:latest" "${ecrRepo}:latest"
    
    # Push
    Write-Host "Pushing $service to ECR..." -ForegroundColor Yellow
    docker push "${ecrRepo}:latest"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ $service pushed successfully!" -ForegroundColor Green
    } else {
        Write-Host "❌ Failed to push $service" -ForegroundColor Red
    }
    
    Set-Location ..\..
}

Write-Host "`n=== All Services Processed ===" -ForegroundColor Green
Write-Host "Check above for any errors."

