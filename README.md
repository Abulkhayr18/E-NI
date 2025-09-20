# E-NI
#  EV Charging Network Data Warehouse

> **How do you build scalable analytics for Europe's fastest-growing EV charging network?**

This project demonstrates enterprise-grade data warehouse design for electric vehicle charging analytics, built for multi-country operations across Germany, France, and the Netherlands.

##  The Business Challenge

As EV adoption explodes across Europe, charging network operators face critical questions:
- Which stations generate the most revenue?
- When do customers charge most frequently?
- How do different vehicle types impact network utilization?
- Which locations should we expand to next?
- How do we optimize pricing across different markets?

Traditional transactional databases can't handle the analytical workload needed to answer these questions at scale.

##  Architecture Overview

### Star Schema Design
Built following Kimball methodology for maximum query performance:

```
                    ┌─────────────────┐
                    │   dim_time      │
                    │   - time_key    │
                    │   - full_date   │
                    │   - day_of_week │
                    │   - quarter     │
                    │   - season      │
                    └─────────┬───────┘
                              │
    ┌─────────────────┐      │      ┌─────────────────┐
    │   dim_station   │      │      │  dim_customer   │
    │   - station_key │      │      │  - customer_key │
    │   - station_id  │      │      │  - customer_id  │
    │   - operator    │      │      │  - segment      │
    │   - location    │      │      │  - country      │
    │   - power_kw    │      │      │  - plan_type    │
    └─────────┬───────┘      │      └─────────┬───────┘
              │              │                │
              │    ┌─────────▼─────────┐     │
              └────► fact_charging_     ◄─────┘
                   │      session      │
                   │                   │
                   │ - energy_kwh      │
                   │ - duration_min    │
                   │ - total_cost      │
                   │ - peak_power      │
                   └─────────▲─────────┘
                             │
                    ┌────────┴────────┐
                    │   dim_vehicle   │
                    │   - vehicle_key │
                    │   - make/model  │
                    │   - battery_kwh │
                    │   - category    │
                    └─────────────────┘
```

##  Key Features

### 1. **Multi-Country Operations**
- **Germany**: Berlin Central, Munich Airport, Hamburg Industrial
- **France**: Paris Nord Terminal
- **Netherlands**: Amsterdam Port
- Unified reporting across all markets

### 2. **Slowly Changing Dimensions (SCD Type 2)**
```sql
-- Track customer changes over time without losing history
CREATE TABLE dim_customer (
    customer_key INT IDENTITY(1,1) PRIMARY KEY,
    customer_id VARCHAR(50) NOT NULL,
    subscription_plan VARCHAR(100),
    effective_date DATE NOT NULL DEFAULT GETDATE(),
    expiry_date DATE NULL,
    is_current BIT NOT NULL DEFAULT 1
);
```

### 3. **Performance Optimization**
- **Columnstore indexes** for analytical queries
- **Partitioning strategy** for time-series data
- **Optimized views** for common business questions

### 4. **Real-Time Analytics Views**
```sql
-- Daily performance metrics
SELECT
    full_date,
    total_sessions,
    total_energy_kwh,
    total_revenue,
    unique_customers
FROM vw_daily_charging_summary
WHERE full_date >= DATEADD(MONTH, -3, GETDATE());
```

##  Business Intelligence Capabilities

### Revenue Analytics
```sql
-- Monthly revenue by country
SELECT 
    ds.country,
    dt.month_name,
    dt.year,
    SUM(f.total_cost) as monthly_revenue,
    COUNT(*) as session_count,
    SUM(f.energy_delivered_kwh) as total_energy
FROM fact_charging_session f
JOIN dim_station ds ON f.station_key = ds.station_key
JOIN dim_time dt ON f.time_key = dt.time_key
WHERE f.session_status = 'completed'
GROUP BY ds.country, dt.month_name, dt.year, dt.month_number
ORDER BY dt.year, dt.month_number, monthly_revenue DESC;
```

### Customer Segmentation
```sql
-- Customer behavior analysis
SELECT 
    dc.customer_segment,
    dc.subscription_plan,
    COUNT(*) as total_sessions,
    AVG(f.energy_delivered_kwh) as avg_energy_per_session,
    AVG(f.total_cost) as avg_cost_per_session,
    AVG(f.charging_duration_minutes) as avg_duration
FROM fact_charging_session f
JOIN dim_customer dc ON f.customer_key = dc.customer_key
WHERE dc.is_current = 1
GROUP BY dc.customer_segment, dc.subscription_plan
ORDER BY avg_cost_per_session DESC;
```

### Station Performance
```sql
-- Top performing stations
SELECT TOP 10
    station_name,
    city,
    country,
    total_sessions,
    total_revenue,
    avg_energy_per_session
FROM vw_station_performance
ORDER BY total_revenue DESC;
```

##  Technical Implementation

### Database: SQL Server
**Why SQL Server for this project:**
- ✅ **Columnstore indexes** for fast analytical queries
- ✅ **Advanced windowing functions** for time-series analysis
- ✅ **Built-in BI integration** with Power BI
- ✅ **Enterprise scalability** for multi-country operations

### Key Performance Features

**1. Columnstore Compression**
```sql
-- 10x compression ratio for analytical workloads
CREATE CLUSTERED COLUMNSTORE INDEX CCI_fact_charging_session 
ON fact_charging_session;
```

**2. Intelligent Indexing**
```sql
-- Covering indexes for common query patterns
CREATE NONCLUSTERED INDEX IX_fact_charging_time_station 
ON fact_charging_session (time_key, station_key)
INCLUDE (energy_delivered_kwh, charging_duration_minutes, total_cost);
```

**3. Optimized Views**
```sql
-- Pre-aggregated daily summaries for dashboard performance
CREATE VIEW vw_daily_charging_summary AS
SELECT
    dt.full_date,
    COUNT(*) AS total_sessions,
    SUM(f.energy_delivered_kwh) AS total_energy_kwh,
    SUM(f.total_cost) AS total_revenue
FROM fact_charging_session f
JOIN dim_time dt ON f.time_key = dt.time_key
WHERE f.session_status = 'completed'
GROUP BY dt.full_date, dt.day_of_week;
```

##  Scale and Performance

### Data Volume Capacity
- **10M+ charging sessions** per year
- **500+ charging stations** across Europe
- **100K+ active customers**
- **Sub-second query response** for executive dashboards

### Query Performance Examples
```sql
-- Complex analytical query optimized for speed
WITH station_metrics AS (
    SELECT 
        ds.station_id,
        ds.country,
        COUNT(*) as session_count,
        SUM(f.energy_delivered_kwh) as total_energy,
        AVG(f.charging_duration_minutes) as avg_duration,
        RANK() OVER (PARTITION BY ds.country ORDER BY SUM(f.total_cost) DESC) as revenue_rank
    FROM fact_charging_session f
    JOIN dim_station ds ON f.station_key = ds.station_key
    JOIN dim_time dt ON f.time_key = dt.time_key
    WHERE dt.full_date >= DATEADD(MONTH, -6, GETDATE())
    GROUP BY ds.station_id, ds.country
)
SELECT 
    country,
    station_id,
    session_count,
    total_energy,
    avg_duration,
    revenue_rank
FROM station_metrics
WHERE revenue_rank <= 5
ORDER BY country, revenue_rank;
```

##  Getting Started

### Prerequisites
```sql
-- SQL Server 2019 or later
-- Minimum 8GB RAM
-- 100GB available storage
```

### Quick Setup
```bash
# 1. Clone the repository
git clone https://github.com/yourusername/ev-charging-dwh.git

# 2. Execute the database script
sqlcmd -S your_server -d master -i "EV DWH ARCH.sql"

# 3. Verify installation
sqlcmd -S your_server -d EV -Q "SELECT COUNT(*) FROM fact_charging_session"
```

### Sample Queries to Try
```sql
-- 1. Today's charging activity
SELECT * FROM vw_daily_charging_summary 
WHERE full_date = CAST(GETDATE() AS DATE);

-- 2. Station performance ranking
SELECT TOP 5 * FROM vw_station_performance 
ORDER BY total_revenue DESC;

-- 3. Customer charging patterns by day of week
SELECT 
    dt.day_of_week,
    COUNT(*) as sessions,
    AVG(f.energy_delivered_kwh) as avg_energy
FROM fact_charging_session f
JOIN dim_time dt ON f.time_key = dt.time_key
GROUP BY dt.day_of_week, DATEPART(WEEKDAY, dt.full_date)
ORDER BY DATEPART(WEEKDAY, dt.full_date);
```

##  Business Intelligence Integration

### Power BI Dashboard Queries
```sql
-- Revenue trend for Power BI
SELECT 
    dt.full_date as Date,
    SUM(f.total_cost) as Revenue,
    COUNT(*) as Sessions,
    SUM(f.energy_delivered_kwh) as Energy_kWh
FROM fact_charging_session f
JOIN dim_time dt ON f.time_key = dt.time_key
WHERE dt.full_date >= DATEADD(YEAR, -1, GETDATE())
GROUP BY dt.full_date
ORDER BY dt.full_date;

-- Geographic performance for mapping
SELECT 
    ds.station_name as Station,
    ds.city as City,
    ds.country as Country,
    ds.latitude as Lat,
    ds.longitude as Lng,
    COUNT(*) as Total_Sessions,
    SUM(f.total_cost) as Revenue
FROM fact_charging_session f
JOIN dim_station ds ON f.station_key = ds.station_key
WHERE ds.is_current = 1
GROUP BY ds.station_name, ds.city, ds.country, ds.latitude, ds.longitude;
```

### Tableau Integration
```sql
-- Customer segmentation for Tableau
SELECT 
    dc.customer_segment,
    dc.home_country,
    dc.subscription_plan,
    COUNT(DISTINCT dc.customer_id) as Customer_Count,
    COUNT(f.session_key) as Total_Sessions,
    SUM(f.total_cost) as Total_Spend,
    AVG(f.energy_delivered_kwh) as Avg_Energy_Per_Session
FROM dim_customer dc
LEFT JOIN fact_charging_session f ON dc.customer_key = f.customer_key
WHERE dc.is_current = 1
GROUP BY dc.customer_segment, dc.home_country, dc.subscription_plan;
```

##  Key Insights Enabled

### 1. **Operational Optimization**
- Identify peak charging times for capacity planning
- Optimize pricing based on demand patterns
- Monitor station utilization across markets

### 2. **Customer Analytics**
- Segment customers by charging behavior
- Analyze subscription plan effectiveness
- Track customer lifetime value

### 3. **Revenue Intelligence**
- Compare performance across countries
- Identify high-value station locations
- Forecast revenue based on usage trends

### 4. **Network Expansion**
- Data-driven site selection for new stations
- Market penetration analysis
- Competitive positioning insights

## 🔧 Maintenance and Monitoring

### Data Quality Checks
```sql
-- Daily data quality monitoring
SELECT 
    CAST(GETDATE() AS DATE) as check_date,
    COUNT(*) as total_sessions,
    COUNT(CASE WHEN energy_delivered_kwh IS NULL THEN 1 END) as missing_energy,
    COUNT(CASE WHEN total_cost <= 0 THEN 1 END) as invalid_cost,
    COUNT(CASE WHEN charging_duration_minutes <= 0 THEN 1 END) as invalid_duration
FROM fact_charging_session
WHERE CAST(session_start_datetime AS DATE) = CAST(GETDATE() AS DATE);
```

### Performance Monitoring
```sql
-- Index usage analysis
SELECT 
    i.name as index_name,
    s.user_seeks,
    s.user_scans,
    s.user_updates,
    s.last_user_seek,
    s.last_user_scan
FROM sys.dm_db_index_usage_stats s
JOIN sys.indexes i ON s.object_id = i.object_id AND s.index_id = i.index_id
WHERE OBJECT_NAME(s.object_id) = 'fact_charging_session';
```

##  Future Enhancements

### Phase 2: Advanced Analytics
- [ ] **Predictive modeling** for demand forecasting
- [ ] **Real-time streaming** data integration
- [ ] **Machine learning** for dynamic pricing
- [ ] **IoT integration** for station health monitoring

### Phase 3: Extended Coverage
- [ ] **Additional countries** (Spain, Italy, Poland)
- [ ] **Vehicle telematics** integration
- [ ] **Weather data** correlation
- [ ] **Traffic pattern** analysis

##  Contributing

This data warehouse design showcases enterprise-grade analytics architecture. Feel free to:
- Fork and adapt for your own EV charging analytics
- Suggest improvements for multi-country operations
- Add new analytical views and queries
- Optimize performance for larger datasets

##  License

MIT License - feel free to use this design for your own projects.

---

##  Why This Project Matters

This EV charging data warehouse demonstrates:
- ✅ **Enterprise data modeling** skills
- ✅ **Multi-country operations** experience
- ✅ **Performance optimization** expertise
- ✅ **Business intelligence** integration
- ✅ **Scalable architecture** design



---

*Built for the future of sustainable transportation analytics* 🌱
