CREATE DATABASE EV;

USE EV;

-- 1. CREATE FACT TABLE 
-- =============================================
CREATE TABLE fact_charging_session (
    session_key BIGINT IDENTITY(1,1) PRIMARY KEY,
    station_key INT NOT NULL,
    customer_key INT NOT NULL,
    vehicle_key INT NOT NULL,
    time_key INT NOT NULL,
    session_start_datetime DATETIME2(3) NOT NULL,
    session_end_datetime DATETIME2(3),
    energy_delivered_kwh DECIMAL(8,3),
    charging_duration_minutes INT,
    peak_power_kw DECIMAL(6,2),
    total_cost DECIMAL(8,2),
    session_status VARCHAR(50)
);

-- Add clustered columnstore index 
CREATE CLUSTERED COLUMNSTORE INDEX CCI_fact_charging_session 
ON fact_charging_session;



-- 2. CREATE DIMENSION TABLES
-- =============================================

-- DIM_STATION Table
CREATE TABLE dim_station (
    station_key INT IDENTITY(1,1) PRIMARY KEY,
    station_id VARCHAR(50) NOT NULL,
    station_name VARCHAR(200),
    operator_name VARCHAR(100),
    connector_type VARCHAR(50),
    max_power_kw DECIMAL(6,2),
    location_address VARCHAR(500),
    city VARCHAR(100),
    country VARCHAR(50),
    latitude DECIMAL(9,6),
    longitude DECIMAL(9,6),
    station_status VARCHAR(50),
    effective_date DATE NOT NULL DEFAULT GETDATE(),
    expiry_date DATE NULL,
    is_current BIT NOT NULL DEFAULT 1
);

-- Indexes for DIM_STATION
CREATE NONCLUSTERED INDEX IX_station_current ON dim_station (station_id, is_current);
CREATE NONCLUSTERED INDEX IX_station_location ON dim_station (latitude, longitude);
CREATE NONCLUSTERED INDEX IX_station_city_country ON dim_station (city, country);


-- DIM_CUSTOMER Table (with SCD Type 2)
CREATE TABLE dim_customer (
    customer_key INT IDENTITY(1,1) PRIMARY KEY,
    customer_id VARCHAR(50) NOT NULL,
    customer_type VARCHAR(50),
    subscription_plan VARCHAR(100),
    registration_date DATE,
    home_country VARCHAR(50),
    customer_segment VARCHAR(50),
    is_business_customer BIT,
    effective_date DATE NOT NULL DEFAULT GETDATE(),
    expiry_date DATE NULL,
    is_current BIT NOT NULL DEFAULT 1
);

-- Indexes for DIM_CUSTOMER
CREATE NONCLUSTERED INDEX IX_customer_current ON dim_customer (customer_id, is_current);
CREATE NONCLUSTERED INDEX IX_customer_segment ON dim_customer (customer_segment);
CREATE NONCLUSTERED INDEX IX_customer_type ON dim_customer (customer_type);



-- DIM_VEHICLE Table
CREATE TABLE dim_vehicle (
    vehicle_key INT IDENTITY(1,1) PRIMARY KEY,
    vehicle_id VARCHAR(50) NOT NULL,
    make VARCHAR(50),
    model VARCHAR(100),
    model_year INT,
    battery_capacity_kwh DECIMAL(6,2),
    max_charging_power_kw DECIMAL(6,2),
    connector_type VARCHAR(50),
    vehicle_category VARCHAR(50)
);

-- Indexes for DIM_VEHICLE
CREATE NONCLUSTERED INDEX IX_vehicle_id ON dim_vehicle (vehicle_id);
CREATE NONCLUSTERED INDEX IX_vehicle_make_model ON dim_vehicle (make, model);
CREATE NONCLUSTERED INDEX IX_vehicle_category ON dim_vehicle (vehicle_category);



-- DIM_TIME Table
CREATE TABLE dim_time (
    time_key INT PRIMARY KEY,
    full_date DATE NOT NULL,
    day_of_week VARCHAR(20),
    day_of_month INT,
    month_number INT,
    month_name VARCHAR(20),
    quarter INT,
    year INT,
    is_weekend BIT,
    is_holiday BIT,
    season VARCHAR(20)
);

-- Indexes for DIM_TIME
CREATE NONCLUSTERED INDEX IX_time_date ON dim_time (full_date);
CREATE NONCLUSTERED INDEX IX_time_year_month ON dim_time (year, month_number);



-- 3. ADD FOREIGN KEY CONSTRAINTS
-- =============================================
ALTER TABLE fact_charging_session 
ADD CONSTRAINT FK_station FOREIGN KEY (station_key) REFERENCES dim_station(station_key);

ALTER TABLE fact_charging_session 
ADD CONSTRAINT FK_customer FOREIGN KEY (customer_key) REFERENCES dim_customer(customer_key);

ALTER TABLE fact_charging_session 
ADD CONSTRAINT FK_vehicle FOREIGN KEY (vehicle_key) REFERENCES dim_vehicle(vehicle_key);

ALTER TABLE fact_charging_session 
ADD CONSTRAINT FK_time FOREIGN KEY (time_key) REFERENCES dim_time(time_key);



-- 4. POPULATE DIM_TIME TABLE (Sample for 2024-2025)
-- =============================================
WITH DateSequence AS (
    SELECT CAST('2024-01-01' AS DATE) AS DateValue
    UNION ALL
    SELECT DATEADD(DAY, 1, DateValue)
    FROM DateSequence
    WHERE DateValue < '2025-12-31'
)
INSERT INTO dim_time (
    time_key, full_date, day_of_week, day_of_month, 
    month_number, month_name, quarter, year, 
    is_weekend, is_holiday, season
)
SELECT 
    CAST(FORMAT(DateValue, 'yyyyMMdd') AS INT) as time_key,
    DateValue as full_date,
    DATENAME(WEEKDAY, DateValue) as day_of_week,
    DAY(DateValue) as day_of_month,
    MONTH(DateValue) as month_number,
    DATENAME(MONTH, DateValue) as month_name,
    DATEPART(QUARTER, DateValue) as quarter,
    YEAR(DateValue) as year,
    CASE WHEN DATEPART(WEEKDAY, DateValue) IN (1, 7) THEN 1 ELSE 0 END as is_weekend,
    0 as is_holiday, -- You can update this later with holiday logic
    CASE 
        WHEN MONTH(DateValue) IN (12, 1, 2) THEN 'Winter'
        WHEN MONTH(DateValue) IN (3, 4, 5) THEN 'Spring'
        WHEN MONTH(DateValue) IN (6, 7, 8) THEN 'Summer'
        ELSE 'Fall'
    END as season
FROM DateSequence
OPTION (MAXRECURSION 1000);



-- 5.  DATA INSERTS
-- =============================================

-- Sample Stations
INSERT INTO dim_station (station_id, station_name, operator_name, connector_type, max_power_kw, city, country, latitude, longitude, station_status)
VALUES 
('STN_DE001', 'Berlin Central Station', 'Elvah GmbH', 'CCS2', 150.0, 'Berlin', 'Germany', 52.5200, 13.4050, 'Active'),
('STN_DE002', 'Munich Airport Hub', 'Elvah GmbH', 'CCS2', 300.0, 'Munich', 'Germany', 48.1351, 11.5820, 'Active'),
('STN_FR001', 'Paris Nord Terminal', 'Elvah France', 'CCS2', 175.0, 'Paris', 'France', 48.8566, 2.3522, 'Active'),
('STN_NL001', 'Amsterdam Port', 'Elvah Nederland', 'CCS2', 250.0, 'Amsterdam', 'Netherlands', 52.3676, 4.9041, 'Active'),
('STN_DE003', 'Hamburg Industrial', 'Elvah GmbH', 'CHAdeMO', 100.0, 'Hamburg', 'Germany', 53.5511, 9.9937, 'Maintenance');

-- Sample Customers
INSERT INTO dim_customer (customer_id, customer_type, subscription_plan, registration_date, home_country, customer_segment, is_business_customer)
VALUES 
('CUST_001', 'Premium', 'Unlimited Monthly', '2024-01-15', 'Germany', 'Frequent User', 0),
('CUST_002', 'Standard', 'Pay Per Use', '2024-02-20', 'France', 'Occasional User', 0),
('CUST_003', 'Business', 'Fleet Enterprise', '2024-01-10', 'Germany', 'Corporate', 1),
('CUST_004', 'Premium', 'Unlimited Annual', '2024-03-05', 'Netherlands', 'Frequent User', 0),
('CUST_005', 'Standard', 'Monthly Basic', '2024-02-28', 'Germany', 'Regular User', 0);

-- Sample Vehicles
INSERT INTO dim_vehicle (vehicle_id, make, model, model_year, battery_capacity_kwh, max_charging_power_kw, connector_type, vehicle_category)
VALUES 
('VEH_001', 'Tesla', 'Model 3', 2024, 75.0, 250.0, 'CCS2', 'Sedan'),
('VEH_002', 'BMW', 'iX3', 2024, 80.0, 150.0, 'CCS2', 'SUV'),
('VEH_003', 'Volkswagen', 'ID.4', 2024, 82.0, 135.0, 'CCS2', 'SUV'),
('VEH_004', 'Audi', 'e-tron GT', 2024, 93.4, 270.0, 'CCS2', 'Sports Car'),
('VEH_005', 'Mercedes', 'EQS', 2024, 107.8, 200.0, 'CCS2', 'Luxury Sedan');

-- Sample Charging Sessions
INSERT INTO fact_charging_session (
    station_key, customer_key, vehicle_key, time_key,
    session_start_datetime, session_end_datetime, energy_delivered_kwh,
    charging_duration_minutes, peak_power_kw, total_cost, session_status
)
VALUES 
(1, 1, 1, 20240915, '2024-09-15 08:30:00', '2024-09-15 09:15:00', 45.2, 45, 135.0, 22.60, 'completed'),
(2, 2, 2, 20240915, '2024-09-15 10:00:00', '2024-09-15 10:40:00', 32.1, 40, 120.0, 18.75, 'completed'),
(3, 3, 3, 20240915, '2024-09-15 14:20:00', '2024-09-15 15:30:00', 58.7, 70, 100.0, 31.20, 'completed'),
(1, 4, 4, 20240916, '2024-09-16 07:45:00', '2024-09-16 08:20:00', 28.4, 35, 150.0, 16.90, 'completed'),
(4, 5, 5, 20240916, '2024-09-16 11:30:00', '2024-09-16 12:45:00', 72.8, 75, 180.0, 42.15, 'completed');



-- 6. CREATE VIEWS FOR COMMON QUERIES
-- =============================================

-- Daily charging summary view
-- Daily charging summary view
GO
CREATE VIEW vw_daily_charging_summary AS
SELECT
    dt.full_date,
    dt.day_of_week,
    COUNT(*)                       AS total_sessions,
    SUM(f.energy_delivered_kwh)     AS total_energy_kwh,
    AVG(f.charging_duration_minutes) AS avg_duration_minutes,
    SUM(f.total_cost)               AS total_revenue,
    COUNT(DISTINCT f.station_key)   AS active_stations,
    COUNT(DISTINCT f.customer_key)  AS unique_customers
FROM fact_charging_session f
JOIN dim_time dt ON f.time_key = dt.time_key
WHERE f.session_status = 'completed'
GROUP BY dt.full_date, dt.day_of_week;
GO


-- Station performance view
GO
CREATE VIEW vw_station_performance AS
SELECT 
    ds.station_id,
    ds.station_name,
    ds.city,
    ds.country,
    COUNT(*) as total_sessions,
    SUM(f.energy_delivered_kwh) as total_energy_delivered,
    AVG(f.energy_delivered_kwh) as avg_energy_per_session,
    SUM(f.total_cost) as total_revenue,
    AVG(f.charging_duration_minutes) as avg_session_duration
FROM fact_charging_session f
JOIN dim_station ds ON f.station_key = ds.station_key
WHERE f.session_status = 'completed'
  AND ds.is_current = 1
GROUP BY ds.station_id, ds.station_name, ds.city, ds.country;
GO


-- 7. PERFORMANCE OPTIMIZATION
-- =============================================

-- Additional indexes for common query patterns
CREATE NONCLUSTERED INDEX IX_fact_charging_time_station 
ON fact_charging_session (time_key, station_key)
INCLUDE (energy_delivered_kwh, charging_duration_minutes, total_cost);

CREATE NONCLUSTERED INDEX IX_fact_charging_customer_date
ON fact_charging_session (customer_key, session_start_datetime)
INCLUDE (energy_delivered_kwh, total_cost, session_status);

CREATE NONCLUSTERED INDEX IX_fact_charging_status_date
ON fact_charging_session (session_status, time_key)
INCLUDE (energy_delivered_kwh, charging_duration_minutes, total_cost);

-- Update statistics for optimal query performance
UPDATE STATISTICS fact_charging_session;
UPDATE STATISTICS dim_station;
UPDATE STATISTICS dim_customer;
UPDATE STATISTICS dim_vehicle;
UPDATE STATISTICS dim_time;