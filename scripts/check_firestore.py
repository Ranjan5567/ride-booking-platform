#!/usr/bin/env python3
"""Check Firestore for analytics data"""
from google.cloud import firestore

db = firestore.Client(database='ride-booking-analytics')
docs = list(db.collection('ride_analytics').limit(10).stream())

print(f'Found {len(docs)} documents in ride_analytics collection')
print()

if docs:
    print('Recent analytics data:')
    for doc in docs:
        data = doc.to_dict()
        print(f'  Document ID: {doc.id}')
        print(f'    City: {data.get("city", "N/A")}')
        print(f'    Count: {data.get("count", "N/A")}')
        print(f'    Timestamp: {data.get("timestamp", "N/A")}')
        print()
else:
    print('No data found in Firestore.')
    print()
    print('Possible reasons:')
    print('  1. No rides created yet')
    print('  2. Aggregation window (60 seconds) not expired')
    print('  3. Analytics script not processing messages')
    print('  4. Script not writing to Firestore')

