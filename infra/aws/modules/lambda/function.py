import json
import os

def lambda_handler(event, context):
    """
    Notification Lambda function
    Logs ride notification to CloudWatch
    """
    try:
        # Parse request body
        if isinstance(event.get('body'), str):
            body = json.loads(event['body'])
        else:
            body = event.get('body', {})
        
        ride_id = body.get('ride_id', 'unknown')
        city = body.get('city', 'unknown')
        
        message = f"Notification: Ride {ride_id} started successfully in {city}"
        
        # Log to CloudWatch
        print(message)
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'message': message,
                'ride_id': ride_id,
                'city': city
            })
        }
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': str(e)
            })
        }

