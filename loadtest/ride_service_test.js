import http from 'k6/http';
import { sleep, check } from 'k6';
import { Rate } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');

export let options = {
  stages: [
    { duration: '30s', target: 20 },  // Ramp up to 20 users
    { duration: '1m', target: 50 },    // Ramp up to 50 users
    { duration: '2m', target: 50 },    // Stay at 50 users
    { duration: '30s', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<2000'], // 95% of requests should be below 2s
    errors: ['rate<0.1'],               // Error rate should be less than 10%
  },
};

// Use localhost:8003 directly (port-forward from kubectl)
const BASE_URL = __ENV.RIDE_SERVICE_URL || 'http://localhost:8003';

// Log the URL being used
console.log(`[k6] Using BASE_URL: ${BASE_URL}`);

export default function () {
  // Generate random ride data
  const cities = ['Bangalore', 'Mumbai', 'Delhi', 'Hyderabad', 'Chennai'];
  const pickups = ['Koramangala', 'HSR Layout', 'Whitefield', 'Indiranagar', 'Marathahalli'];
  const drops = ['Airport', 'City Center', 'Mall', 'Station', 'Park'];
  
  const city = cities[Math.floor(Math.random() * cities.length)];
  const pickup = pickups[Math.floor(Math.random() * pickups.length)];
  const drop = drops[Math.floor(Math.random() * drops.length)];
  
  const payload = JSON.stringify({
    rider_id: Math.floor(Math.random() * 10) + 1,
    driver_id: Math.floor(Math.random() * 5) + 1,
    pickup: pickup,
    drop: drop,
    city: city,
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
    tags: {
      name: 'StartRide',
    },
  };

  const url = `${BASE_URL}/ride/start`;
  const response = http.post(url, payload, params);
  
  // Log errors and some successes for debugging
  if (response.status !== 200) {
    console.log(`[k6] ERROR Request ${__ITER}: Status ${response.status}, URL: ${url}`);
    console.log(`[k6] Error Body: ${response.body}`);
  } else if (__ITER % 20 === 0) {
    // Log every 20th success to show it's working
    try {
      const body = JSON.parse(response.body);
      console.log(`[k6] Success Request ${__ITER}: Ride ID ${body.ride_id}`);
    } catch (e) {
      console.log(`[k6] Response: ${response.body}`);
    }
  }
  
  const success = check(response, {
    'status is 200': (r) => r.status === 200,
    'response has ride_id': (r) => {
      try {
        const body = JSON.parse(r.body);
        const hasRideId = body.hasOwnProperty('ride_id');
        if (!hasRideId) {
          console.log(`[k6] ERROR: Missing ride_id in response: ${JSON.stringify(body)}`);
        }
        return hasRideId;
      } catch (e) {
        console.log(`[k6] ERROR: JSON parse error: ${e}, Response: ${response.body}`);
        return false;
      }
    },
  });

  if (!success) {
    errorRate.add(1);
    console.log(`[k6] Request ${__ITER} FAILED checks`);
  } else {
    errorRate.add(0);
  }
  
  sleep(1);
}

export function handleSummary(data) {
  return {
    'stdout': JSON.stringify(data),
  };
}

