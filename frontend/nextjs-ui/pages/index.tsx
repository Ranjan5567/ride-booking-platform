// Home Page - Simple redirect based on authentication status
// Routes to booking page if logged in, otherwise to auth page
import { useRouter } from 'next/router'
import { useEffect } from 'react'

export default function Home() {
  const router = useRouter()

  // Checks if user is logged in and redirects accordingly
  useEffect(() => {
    const user = localStorage.getItem('user')
    if (user) {
      router.push('/book')
    } else {
      router.push('/auth')
    }
  }, [router])

  return (
    <div className="min-h-screen flex items-center justify-center">
      <div className="text-xl">Redirecting...</div>
    </div>
  )
}

