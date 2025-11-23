# API Gateway Module - HTTP endpoint for Lambda function
# Provides public URL that Ride Service calls to trigger notifications

# HTTP API Gateway - creates public HTTP endpoint
resource "aws_apigatewayv2_api" "main" {
  name          = "${var.lambda_function_name}-api"
  protocol_type = "HTTP"
  description   = "API Gateway for notification Lambda"
}

# Integration - connects API Gateway to Lambda function
resource "aws_apigatewayv2_integration" "lambda" {
  api_id           = aws_apigatewayv2_api.main.id
  integration_type = "AWS_PROXY"
  integration_uri  = var.lambda_function_arn
  integration_method = "POST"
}

# Route - defines POST /notify endpoint that triggers Lambda
resource "aws_apigatewayv2_route" "lambda" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /notify"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

output "api_url" {
  value = aws_apigatewayv2_api.main.api_endpoint
}

output "api_id" {
  value = aws_apigatewayv2_api.main.id
}

