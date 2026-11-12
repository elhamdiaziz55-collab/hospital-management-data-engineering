# Hospital Management: Data Engineering Project

A full-stack database project built in PostgreSQL that takes a private
hospital's business requirements from concept to a secure, analytics-ready
data platform. All data is synthetic.

## What this project covers

| Stage | What I built |
|---|---|
| Conceptual & relational design | ERD with cardinalities, assumptions, 3NF schema, key and constraint choices |
| Operational database | DDL with PK/FK/CHECK constraints, indexes, and synthetic data covering edge cases (no-shows, partial payments, multi-installment invoices) |
| SQL analytics | Joins, subqueries, CTEs, window functions, date logic, reusable views and materialized views |
| Data warehouse | Star and snowflake schemas with defined fact grains, surrogate keys, role-playing date dimensions, and an SCD Type 2 dimension |
| ETL & validation | Dimension-first loads, incremental strategy, late-arriving data, source-to-warehouse reconciliation |
| Security | Group and login roles, least-privilege grants, REVOKE tests, row-level security policies |
| Performance | Range partitioning by month, partition pruning shown with EXPLAIN ANALYZE, maintenance and retention |
| Data quality & insights | Anomaly detection with remediation rules, plus management KPIs (revenue vs. collections, cancellation rate, length of stay, seasonality) |

## Key design decisions
- *(e.g., doctors belong to one department; transfers tracked via SCD2)*
- *(e.g., room assignments modeled as an associative table over time)*
- *(e.g., payments modeled as installments tied to one invoice)*

## Tech stack
PostgreSQL · pgAdmin/DBeaver · diagrams.net / ERDPlus

## Repository structure
See `/sql`, `/docs`, and `/data` — scripts are numbered and run in order.

## How to run
1. Run `sql/01_...` through `sql/15_...` in sequence
2. See `docs/assumptions.md` for business-rule interpretations
