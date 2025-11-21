# Load Test Script for Ride Booking Services
# Sends continuous requests to services to trigger HPA scaling

param(
    [int]$Duration = 120,  # Duration in seconds (default 2 minutes)
    [string]$Service = "ride-service",  # Service to test
    [int]$Concurrent = 10  # Number of concurrent requests
)

Write-Host "========================================"
Write-Host "  Load Test - Ride Booking Platform"
Write-Host "========================================"
Write-Host ""
Write-Host "Configuration:"
Write-Host "  Service: $Service"
Write-Host "  Duration: $Duration seconds ($([math]::Round($Duration/60, 1)) minutes)"
Write-Host "  Concurrent requests: $Concurrent"
Write-Host ""

# Determine port based on service
$port = switch ($Service) {
    "user-service" { 8001 }
    "driver-service" { 8002 }
    "ride-service" { 8003 }
    "payment-service" { 8004 }
    default { 8003 }
}

$baseUrl = "http://localhost:$port"
Write-Host "Target URL: $baseUrl"
Write-Host ""

# Test connection first
Write-Host "Testing connection..."
try {
    $test = Invoke-WebRequest -Uri "$baseUrl/health" -UseBasicParsing -TimeoutSec 5
    Write-Host "✅ Connection successful!"
} catch {
    Write-Host "❌ Connection failed: $_"
    Write-Host "Make sure port-forward is running on port $port"
    exit 1
}

Write-Host ""
Write-Host "Starting load test..."
Write-Host "Watch your Grafana dashboard to see pod count increase!"
Write-Host ""

$startTime = Get-Date
$endTime = $startTime.AddSeconds($Duration)
$requestCount = 0
$errorCount = 0

# Function to send requests
function Send-Requests {
    param([int]$Count)
    
    $jobs = @()
    for ($i = 0; $i -lt $Count; $i++) {
        $job = Start-Job -ScriptBlock {
            param($url)
            $success = 0
            $errors = 0
            while ($true) {
                try {
                    $response = Invoke-WebRequest -Uri "$url/health" -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
                    $success++
                } catch {
                    $errors++
                }
                Start-Sleep -Milliseconds 100  # 10 requests per second per thread
            }
            return @{Success=$success; Errors=$errors}
        } -ArgumentList $baseUrl
        $jobs += $job
    }
    return $jobs
}

# Start concurrent request jobs
$requestJobs = Send-Requests -Count $Concurrent

# Monitor and display progress
$progressInterval = 10  # Update every 10 seconds
$lastUpdate = Get-Date

while ((Get-Date) -lt $endTime) {
    $elapsed = ((Get-Date) - $startTime).TotalSeconds
    $remaining = $Duration - $elapsed
    
    if ($remaining -le 0) {
        break
    }
    
    # Update progress every interval
    if (((Get-Date) - $lastUpdate).TotalSeconds -ge $progressInterval) {
        $minutes = [math]::Floor($remaining / 60)
        $seconds = [math]::Floor($remaining % 60)
        Write-Host "[$([math]::Floor($elapsed))s] Remaining: ${minutes}m ${seconds}s | Requests sent: ~$($requestCount) | Errors: $errorCount"
        $lastUpdate = Get-Date
    }
    
    # Send a batch of requests
    try {
        $response = Invoke-WebRequest -Uri "$baseUrl/health" -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
        $requestCount++
    } catch {
        $errorCount++
    }
    
    Start-Sleep -Milliseconds 50  # Small delay to avoid overwhelming
}

# Stop all background jobs
Write-Host ""
Write-Host "Stopping load test..."
$requestJobs | Stop-Job
$requestJobs | Remove-Job

$totalTime = ((Get-Date) - $startTime).TotalSeconds

Write-Host ""
Write-Host "========================================"
Write-Host "  Load Test Complete"
Write-Host "========================================"
Write-Host "  Duration: $([math]::Round($totalTime, 1)) seconds"
Write-Host "  Requests sent: ~$requestCount"
Write-Host "  Errors: $errorCount"
Write-Host "  Average rate: ~$([math]::Round($requestCount/$totalTime, 1)) req/sec"
Write-Host ""
Write-Host "✅ Check Grafana to see:"
Write-Host "   - Pod count should have increased"
Write-Host "   - CPU usage should show a spike"
Write-Host "   - HPA should have scaled up pods"
Write-Host ""
Write-Host "💡 Pods will scale back down after 5 minutes of low CPU"
Write-Host ""

