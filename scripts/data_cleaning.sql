USE uber_db;

-- Tables:
-- cancellations
-- drivers
-- locations
-- payments
-- reviews
-- riders
-- trips
-- users


-- Cancellations table
SELECT * 
FROM cancellations 
LIMIT 5;

SELECT * 
FROM cancellations
WHERE CONCAT(cancel_id, trip_id, cancelled_by, reason, cancelled_at) IS NULL;
-- No nulls found

SELECT cancel_id, COUNT(*) AS occurrence
FROM cancellations
GROUP BY cancel_id
HAVING COUNT(*) > 1;
-- No duplicates

SELECT DISTINCT reason
FROM cancellations;

-- Drivers table
SELECT * 
FROM drivers 
LIMIT 5;

SELECT *
FROM drivers
WHERE CONCAT(driver_id, user_id, vehicle_make, vehicle_model, vehicle_year, license_plate, rating, join_date, is_active) IS NULL;
-- No nulls found

SELECT driver_id, COUNT(*) AS occurrence
FROM drivers
GROUP BY driver_id
HAVING COUNT(*) > 1;
-- No duplicates

-- Locations table
SELECT * 
FROM locations
LIMIT 5;

SELECT *
FROM locations
WHERE CONCAT(location_id, zone_name, city, latitude, longitude, zone_type) IS NULL;
-- No nulls found

SELECT location_id, COUNT(*) AS occurrence
FROM locations
GROUP BY location_id
HAVING COUNT(*) > 1;
-- No duplicates found

-- Payments table
SELECT *
FROM payments
LIMIT 5;

SELECT * 
FROM payments
WHERE CONCAT(payment_id, trip_id, amount, method, status, paid_at) IS NULL;
-- No nulls found

SELECT payment_id, COUNT(*) AS occurrence
FROM payments
GROUP BY payment_id
HAVING COUNT(*) > 1;
-- No duplicates found

WITH ranked_payments AS (
	SELECT 
		payment_id,
        amount,
        PERCENT_RANK() OVER (ORDER BY amount) AS pct
	FROM payments
),
quartiles AS (
	SELECT
		MAX(CASE WHEN pct <= 0.25 THEN amount END) AS q1,
        MAX(CASE WHEN pct <= 0.75 THEN amount END) AS q3
	FROM ranked_payments
),
iqr_calc AS (
	SELECT 
		q1,
        q3,
        (q3 - q1) AS iqr,
        (q3 + 1.5 * (q3 - q1)) AS upper_bound,
        (q1 - 1.5 * (q3 - q1)) AS lower_bound
	FROM quartiles
)
SELECT 	
	p.payment_id, 
    p.amount,
    ROUND(i.lower_bound, 2) AS iqr_lower_bound,
    ROUND(i.upper_bound, 2) AS iqr_upper_bound
FROM payments p
CROSS JOIN iqr_calc i
WHERE p.amount > i.upper_bound
   OR p.amount < i.lower_bound
ORDER BY p.amount;
-- The payments are skewed on the high end

WITH ranked_payments AS (
	SELECT 
		payment_id,
        amount,
        PERCENT_RANK() OVER (ORDER BY amount) AS pct
	FROM payments
),
quartiles AS (
	SELECT
		MAX(CASE WHEN pct <= 0.25 THEN amount END) AS q1,
        MAX(CASE WHEN pct <= 0.75 THEN amount END) AS q3
	FROM ranked_payments
),
iqr_calc AS (
	SELECT 
		q1,
        q3,
        (q3 - q1) AS iqr,
        (q3 + 3.0 * (q3 - q1)) AS upper_bound,
        (q1 - 3.0 * (q3 - q1)) AS lower_bound
	FROM quartiles
)
SELECT 	
	p.payment_id, 
    p.amount,
    ROUND(i.upper_bound, 2) AS iqr_upper_bound
FROM payments p
CROSS JOIN iqr_calc i
WHERE p.amount > i.upper_bound
   OR p.amount < i.lower_bound
ORDER BY p.amount;

WITH ranked_payments AS (
	SELECT 
		payment_id,
        amount,
        PERCENT_RANK() OVER (ORDER BY amount) AS pct
	FROM payments
),
quartiles AS (
	SELECT
		MAX(CASE WHEN pct <= 0.25 THEN amount END) AS q1,
        MAX(CASE WHEN pct <= 0.75 THEN amount END) AS q3
	FROM ranked_payments
),
iqr_calc AS (
	SELECT 
		q1,
        q3,
        (q3 - q1) AS iqr,
        (q3 + 3.0 * (q3 - q1)) AS upper_bound,
        (q1 - 3.0 * (q3 - q1)) AS lower_bound
	FROM quartiles
)
SELECT 	
	p.payment_id, 
    p.amount as outlier_amount,
    ROUND(i.upper_bound, 2) AS iqr_upper_bound,
    t.trip_id,
    u.user_id,
    u.name
FROM payments p
CROSS JOIN iqr_calc i
INNER JOIN trips t ON p.trip_id = t.trip_id
INNER JOIN riders r ON t.rider_id = r.rider_id
INNER JOIN users u ON r.user_id = u.user_id
WHERE p.amount > i.upper_bound
ORDER BY p.amount;

WITH ranked_payments AS (
	SELECT 
		payment_id,
        amount,
        PERCENT_RANK() OVER (ORDER BY amount) AS pct
	FROM payments
),
quartiles AS (
	SELECT
		MAX(CASE WHEN pct <= 0.25 THEN amount END) AS q1,
        MAX(CASE WHEN pct <= 0.75 THEN amount END) AS q3
	FROM ranked_payments
),
iqr_calc AS (
	SELECT 
        (q3 + 3.0 * (q3 - q1)) AS upper_bound
	FROM quartiles
)
SELECT 	
	u.user_id,
    COUNT(p.amount) AS total_extreme_outliers,
    ROUND(SUM(p.amount), 2) AS total_money_spent_in_outliers,
    ROUND(MAX(p.amount), 2) AS single_highest_payment
FROM payments p
CROSS JOIN iqr_calc i
INNER JOIN trips t ON p.trip_id = t.trip_id
INNER JOIN riders r ON t.rider_id = r.rider_id
INNER JOIN users u ON r.user_id = u.user_id
WHERE p.amount > i.upper_bound
GROUP BY u.user_id
ORDER BY total_extreme_outliers DESC, total_money_spent_in_outliers DESC;
-- There are repeat users who have paid an amount that goes above the upper bound

WITH ranked_payments AS (
	SELECT 
		payment_id,
        amount,
        PERCENT_RANK() OVER (ORDER BY amount) AS pct
	FROM payments
),
quartiles AS (
	SELECT
		MAX(CASE WHEN pct <= 0.25 THEN amount END) AS q1,
        MAX(CASE WHEN pct <= 0.75 THEN amount END) AS q3
	FROM ranked_payments
),
iqr_calc AS (
	SELECT 
        (q3 + 3.0 * (q3 - q1)) AS upper_bound
	FROM quartiles
)
SELECT 	
	p.payment_id, 
    p.amount AS outlier_amount,
    ROUND(i.upper_bound, 2) AS iqr_upper_bound,
    t.trip_id,
    t.distance_km,
    ROUND(p.amount / NULLIF(t.distance_km, 0), 2) AS cost_per_km
FROM payments p
CROSS JOIN iqr_calc i
INNER JOIN trips t ON p.trip_id = t.trip_id
WHERE p.amount > i.upper_bound
ORDER BY cost_per_km DESC;
-- The cost per km seem to be normal, so outliers in payments should not be removed

-- Reviews table
SELECT * FROM reviews LIMIT 5;

SELECT * 
FROM reviews
WHERE CONCAT(review_id, trip_id, reviewer_id, reviewee_id, rating, reviewed_at) IS NULL;
-- Comments may be null, but no nulls are found for other fields

SELECT review_id, COUNT(*) AS occurrence
FROM reviews
GROUP BY review_id
HAVING COUNT(*) > 1;
-- No duplicates found

-- Riders table
SELECT * FROM riders LIMIT 5;

SELECT * 
FROM riders
WHERE CONCAT(rider_id, user_id, rating, total_trips, created_at) IS NULL;
-- No nulls found

SELECT rider_id, COUNT(*) AS occurrence
FROM riders
GROUP BY rider_id
HAVING COUNT(*) > 1;
-- No duplicates found

-- Trips table
SELECT * FROM trips LIMIT 5;

SELECT MAX(trip_id) FROM trips;

SELECT *
FROM trips
WHERE CONCAT(trip_id, rider_id, driver_id, pickup_location_id, dropoff_location_id, requested_at, started_at, completed_at, status, distance_km, duration_mins, base_fare, surge_multiplier, total_fare, payment_method) IS NULL
LIMIT 20000;
-- 3173 rows contain at least a field with a null value

SELECT completed_at, COUNT(*) AS not_completed_trips 
FROM trips 
WHERE completed_at IS NULL
GROUP BY completed_at;
-- All those nulls are from not completed trips

SELECT DISTINCT status
FROM trips;

WITH ranked_payments AS (
	SELECT 
		payment_id,
        amount,
        PERCENT_RANK() OVER (ORDER BY amount) AS pct
	FROM payments
),
quartiles AS (
	SELECT
		MAX(CASE WHEN pct <= 0.25 THEN amount END) AS q1,
        MAX(CASE WHEN pct <= 0.75 THEN amount END) AS q3
	FROM ranked_payments
),
iqr_calc AS (
	SELECT 
		q1,
        q3,
        (q3 - q1) AS iqr,
        (q3 + 3.0 * (q3 - q1)) AS upper_bound,
        (q1 - 3.0 * (q3 - q1)) AS lower_bound
	FROM quartiles
)
SELECT 	
	p.payment_id, 
    p.amount as outlier_amount,
    t.trip_id,
    t.status,
    t.distance_km,
    t.completed_at
FROM payments p
CROSS JOIN iqr_calc i
INNER JOIN trips t ON p.trip_id = t.trip_id
WHERE p.amount > i.upper_bound
	AND t.status IN ("completed")
ORDER BY outlier_amount;
-- 169 rows all include completed trips

CREATE TABLE trips_in_progress AS 
SELECT * FROM trips WHERE status = "in_progress";

DELETE FROM trips
WHERE status = "in_progress";
-- Safely stored "in_progress" status trips in a backup table
-- and deleted those rows from the original database

-- Users table
SELECT * FROM users LIMIT 5;

SELECT * 
FROM users
WHERE CONCAT(user_id, name, email, phone, city, date_joined, is_driver) IS NULL;
-- No nulls found

SELECT user_id, COUNT(*) AS occurrence
FROM users
GROUP BY user_id
HAVING COUNT(*) > 1;
-- No duplicates found