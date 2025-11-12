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

const BASE_URL = __ENV.RIDE_SERVICE_URL || 'http://ride-service:80';

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

  const response = http.post(`${BASE_URL}/ride/start`, payload, params);
  
  const success = check(response, {
    'status is 200': (r) => r.status === 200,
    'response has ride_id': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.hasOwnProperty('ride_id');
      } catch (e) {
        return false;
      }
    },
  });

  errorRate.add(!success);
  
  sleep(1);
}

export function handleSummary(data) {
  return {
    'stdout': JSON.stringify(data),
  };
}

