# Deploy Flink Job to Azure HDInsight (PowerShell)
param(
    [string]$ClusterName = "ride-booking-hdinsight",
    [string]$SSHUser = "sshuser",
    [string]$SSHPass = "P@ssw0rd123!",
    [string]$ResourceGroup = "cloudProject"
)

Write-Host "🚀 Deploying Flink Job to Azure HDInsight..." -ForegroundColor Green

# Get cluster SSH endpoint
Write-Host "📡 Getting HDInsight SSH endpoint..." -ForegroundColor Cyan
$sshEndpoint = az hdinsight show `
  --name $ClusterName `
  --resource-group $ResourceGroup `
  --query "properties.connectivityEndpoints[?name=='SSH'].location" `
  -o tsv

if ([string]::IsNullOrEmpty($sshEndpoint)) {
    Write-Host "❌ Error: Could not get SSH endpoint" -ForegroundColor Red
    exit 1
}

Write-Host "✅ SSH Endpoint: $sshEndpoint" -ForegroundColor Green

# Build Flink job
Write-Host "🔨 Building Flink job..." -ForegroundColor Cyan
Push-Location "$PSScriptRoot\..\analytics\flink-job"
.\mvnw.cmd clean package
Pop-Location

# Get connection strings
Write-Host "📡 Getting connection strings..." -ForegroundColor Cyan
Push-Location "$PSScriptRoot\..\infra\azure"
$eventhubConn = terraform output -raw eventhub_connection_string
$cosmosdbConn = terraform output -raw cosmosdb_connection_string
Pop-Location

Write-Host ""
Write-Host "✅ Infrastructure ready!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Next Steps:" -ForegroundColor Yellow
Write-Host "1. SSH into HDInsight cluster:" -ForegroundColor White
Write-Host "   ssh $SSHUser@$sshEndpoint" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Install Flink (on cluster):" -ForegroundColor White
Write-Host "   wget https://archive.apache.org/dist/flink/flink-1.17.1/flink-1.17.1-bin-scala_2.12.tgz" -ForegroundColor Gray
Write-Host "   tar -xzf flink-1.17.1-bin-scala_2.12.tgz" -ForegroundColor Gray
Write-Host "   cd flink-1.17.1" -ForegroundColor Gray
Write-Host "   ./bin/start-cluster.sh" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Upload JAR file:" -ForegroundColor White
Write-Host "   scp $PSScriptRoot\..\analytics\flink-job\target\ride-analytics-1.0.jar $SSHUser@${sshEndpoint}:~/flink-1.17.1/" -ForegroundColor Gray
Write-Host ""
Write-Host "4. Submit Flink job (on cluster):" -ForegroundColor White
Write-Host "   ./bin/flink run -c com.ridebooking.RideAnalyticsJob ride-analytics-1.0.jar" -ForegroundColor Gray
Write-Host ""
Write-Host "5. Access Flink Web UI:" -ForegroundColor White
Write-Host "   ssh -L 8081:localhost:8081 $SSHUser@$sshEndpoint" -ForegroundColor Gray
Write-Host "   Then open: http://localhost:8081" -ForegroundColor Gray
Write-Host ""
Write-Host "📄 Connection Strings saved to:" -ForegroundColor Yellow
Write-Host "   EventHub: $eventhubConn" -ForegroundColor Gray
Write-Host "   CosmosDB: $cosmosdbConn" -ForegroundColor Gray

