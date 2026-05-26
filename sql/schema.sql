CREATE TABLE fact_sales (
    sales_id SERIAL PRIMARY KEY,
    date_id DATE,
    store_id INT,
    dept_id INT,
    weekly_sales NUMERIC(10,2),
    is_holiday BOOLEAN,
    temperature NUMERIC,
    fuel_price NUMERIC,
    cpi NUMERIC,
    unemployment NUMERIC,
    markdown1 NUMERIC,
    markdown2 NUMERIC,
    markdown3 NUMERIC,
    markdown4 NUMERIC,
    markdown5 NUMERIC,
);

CREATE TABLE dim_store (
    store_id INT PRIMARY KEY,
    store_type VARCHAR(10),
    size INT
);

CREATE TABLE dim_date (
    date_id DATE PRIMARY KEY,
    year INT,
    month INT,
    day INT,
    week INT,
    weekday INT,
    is_weekend BOOLEAN
);




ALTER TABLE fact_sales
ADD CONSTRAINT fk_date
FOREIGN KEY (date_id)
REFERENCES dim_date(date_id);

ALTER TABLE fact_sales
ADD CONSTRAINT fk_store
FOREIGN KEY (store_id)
REFERENCES dim_store(store_id);
