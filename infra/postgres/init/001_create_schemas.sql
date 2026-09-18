CREATE SCHEMA IF NOT EXISTS ecommerce;
CREATE SCHEMA IF NOT EXISTS analytics_staging;
CREATE SCHEMA IF NOT EXISTS analytics_intermediate;
CREATE SCHEMA IF NOT EXISTS analytics_marts;

COMMENT ON SCHEMA ecommerce IS
    'Synthetic operational sources used by ATOrders.';

COMMENT ON SCHEMA analytics_staging IS
    'Standardized source models created by dbt.';

COMMENT ON SCHEMA analytics_intermediate IS
    'Reusable business transformations created by dbt.';

COMMENT ON SCHEMA analytics_marts IS
    'Analytics-ready dimensions, facts, and marts.';