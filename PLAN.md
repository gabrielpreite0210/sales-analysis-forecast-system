# Retail Revenue Intelligence - Refactoring Plan

## Core Business Question

Can historical sales patterns and contextual variables be used to:

1. forecast future retail demand

2. identify stores and departments showing abnormal sales deterioration (risk score)

3. explain the main factors associated with that deterioration?

---

## Project Layers

### 1. Descriptive Analytics

Understand:

- revenue concentration

- store performance

- department performance

- seasonality

- volatility

- holiday behavior

### 2. Statistical Analysis

Evaluate:

- holiday vs non-holiday sales

- differences across store types

- associations between contextual variables and sales

- practical significance vs statistical significance

### 3. Forecasting

Compare:

- Naive forecast

- Seasonal Naive forecast

- Moving Average baseline

- Prophet

- Machine Learning forecasting model

Evaluation must use temporal validation.

### 4. Revenue Risk / Early Warning

Define sales deterioration and identify:

- stores at risk

- departments at risk

- unusual negative deviations from expected sales

- persistent declining trends

### 5. Explainability

Explain why a store/department receives a high-risk prediction.

### 6. Decision Product

Expose results through:

- Power BI executive dashboard

- interactive web application

- business-oriented README

---

## Planned  Phases

- 1 — Data audit

- 2 — Preprocessing review

- 3 — Feature engineering

- 4 — Forecast baselines

- 5 — Temporal validation

- 6 — Advanced forecasting model

- 7 — Risk definition

- 8— Early-warning model

- 9 — Explainability

- 10 — Power BI redesign

- 11 — Web app redesign

- 12 — Testing and reproducibility

- 13 — README and portfolio packaging