# Quick Database Seeding Script
# Seeds the RDS database with test users

$ErrorActionPreference = "Stop"

Write-Host "`n=== Seeding Database with Test Users ===" -ForegroundColor Cyan

# User Service URL
$userServiceUrl = "http://localhost:8001"

# Test Riders
$riders = @(
    @{name="John Doe"; email="john@example.com"; password="password123"; user_type="rider"; city="Mumbai"},
    @{name="Jane Smith"; email="jane@example.com"; password="password123"; user_type="rider"; city="Delhi"},
    @{name="Bob Wilson"; email="bob@example.com"; password="password123"; user_type="rider"; city="Bangalore"},
    @{name="Alice Brown"; email="alice@example.com"; password="password123"; user_type="rider"; city="Mumbai"}
)

# Test Drivers
$drivers = @(
    @{name="Driver Mike"; email="mike@driver.com"; password="password123"; user_type="driver"; city="Mumbai"},
    @{name="Driver Sarah"; email="sarah@driver.com"; password="password123"; user_type="driver"; city="Delhi"},
    @{name="Driver Tom"; email="tom@driver.com"; password="password123"; user_type="driver"; city="Bangalore"}
)

Write-Host "`nCreating Riders..." -ForegroundColor Yellow
foreach ($rider in $riders) {
    try {
        $body = $rider | ConvertTo-Json
        $response = Invoke-RestMethod -Uri "$userServiceUrl/user/register" -Method POST -Body $body -ContentType "application/json"
        Write-Host "  ✅ Created: $($rider.name) (ID: $($response.id))" -ForegroundColor Green
    } catch {
        Write-Host "  ⚠️  $($rider.name): $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host "`nCreating Drivers..." -ForegroundColor Yellow
foreach ($driver in $drivers) {
    try {
        $body = $driver | ConvertTo-Json
        $response = Invoke-RestMethod -Uri "$userServiceUrl/user/register" -Method POST -Body $body -ContentType "application/json"
        Write-Host "  ✅ Created: $($driver.name) (ID: $($response.id))" -ForegroundColor Green
    } catch {
        Write-Host "  ⚠️  $($driver.name): $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host "`n✅ Database seeding complete!" -ForegroundColor Green
Write-Host "`nYou can now use these accounts:" -ForegroundColor Cyan
Write-Host "  Riders: john@example.com, jane@example.com, bob@example.com"
Write-Host "  Drivers: mike@driver.com, sarah@driver.com, tom@driver.com"
Write-Host "  Password (all): password123"

