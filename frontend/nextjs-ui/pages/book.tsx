// Book Ride Page - Main booking interface (6th microservice: Frontend)
// This page triggers the complete ride booking flow: Ride Service → Payment → Lambda → Pub/Sub
import { useState, useEffect } from 'react'
import { useRouter } from 'next/router'
import axios from 'axios'

export default function BookRide() {
  const router = useRouter()
  const [user, setUser] = useState<any>(null)
  const [formData, setFormData] = useState({
    pickup: '',
    drop: '',
    city: '',
    driver_id: 1
  })
  const [loading, setLoading] = useState(false)
  const [message, setMessage] = useState('')

  // API endpoint - connects to Ride Service (port-forwarded from EKS)
  const RIDE_API = process.env.NEXT_PUBLIC_RIDE_API_URL || 'http://localhost:8003'

  useEffect(() => {
    const userData = localStorage.getItem('user')
    if (!userData) {
      router.push('/auth')
      return
    }
    setUser(JSON.parse(userData))
  }, [router])

  // Handles ride booking - calls Ride Service which orchestrates:
  // 1. Stores ride in RDS, 2. Processes payment, 3. Triggers Lambda, 4. Publishes to Pub/Sub
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    setMessage('')

    try {
      // API call to Ride Service - triggers the entire microservices orchestration
      const response = await axios.post(`${RIDE_API}/ride/start`, {
        rider_id: user.id,
        driver_id: formData.driver_id,
        pickup: formData.pickup,
        drop: formData.drop,
        city: formData.city  // City is used for analytics aggregation in Flink
      })
      setMessage(`Ride started successfully! Ride ID: ${response.data.ride_id}`)
      setFormData({ pickup: '', drop: '', city: '', driver_id: 1 })
    } catch (err: any) {
      setMessage(err.response?.data?.detail || 'Failed to start ride')
    } finally {
      setLoading(false)
    }
  }

  if (!user) return null

  return (
    <div className="min-h-screen bg-gray-50 py-12 px-4">
      <div className="max-w-2xl mx-auto">
        <div className="bg-white rounded-lg shadow-lg p-8">
          <h1 className="text-3xl font-bold mb-6 text-gray-800">Book a Ride</h1>
          
          {message && (
            <div className={`mb-4 p-4 rounded ${
              message.includes('successfully') 
                ? 'bg-green-100 text-green-700' 
                : 'bg-red-100 text-red-700'
            }`}>
              {message}
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-4">
            <input
              type="text"
              placeholder="Pickup Location"
              value={formData.pickup}
              onChange={(e) => setFormData({ ...formData, pickup: e.target.value })}
              className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              required
            />
            
            <input
              type="text"
              placeholder="Drop Location"
              value={formData.drop}
              onChange={(e) => setFormData({ ...formData, drop: e.target.value })}
              className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              required
            />
            
            <input
              type="text"
              placeholder="City"
              value={formData.city}
              onChange={(e) => setFormData({ ...formData, city: e.target.value })}
              className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              required
            />
            
            <input
              type="number"
              placeholder="Driver ID"
              value={formData.driver_id}
              onChange={(e) => setFormData({ ...formData, driver_id: parseInt(e.target.value) })}
              className="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              required
            />

            <button
              type="submit"
              disabled={loading}
              className="w-full bg-blue-600 text-white py-3 rounded-lg hover:bg-blue-700 transition disabled:opacity-50"
            >
              {loading ? 'Starting Ride...' : 'Start Ride'}
            </button>
          </form>

          <div className="mt-6 flex gap-4">
            <button
              onClick={() => router.push('/rides')}
              className="flex-1 bg-gray-200 text-gray-800 py-2 rounded-lg hover:bg-gray-300 transition"
            >
              My Rides
            </button>
            <button
              onClick={() => router.push('/analytics')}
              className="flex-1 bg-purple-600 text-white py-2 rounded-lg hover:bg-purple-700 transition"
            >
              Analytics
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}

