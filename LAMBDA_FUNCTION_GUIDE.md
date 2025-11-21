# Lambda Function Guide - Notification Service

## 📋 Overview

The Lambda function is a **serverless notification service** that sends notifications when rides are started. It's part of the multi-cloud ride booking platform.

**Function Name:** `ride-booking-notification-lambda`  
**Runtime:** Python 3.11  
**Trigger:** HTTP via API Gateway  
**Purpose:** Log ride notifications to CloudWatch

## 🔗 API Endpoint

**URL:** `https://98p8bgfmf5.execute-api.ap-south-1.amazonaws.com/notify`

**Method:** POST  
**Content-Type:** application/json

## 📝 Request Format

```json
{
  "ride_id": 123,
  "city": "Mumbai"
}
```

## ✅ Response Format

**Success (200):**
```json
{
  "message": "Notification: Ride 123 started successfully in Mumbai",
  "ride_id": 123,
  "city": "Mumbai"
}
```

**Error (500):**
```json
{
  "error": "Error message here"
}
```

## 🚀 How It Works

1. **Ride Service calls Lambda** when a ride is started
2. **Lambda receives** ride_id and city
3. **Lambda logs** notification to CloudWatch
4. **Lambda returns** success response

## 🧪 Testing the Lambda Function

### Method 1: Direct HTTP Request

```powershell
# Test Lambda via API Gateway
$body = @{
    ride_id = 123
    city = "Mumbai"
} | ConvertTo-Json

Invoke-WebRequest -Uri "https://98p8bgfmf5.execute-api.ap-south-1.amazonaws.com/notify" `
    -Method POST `
    -Body $body `
    -ContentType "application/json"
```

### Method 2: Using AWS CLI

```powershell
# Invoke Lambda directly
aws lambda invoke `
    --function-name ride-booking-notification-lambda `
    --payload '{"body": "{\"ride_id\": 123, \"city\": \"Mumbai\"}"}' `
    response.json

# View response
Get-Content response.json
```

### Method 3: Test via Ride Service

The Lambda is automatically called when you start a ride through the Ride Service:

```powershell
# Start a ride (this will trigger Lambda)
curl -X POST http://localhost:8003/api/rides/start `
    -H "Content-Type: application/json" `
    -d '{"user_id": 1, "driver_id": 1, "pickup": "Location A", "dropoff": "Location B"}'
```

## 📊 Viewing Lambda Logs

### CloudWatch Logs

```powershell
# View recent logs
aws logs tail /aws/lambda/ride-booking-notification-lambda --since 1h

# View last 50 log entries
aws logs tail /aws/lambda/ride-booking-notification-lambda --since 1h --format short | Select-Object -Last 50

# Follow logs in real-time
aws logs tail /aws/lambda/ride-booking-notification-lambda --follow
```

### Via AWS Console

1. Go to: https://console.aws.amazon.com/cloudwatch
2. Navigate to: **Logs** → **Log groups**
3. Find: `/aws/lambda/ride-booking-notification-lambda`
4. Click on latest log stream to view messages

## 🔧 Configuration

### Environment Variables

- `LOG_LEVEL`: INFO (set in Terraform)

### Lambda Settings

- **Memory:** 128 MB
- **Timeout:** 3 seconds
- **Runtime:** Python 3.11
- **Handler:** `index.handler`

### IAM Role

The Lambda has a role with:
- CloudWatch Logs write permissions
- Basic Lambda execution permissions

## 🔗 Integration with Ride Service

The Ride Service calls Lambda when a ride starts:

**Code Location:** `services/ride-service/app.py`

**Environment Variable:**
- `LAMBDA_API_URL`: Set in ConfigMap (from Terraform output)

**How it's called:**
```python
async def call_notification_lambda(ride_id: int, city: str):
    lambda_url = os.getenv('LAMBDA_API_URL')
    payload = {"ride_id": ride_id, "city": city}
    # Makes HTTP POST request to Lambda
```

## 🎛️ Disabling Notifications

If you want to disable Lambda calls during testing:

```powershell
# Set environment variable in ride-service deployment
kubectl set env deployment/ride-service DISABLE_NOTIFICATIONS=true

# Re-enable
kubectl set env deployment/ride-service DISABLE_NOTIFICATIONS=false
```

Or update the deployment YAML:
```yaml
env:
- name: DISABLE_NOTIFICATIONS
  value: "true"  # Set to "false" to enable
```

## 📈 Monitoring Lambda

### View Metrics

```powershell
# Get Lambda metrics
aws cloudwatch get-metric-statistics `
    --namespace AWS/Lambda `
    --metric-name Invocations `
    --dimensions Name=FunctionName,Value=ride-booking-notification-lambda `
    --start-time (Get-Date).AddHours(-1).ToString("yyyy-MM-ddTHH:mm:ss") `
    --end-time (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss") `
    --period 3600 `
    --statistics Sum
```

### Check Function Status

```powershell
# Get function configuration
aws lambda get-function --function-name ride-booking-notification-lambda

# Get function URL (if configured)
aws lambda get-function-url-config --function-name ride-booking-notification-lambda
```

## 🐛 Troubleshooting

### Lambda Not Being Called?

1. **Check Ride Service logs:**
   ```powershell
   kubectl logs -l app=ride-service --tail=50 | Select-String "lambda"
   ```

2. **Verify Lambda URL is set:**
   ```powershell
   kubectl get configmap app-config -o yaml | Select-String "lambda"
   ```

3. **Test Lambda directly:**
   ```powershell
   # Use the test command above
   ```

### Lambda Errors?

1. **Check CloudWatch Logs:**
   ```powershell
   aws logs tail /aws/lambda/ride-booking-notification-lambda --since 1h
   ```

2. **Check Lambda function code:**
   - File: `infra/aws/modules/lambda/function.py`
   - Make sure handler is correct: `index.handler`

3. **Verify API Gateway:**
   ```powershell
   aws apigateway get-rest-apis
   ```

### Lambda Timeout?

- Current timeout: 3 seconds
- Increase if needed in Terraform: `infra/aws/modules/lambda/main.tf`

## 🔄 Updating Lambda Function

1. **Edit function code:**
   ```bash
   # Edit: infra/aws/modules/lambda/function.py
   ```

2. **Redeploy:**
   ```powershell
   cd infra/aws
   terraform apply -target=module.lambda
   ```

3. **Or update via AWS CLI:**
   ```powershell
   # Zip the function
   Compress-Archive -Path infra/aws/modules/lambda/function.py -DestinationPath lambda.zip

   # Update function
   aws lambda update-function-code `
       --function-name ride-booking-notification-lambda `
       --zip-file fileb://lambda.zip
   ```

## 📚 Summary

- **What it does:** Sends notifications when rides start
- **How it's triggered:** HTTP POST from Ride Service
- **Where logs go:** CloudWatch Logs
- **How to test:** Use the API Gateway URL or invoke directly
- **How to monitor:** Check CloudWatch Logs and metrics

The Lambda function is fully integrated and working! It's automatically called by the Ride Service when rides are started.


