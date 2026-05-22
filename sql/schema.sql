CREATE TABLE fact_sales (
    sales_id SERIAL PRIMARY KEY,
    date_id DATE,
    store_id INT,
    product_id INT,
    units_sold INT,
    sales_amount NUMERIC(10,2)
);

CREATE TABLE dim_product (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(100),
    category VARCHAR(50),
    subcategory VARCHAR(50)
);

CREATE TABLE dim_store(
    store_id INT PRIMARY KEY,
    region VARCHAR(50),
    store_type VARCHAR(50)
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

ALTER TABLE fact_sales
ADD CONSTRAINT fk_product
FOREIGN KEY (product_id)
REFERENCES dim_product(product_id);
