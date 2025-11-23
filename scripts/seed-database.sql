-- Seed Database with Test Users and Data
-- Run this on RDS PostgreSQL

-- Users (Riders)
INSERT INTO users (name, email, password, user_type, city) VALUES
('John Doe', 'john@example.com', 'password123', 'rider', 'Mumbai'),
('Jane Smith', 'jane@example.com', 'password123', 'rider', 'Delhi'),
('Bob Wilson', 'bob@example.com', 'password123', 'rider', 'Bangalore'),
('Alice Brown', 'alice@example.com', 'password123', 'rider', 'Mumbai');

-- Drivers
INSERT INTO users (name, email, password, user_type, city) VALUES
('Driver Mike', 'mike@driver.com', 'password123', 'driver', 'Mumbai'),
('Driver Sarah', 'sarah@driver.com', 'password123', 'driver', 'Delhi'),
('Driver Tom', 'tom@driver.com', 'password123', 'driver', 'Bangalore'),
('Driver Lisa', 'lisa@driver.com', 'password123', 'driver', 'Mumbai');

-- Show inserted users
SELECT id, name, email, user_type, city FROM users;

