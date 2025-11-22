import { useState, useEffect } from 'react'
import { useRouter } from 'next/router'
import axios from 'axios'
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts'

interface AnalyticsData {
  city: string
  count: number
  timestamp: string
}

export default function Analytics() {
  const router = useRouter()
  const [data, setData] = useState<AnalyticsData[]>([])
  const [loading, setLoading] = useState(true)

  const RIDE_API = process.env.NEXT_PUBLIC_RIDE_API_URL || 'http://localhost:8003'

  useEffect(() => {
    const userData = localStorage.getItem('user')
    if (!userData) {
      router.push('/auth')
      return
    }
    fetchAnalytics()
    const interval = setInterval(fetchAnalytics, 30000) // Refresh every 30s
    return () => clearInterval(interval)
  }, [router])

  const fetchAnalytics = async () => {
    try {
      // Fetching real-time analytics from ride service (aggregated from Firestore)
      const response = await axios.get(`${RIDE_API}/analytics/latest`)
      setData(response.data)
    } catch (err) {
      // Fallback to mock data for demo
      setData([
        { city: 'Bangalore', count: 45, timestamp: new Date().toISOString() },
        { city: 'Mumbai', count: 32, timestamp: new Date().toISOString() },
        { city: 'Delhi', count: 28, timestamp: new Date().toISOString() },
        { city: 'Hyderabad', count: 15, timestamp: new Date().toISOString() },
        { city: 'Chennai', count: 12, timestamp: new Date().toISOString() },
      ])
    } finally {
      setLoading(false)
    }
  }

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-xl">Loading analytics...</div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-50 py-12 px-4">
      <div className="max-w-6xl mx-auto">
        <div className="bg-white rounded-lg shadow-lg p-8">
          <h1 className="text-3xl font-bold mb-6 text-gray-800">Ride Analytics Dashboard</h1>
          <p className="text-gray-600 mb-6">Rides per city per minute (processed by Flink → Google Firestore)</p>
          
          <div className="h-96">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={data}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="city" />
                <YAxis />
                <Tooltip />
                <Legend />
                <Bar dataKey="count" fill="#8884d8" />
              </BarChart>
            </ResponsiveContainer>
          </div>

          <div className="mt-6">
            <button
              onClick={() => router.push('/book')}
              className="bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 transition"
            >
              Back to Booking
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}

