# 🗄️ Database Access Guide

## ✅ RDS is Now Publicly Accessible!

### Connection Details

```
Host:     ridebooking.cba8g8sckc8k.ap-south-1.rds.amazonaws.com
Port:     5432
Database: ridebooking
Username: postgres
Password: RideDB_2025!
```

---

## 🔍 Option 1: AWS Query Editor (Easiest)

**Direct Link:**
```
https://ap-south-1.console.aws.amazon.com/rds/home?region=ap-south-1#query-editor:
```

**Steps:**
1. Click the link above
2. Click "Connect to database"
3. Select: `ridebooking`
4. Choose: "Connect with database credentials"
5. Username: `postgres`
6. Password: `RideDB_2025!`
7. Click "Connect"

**Run These Queries:**
```sql
-- See all users (should show 8 users)
SELECT * FROM users;

-- See all rides
SELECT * FROM rides;

-- Count rides by city (for analytics)
SELECT city, COUNT(*) as ride_count 
FROM rides 
GROUP BY city 
ORDER BY ride_count DESC;

-- Check recent rides
SELECT id, rider_id, driver_id, city, status, created_at 
FROM rides 
ORDER BY created_at DESC 
LIMIT 10;
```

---

## 🔌 Option 2: pgAdmin or DBeaver

**Connection String:**
```
postgresql://postgres:RideDB_2025!@ridebooking.cba8g8sckc8k.ap-south-1.rds.amazonaws.com:5432/ridebooking
```

**Or use these details in your SQL client:**
- **Type:** PostgreSQL
- **Host:** ridebooking.cba8g8sckc8k.ap-south-1.rds.amazonaws.com
- **Port:** 5432
- **Database:** ridebooking
- **Username:** postgres
- **Password:** RideDB_2025!
- **SSL Mode:** Prefer

---

## 📊 Database Schema

### Tables:
1. **users** - All riders and drivers
   - id, name, email, password, user_type (rider/driver), city

2. **rides** - All ride bookings
   - id, rider_id, driver_id, pickup, drop, city, status, fare, created_at

3. **payments** - Payment records
   - id, ride_id, amount, payment_method, status

---

## 🧪 Test Queries

### Check Seeded Users:
```sql
SELECT id, name, email, user_type, city FROM users;
```

Expected: 8 users (4 riders, 3 drivers, 1 test user)

### Check Latest Rides:
```sql
SELECT 
  r.id,
  u1.name as rider,
  u2.name as driver,
  r.city,
  r.status,
  r.created_at
FROM rides r
LEFT JOIN users u1 ON r.rider_id = u1.id
LEFT JOIN users u2 ON r.driver_id = u2.id
ORDER BY r.created_at DESC;
```

### Analytics Query (City-wise Ride Count):
```sql
SELECT 
  city,
  COUNT(*) as total_rides,
  COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed_rides,
  COUNT(CASE WHEN status = 'active' THEN 1 END) as active_rides
FROM rides
GROUP BY city
ORDER BY total_rides DESC;
```

---

## 🔒 Security Note

⚠️ **The RDS is now open to the internet (0.0.0.0/0)**

This is for testing/demo purposes. In production:
- Restrict security group to specific IPs
- Use VPN or bastion host
- Enable SSL/TLS only connections

---

## ✅ Next Steps

1. Open AWS Query Editor
2. Connect to `ridebooking` database
3. Run `SELECT * FROM users;` to verify data
4. Create rides using Thunder Client
5. Query rides table to see new data

**Database is ready for your demo!** 🎉


