# Hospital Management Database (PostgreSQL)

Relational database design for a private hospital: departments, doctors, patients,
appointments, consultations, prescriptions, rooms, hospitalizations, invoices and payments.

> **Status:** Part 1 of the challenge: conceptual model, relational schema, synthetic data
> and constraint tests. Queries, views, warehouse, security and partitioning are on the roadmap.

![ER diagram](docs/images/er_diagram.png)

## What this project demonstrates
- Turning written business rules into an ER model and a normalized relational schema
- Enforcing rules **inside the database** with PK/FK, UNIQUE, CHECK, NOT NULL and composite FKs
- Testing the design: every rule has a violation test that must fail
- Documenting assumptions and known limitations honestly

## Design highlights
| Business rule | How it is enforced |
|---|---|
| A consultation comes from a **completed** appointment (walk-ins/emergencies allowed) | Composite FK `(appointmentId, patientId, doctorId, status)` plus a CHECK, with no trigger |
| One appointment gives at most one consultation | `UNIQUE` on `consultation.appointmentId` |
| A doctor cannot have two appointments at the same time | `UNIQUE (doctorId, appointment_date_time)` |
| A medication appears in many consultations, with per-consultation dosage | Associative table `prescription_line` |
| An invoice is paid in installments; paid / partial / unpaid | 1:N `invoice` to `payments`, balance computed from completed payments |
| Each billing line matches its type | CHECK on `line_type` vs reference columns |

More detail in [`docs/design_decisions.md`](docs/design_decisions.md).

## How to run
Requires PostgreSQL 14+ and `psql`.

```bash
createdb hospital_db
psql -d hospital_db -f sql/02_create_operational_tables.sql
psql -d hospital_db -f sql/03_indexes.sql
psql -d hospital_db -f sql/04_load_synthetic_data.sql
psql -d hospital_db -f tests/01_appointments_constraints.sql   # prints PASS/FAIL per rule
```

## Documentation
- [Business rules](docs/business_rules.md)
- [Assumptions](docs/assumptions.md)
- [Design decisions](docs/design_decisions.md)
- [Data dictionary](docs/data_dictionary.md)
- [Known limitations](docs/limitations.md)

## Known limitations
- Room capacity is not enforced by constraints (detection query provided).
- Overpayment and "invoice total = sum of lines" are not enforced.
- Same-start-time appointments are blocked, but true time overlaps are not.

## Roadmap
- [x] Conceptual model (ERD)
- [x] Relational schema and constraints
- [x] Synthetic data
- [x] Constraint tests
- [ ] SQL queries (joins, subqueries, CTEs, window functions)
- [ ] Views and materialized views
- [ ] Star and snowflake warehouse, SCD Type 2
- [ ] Roles, permissions and row-level security
- [ ] Partitioning and performance
- [ ] Data quality checks

## Credits
Based on the *Hospital Management Data Engineering Challenge* ([source](PASTE-LINK-HERE)).
All data in this repository is synthetic.
