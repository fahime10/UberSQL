-- Financial Performance

USE uber_db;

-- Surge revenue vs standard trip revenue
SELECT 
	CASE 
		WHEN t.surge_multiplier > 1.0 THEN "Surge Trip"
        ELSE "Standard Trip"
	END AS trip_type,
    COUNT(payment_id) AS total_trips,
    ROUND(SUM(p.amount), 2) AS total_revenue,
    ROUND(AVG(p.amount), 2) AS avg_fare_per_trip
FROM payments p
INNER JOIN trips t ON p.trip_id = t.trip_id
GROUP BY trip_type;
-- This query will only consider the completed trips, as they are the ones that have had a transaction

-- Surge trips vs cancellations
SELECT
	surge_multiplier,
    COUNT(*) AS total_requests,
    SUM(CASE WHEN status = "cancelled" THEN 1 ELSE 0 END) AS total_cancellations,
    ROUND(100.0 * SUM(CASE WHEN status = "cancelled" THEN 1 ELSE 0 END) / COUNT(*), 2) AS cancellation_rate_pct
FROM trips
GROUP BY surge_multiplier
ORDER BY cancellation_rate_pct DESC;
-- There is no real pattern and so cannot conclude whether the moment surge prices are there, the customers tend to cancel the trip

-- Best surge multiplier that yield results
SELECT 
	t.surge_multiplier,
    COUNT(p.payment_id) AS completed_paid_trips,
    ROUND(MAX(p.amount), 2) AS max_payment_amount,
    ROUND(AVG(p.amount), 2) AS avg_payment_amount
FROM payments p
INNER JOIN trips t ON p.trip_id = t.trip_id
WHERE t.status = "completed"
GROUP BY t.surge_multiplier
ORDER BY max_payment_amount DESC
LIMIT 5;
-- The best multiplier are towards the high end of the data

-- Breakdown of gross vs lost revenue from cancelled trips
SELECT 
	t.status,
    COUNT(t.trip_id) AS total_trips,
    ROUND(COALESCE(SUM(p.amount), 0), 2) AS total_realized_revenue,
    ROUND(SUM(t.total_fare), 2) AS total_expected_fare,
    ROUND(SUM(t.total_fare - COALESCE(p.amount, 0)), 2) AS lost_revenue,
    ROUND(100.0 * SUM(t.total_fare - COALESCE(p.amount, 0)) / NULLIF(SUM(t.total_fare), 0), 2) AS revenue_loss_pct
FROM trips t
LEFT JOIN payments p ON t.trip_id = p.trip_id
GROUP BY t.status;
-- Cancelled trips do not yield any revenue

-- Base fare vs Surge Fare
SELECT 
	ROUND(SUM(t.base_fare), 2) AS total_base_revenue,
    ROUND(SUM(t.total_fare - t.base_fare), 2) AS total_surge_revenue,
    ROUND(100.0 * SUM(t.base_fare) / NULLIF(SUM(t.total_fare), 0), 2) as base_fare_pct,
    ROUND(100.0 * SUM(t.total_fare - t.base_fare) / NULLIF(SUM(t.total_fare), 0), 2) AS surge_fare_pct
    FROM trips t
    INNER JOIN payments p ON t.trip_id = p.trip_id
    WHERE t.status = "completed";
    -- Base fares yield more revenue than surge pricing, by about 80%
    
    -- Revenue yield per kilometre
    SELECT 
		CASE 
			WHEN t.distance_km < 3 THEN "Very Short (Less than 3km)"
            WHEN t.distance_km BETWEEN 3 AND 10 THEN "Short (3-10km)"
            WHEN t.distance_km BETWEEN 10.01 AND 25 THEN "Medium (10-25km)"
            ELSE "Long (More than 25km)"
		END AS distance_bucket,
        COUNT(p.payment_id) AS total_trips,
        ROUND(SUM(p.amount), 2) AS total_revenue,
        ROUND(AVG(p.amount / NULLIF(t.distance_km, 0)), 2) AS avg_revenue_per_km
FROM payments p
INNER JOIN trips t ON p.trip_id = t.trip_id
WHERE t.status = "completed" AND t.distance_km > 0
GROUP BY distance_bucket
ORDER BY distance_bucket;
-- Shorter trips yield more revenue (4.64 on average)

-- Payment method revenue distribution
SELECT
	p.method,
    COUNT(p.payment_id) AS total_transactions,
    ROUND(SUM(p.amount), 2) AS total_revenue,
    ROUND(AVG(p.amount), 2) AS avg_transaction_value,
    ROUND(100.0 * SUM(p.amount) / SUM(SUM(p.amount)) OVER (), 2) AS revenue_share_pct
FROM payments p
INNER JOIN trips t ON p.trip_id = t.trip_id
WHERE t.status = "completed"
GROUP BY p.method
ORDER BY total_revenue DESC;
-- All payment methods are distributed evenly to some extent