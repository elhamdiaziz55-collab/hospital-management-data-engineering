# Hospital Management Database (PostgreSQL)

![PostgreSQL](https://img.shields.io/badge/PostgreSQL-14%2B-336791?logo=postgresql&logoColor=white)

A data engineering mini-project built around one realistic domain: a private hospital
that manages departments, doctors, patients, appointments, consultations, prescriptions,
rooms, hospitalizations, invoices and payments.

The project goes from written business rules to a complete data platform, and is meant to
demonstrate hands-on skills in both **OLTP** and **OLAP** systems with PostgreSQL:

- **OLTP:** designing and implementing a normalized operational database, with business
  rules enforced by keys, constraints and composite foreign keys
- **SQL for analytics:** joins, aggregations, subqueries to
  answer management questions
- **Views:** normal and materialized views as a reusable analytics layer
- **OLAP:** dimensional modeling with star and snowflake schemas, built from the
  operational source
- **Access control:** roles, privileges and least-privilege design
- **Performance:** table partitioning for large time-based tables

## Contents
- [Documentation](#documentation)
- [ER diagram](#er-diagram)
- [Database overview](#database-overview)
- [Design highlights](#design-highlights)
- [How to run](#how-to-run)
- [Known limitations](#known-limitations)
- [Credits](#credits)

## Documentation

| Document | Content |
|---|---|
| [`docs/ER_MODEL.png`](docs/ER_MODEL.png) | Entity-relationship diagram of the operational database |
| [`docs/business_rules.md`](docs/business_rules.md) | Every business rule enforced by the schema, with the constraint that enforces it |
| [`docs/operational_database_schema.sql`](docs/operational_database_schema.sql) | Full PostgreSQL schema: tables, keys and constraints |

## ER diagram

![ER diagram of the hospital database](docs/ER_MODEL.png)

## Database overview

12 tables in 5 functional areas:

| Area | Tables |
|---|---|
| Organization | `departments`, `doctors` |
| Patients and scheduling | `patients`, `appointments` |
| Clinical | `consultation`, `medications`, `prescription_line` |
| Inpatient | `room`, `hospitalization` |
| Billing | `invoice`, `billing_line`, `payment` |

## Design highlights

The main idea is to enforce business rules **inside the database** (keys, CHECKs and
composite foreign keys), not only in application code. The full list is in
[`docs/business_rules.md`](docs/business_rules.md).

| Business rule | How it is enforced |
|---|---|
| A consultation comes from a **completed** appointment; walk-ins and emergencies are allowed | Composite FK `(appointmentId, patientId, doctorId, status)` plus a CHECK, with no trigger |
| The consultation has the same patient and doctor as its appointment | The same composite FK |
| One appointment gives at most one consultation | `UNIQUE` on `consultation.appointmentId` |
| A doctor cannot have two appointments starting at the same time | `UNIQUE (doctorId, appointment_date_time)` |
| A medication appears in many consultations, with its own dosage each time | Associative table `prescription_line` |
| A private room holds exactly one patient | CHECK on `room_type` and `capacity` |
| A stay has a discharge date if and only if it is discharged | CHECK on `status` and `discharge_datetime` |
| An invoice can be paid in several installments | 1:N `invoice` to `payment` |
| Each billing line references only what matches its type | CHECK on `line_type` and the reference columns |

## How to run

Requires PostgreSQL 14+ and `psql`.

```bash
createdb hospital_db
psql -d hospital_db -f docs/operational_database_schema.sql
```

Then check the tables with `\dt` in `psql`.

## Known limitations

These rules are not enforced by constraints, because a `CHECK`, `UNIQUE` or foreign key
only sees one row or one key and cannot count or sum other rows. They require
**triggers**, which I have not learned yet.

| Limitation | Why a constraint cannot enforce it | Planned solution |
|---|---|---|
| **Room capacity:** a room can receive more patients than its capacity | Needs to count the patients in the room at a given time | Trigger on `hospitalization` |
| **Overpayment:** completed payments can exceed the invoice total | Needs to sum the other payments of the invoice | Trigger on `payment` |
| **Invoice total** is not checked against the sum of its billing lines | Needs to sum rows from another table | Trigger on `billing_line` |
| **Invoice status** is stored, so it can drift from the real payments | Needs to be recalculated each time a payment changes | Trigger on `payment` (or a computed view) |




# SQL queries

Queries on the operational hospital database, grouped by topic.
Techniques used: SELECT/WHERE, aggregation, JOINs, subqueries, EXISTS, CASE.


## D1. Basic SELECT and filtering

**1. Retrieve all registered patients.**
```sql
select * from patients;
```

**2. Display each doctor's name and specialty.**
```sql
select name, specialty from doctors;
```

**3. Find patients born after 1 January 2000.**
```sql
select patientId, name, dateOfBirth
from patients
where dateOfBirth > '2000-01-01';
```

**4. Find confirmed appointments.**
```sql
select * from appointments
where status = 'confirmed';
```


**5. Display the most recent appointments first.**
```sql
select * from appointments
order by appointment_date_time desc;
```

**6. Find appointments within a specified date range (all of November 2026).**
```sql
select * from appointments
where appointment_date_time >= '2026-11-01'
  and appointment_date_time <  '2026-12-01'
order by appointment_date_time;
```

**7. Find patients whose phone number is missing.**
```sql
select patientId, name
from patients
where contact_details is null;
```
Assumption: the schema has no separate phone column, so missing contact details is used as the missing phone.

---

## D2. Aggregation

**1. Count all registered patients.**
```sql
select count(*) as nb_patients from patients;
```


**2. Count appointments by status.**
```sql
select status, count(*) as nb_appointments
from appointments
group by status
order by nb_appointments desc;
```

**4. Count doctors in each department.**
```sql
select d.name as department, count(doc.doctorId) as nb_doctors
from departments d
left join doctors doc on doc.codeDep = d.codeDep
group by d.codeDep, d.name
order by nb_doctors desc;
```
The `left join` keeps departments that have no doctors (count 0).

**5. Find departments with more than three doctors.**
```sql
select d.name as department, count(doc.doctorId) as nb_doctors
from departments d
left join doctors doc on doc.codeDep = d.codeDep
group by d.codeDep, d.name
having count(doc.doctorId) > 3;
```

**6. Calculate appointment count per doctor, including doctors with zero appointments.**
```sql
select doc.doctorId, doc.name, count(a.appointmentId) as nb_appointments
from doctors doc
left join appointments a on a.doctorId = doc.doctorId
group by doc.doctorId, doc.name
order by nb_appointments desc;
```

**7. Calculate total payments received per month.**
```sql
select date_trunc('month', payment_date) as month,
       sum(amount) as total_received
from payment
where status = 'completed'
group by date_trunc('month', payment_date)
order by month;
```
Only `completed` payments count as received. Pending, failed and refunded payments are excluded.

**8. Find patients with more than two appointments.**
```sql
select p.patientId, p.name, count(a.appointmentId) as nb_appointments
from patients p
join appointments a on a.patientId = p.patientId
group by p.patientId, p.name
having count(a.appointmentId) > 2;
```

---

## D3. JOINs

**1. Display appointments with patient and doctor names.**
```sql
select a.appointmentId, a.appointment_date_time, a.status,
       p.name as patient, d.name as doctor
from appointments a
join patients p on p.patientId = a.patientId
join doctors  d on d.doctorId  = a.doctorId
order by a.appointment_date_time;
```

**2. Display doctors with their department names.**
```sql
select doc.doctorId, doc.name as doctor, doc.specialty, dep.name as department
from doctors doc
join departments dep on dep.codeDep = doc.codeDep;
```

**3. Retrieve consultations with patient and doctor details.**
```sql
select c.consultationId, c.consultation_type, c.consult_datetime,
       p.name as patient, d.name as doctor, d.specialty,
       c.symptoms, c.diagnosis
from consultation c
join patients p on p.patientId = c.patientId
join doctors  d on d.doctorId  = c.doctorId
order by c.consult_datetime;
```

**4. Display hospitalization records with room information.**
```sql
select h.patientId, h.admission_datetime, h.discharge_datetime, h.status,
       r.room_number, r.room_type, r.capacity
from hospitalization h
join room r on r.roomId = h.roomId
order by h.admission_datetime;
```

**5. Display invoices with patient names.**
```sql
select i.invoiceId, i.invoice_number, p.name as patient,
       i.issue_date, i.due_date, i.status, i.total_amount
from invoice i
join patients p on p.patientId = i.patientId;
```

**6. Find patients who have never made an appointment.**
```sql
select p.patientId, p.name
from patients p
left join appointments a on a.patientId = p.patientId
where a.appointmentId is null;
```

**7. Find doctors who have never had an appointment.**
```sql
select d.doctorId, d.name
from doctors d
left join appointments a on a.doctorId = d.doctorId
where a.appointmentId is null;
```

**8. List each consultation and its prescribed medication lines.**
```sql
select c.consultationId, c.consult_datetime,
       m.name as medication, pl.dosage, pl.frequency,
       pl.duration_days, pl.quantity
from consultation c
join prescription_line pl on pl.consulationId = c.consultationId
join medications m        on m.medicationId   = pl.medicationId
order by c.consultationId, m.name;
```


## D4. Subqueries and set logic

**1. Find doctors whose appointment count is above the average across doctors.**
```sql
select doc.doctorId, doc.name, count(a.appointmentId) as nb_appointments
from doctors doc
left join appointments a on a.doctorId = doc.doctorId
group by doc.doctorId, doc.name
having count(a.appointmentId) > (
    select avg(t.nb)
    from (
        select count(a2.appointmentId) as nb
        from doctors d2
        left join appointments a2 on a2.doctorId = d2.doctorId
        group by d2.doctorId
    ) t
);
```
The inner query counts appointments per doctor (doctors with zero included). The middle query averages those counts. The outer query keeps the doctors above that average.


**2. Find patients with more appointments than the average patient.**
```sql
select p.patientId, p.name, count(a.appointmentId) as nb_appointments
from patients p
left join appointments a on a.patientId = p.patientId
group by p.patientId, p.name
having count(a.appointmentId) > (
    select avg(t.nb)
    from (
        select count(a2.appointmentId) as nb
        from patients p2
        left join appointments a2 on a2.patientId = p2.patientId
        group by p2.patientId
    ) t
);
```

**3. Find the invoice with the highest total amount.**
```sql
select invoiceId, invoice_number, total_amount
from invoice
where total_amount = (select max(total_amount) from invoice);
```

**4. Find patients who have never received a consultation.**
```sql
select p.patientId, p.name
from patients p
where not exists (
    select 1 from consultation c
    where c.patientId = p.patientId
);
```

**5. Use EXISTS to identify patients with at least one unpaid invoice.**
```sql
select p.patientId, p.name
from patients p
where exists (
    select 1 from invoice i
    where i.patientId = p.patientId
      and i.status = 'unpaid'
);
```

## D5. CASE expressions

**1. Classify invoices as Paid, Partially Paid or Unpaid (total vs successful payments).**
```sql
select i.invoiceId, i.invoice_number, i.total_amount,
       coalesce(sum(p.amount), 0) as paid_amount,
       case
           when coalesce(sum(p.amount), 0) = 0              then 'Unpaid'
           when coalesce(sum(p.amount), 0) < i.total_amount then 'Partially Paid'
           else 'Paid'
       end as payment_status
from invoice i
left join payment p on p.invoiceId = i.invoiceId
                   and p.status = 'completed'
group by i.invoiceId, i.invoice_number, i.total_amount
order by i.invoiceId;
```
But also i prefer doing it with subqueries , this is another method :

```sql
select t.invoice_number,
       t.total_amount,
       t.paid_amount,
       case
           when t.paid_amount = 0                then 'UNPAID'
           when t.paid_amount >= t.total_amount  then 'PAID'
           else 'PARTIALLY PAID'
       end as calculated_status
from (
    select i.invoice_number,
           i.total_amount,
           (select coalesce(sum(p.amount), 0)
            from payments p
            where p.invoiceId = i.invoiceId
              and p.status = 'completed') as paid_amount
    from invoice i
) t;
```

**2. Classify patients by age: Minor (under 18), Adult (18 to 60), Senior (over 60).**
```sql
select patientId, name, dateOfBirth,
       extract(year from age(dateOfBirth)) as age,
       case
           when extract(year from age(dateOfBirth)) < 18  then 'Minor'
           when extract(year from age(dateOfBirth)) <= 60 then 'Adult'
           else 'Senior'
       end as age_group
from patients;
```

**3. Create a readable label for each appointment status.**
```sql
select appointmentId, appointment_date_time, status,
       case status
           when 'scheduled' then 'Scheduled, not yet confirmed'
           when 'confirmed' then 'Confirmed by the patient'
           when 'completed' then 'Visit completed'
           when 'cancelled' then 'Cancelled'
           when 'no-show'   then 'Patient did not show up'
           else 'Unknown status'
       end as status_label
from appointments;
```

# Part E: Views and Reusable Analytics


| Situation | Choice | Reason |
|---|---|---|
| Data changes constantly and results must be current | **Normal view** | Runs the query on every read, so it is always up to date |
| Query is expensive, read often, small staleness is acceptable | **Materialized view** | Stores the result on disk, so reads are fast until the next refresh |

Appointments and invoices are transactional (OLTP) data: bookings, cancellations and payments happen all day, so they use normal views. Consultation history and revenue aggregates are read far more than they change, so they use materialized views.

## 3. Views at a glance

| View | Type | Grain | Purpose |
|---|---|---|---|
| `doctor_appointment_summary` | Normal | doctor + appointment status | Doctor workload, including doctors with no appointments |
| `patient_history` | Materialized | consultation | Consultation history per patient |
| `monthly_appointments` | Normal | month + appointment status | Demand trend, cancellations and no-shows |
| `invoice_summary` | Normal | invoice | Total, amount paid, remaining balance |
| `monthly_revenue` | Materialized | month | Billed revenue per month |

---

## 4. E1: Creating the views

### 4.1 `doctor_appointment_summary` (normal)

**Why normal:** appointments are updated frequently.
**Key technique:** `LEFT JOIN appointments` keeps doctors with zero appointments. `COUNT(appointmentId)` ignores NULLs, so they show `0` (with `status = NULL`).

```sql
CREATE VIEW doctor_appointment_summary AS
SELECT  doc.doctorId,
        doc.name                 AS doc_name,
        dep.name                 AS dep_name,
        app.status,
        COUNT(app.appointmentId) AS nb_appointments
FROM doctors doc
INNER JOIN departments dep ON dep.codeDep = doc.codeDep
LEFT  JOIN appointments app ON app.doctorId = doc.doctorId
GROUP BY doc.doctorId, doc.name, dep.name, app.status;
```

### 4.2 `patient_history` (materialized)

**Why materialized:** consultation history is read often and changes less often, so the result is stored on disk and refreshed when needed.
**Key technique:** `consultationId` is included so a **unique index** can be created, which enables `REFRESH MATERIALIZED VIEW CONCURRENTLY` (readers are not blocked during refresh).

```sql
CREATE MATERIALIZED VIEW patient_history AS
SELECT  p.patientId,
        p.name AS patient_name,
        c.consultationId,
        c.consultation_type,
        c.consult_datetime,
        c.symptoms,
        c.diagnosis
FROM patients p
INNER JOIN consultation c USING (patientId);

CREATE UNIQUE INDEX ux_patient_history_consultation
    ON patient_history (consultationId);
```

### 4.3 `monthly_appointments` (normal)

**Why normal:** management needs live appointment numbers.
**Key technique:** `TO_CHAR(..., 'YYYY-MM')` groups by month, and the text format sorts chronologically.

```sql
CREATE VIEW monthly_appointments AS
SELECT  TO_CHAR(appointment_date_time, 'YYYY-MM') AS in_month,
        status,
        COUNT(*)                                   AS nb_appointments
FROM appointments
GROUP BY TO_CHAR(appointment_date_time, 'YYYY-MM'), status;
```

### 4.4 `invoice_summary` (normal)

**Why normal:** balances must always be current.
**Key technique:** the `status = 'completed'` filter sits in the `ON` clause, **not** in `WHERE`. In `WHERE`, unpaid invoices would disappear from the result.
**Avoiding double counting:** only one one-to-many join (invoice → payments) is used, so `total_amount` is never multiplied. Unpaid invoices get `paid_amount = 0` through `COALESCE`.

```sql
CREATE VIEW invoice_summary AS
SELECT  i.invoiceId,
        i.invoice_number,
        i.patientId,
        i.total_amount,
        COALESCE(SUM(pay.amount), 0)                  AS paid_amount,
        i.total_amount - COALESCE(SUM(pay.amount), 0) AS remaining_amount
FROM invoice i
LEFT JOIN payments pay
       ON pay.invoiceId = i.invoiceId
      AND pay.status = 'completed'
GROUP BY i.invoiceId, i.invoice_number, i.patientId, i.total_amount;
```

### 4.5 `monthly_revenue` (materialized)

**Measure:** *billed* revenue (invoiced amount by issue month), not cash collected.
**Why materialized:** it aggregates all invoices, and a daily refresh is enough for reporting.

```sql
CREATE MATERIALIZED VIEW monthly_revenue AS
SELECT  DATE_TRUNC('month', issue_date)::date AS revenue_month,
        COUNT(*)                              AS nb_invoices,
        SUM(total_amount)                     AS billed_revenue
FROM invoice
GROUP BY DATE_TRUNC('month', issue_date);

CREATE UNIQUE INDEX ux_monthly_revenue_month
    ON monthly_revenue (revenue_month);
```

---

## 5. E2: Querying the views

| # | Question | Status |
|---|---|---|
| E2.1 | Five busiest doctors | Done |
| E2.2 | Departments above a consultation threshold | Pending (`department_performance`) |
| E2.3 | Patients with unpaid or partially paid invoices | Done |
| E2.4 | Month with the most appointments | Done |
| E2.5 | Compare department performance | Pending (`department_performance`) |

```sql
-- E2.1 Five busiest doctors (total across all statuses)
SELECT doctorId, doc_name, SUM(nb_appointments) AS total_appointments
FROM doctor_appointment_summary
GROUP BY doctorId, doc_name
ORDER BY total_appointments DESC
LIMIT 5;

-- E2.3 Patients with an outstanding balance
SELECT DISTINCT p.name AS patient_name
FROM invoice_summary s
INNER JOIN patients p USING (patientId)
WHERE s.remaining_amount > 0;

-- E2.4 Busiest month
SELECT in_month, SUM(nb_appointments) AS appointments
FROM monthly_appointments
GROUP BY in_month
ORDER BY appointments DESC
LIMIT 1;
```

---

## 6. E3: View management

### E3.1 Replacing a view

`CREATE OR REPLACE VIEW` redefines a view without dropping dependent objects. Here `codeDep` is added to `doctor_appointment_summary`. PostgreSQL only allows **new columns at the end**; existing columns must keep their names, order and types.

```sql
CREATE OR REPLACE VIEW doctor_appointment_summary AS
SELECT  doc.doctorId,
        doc.name                 AS doc_name,
        dep.name                 AS dep_name,
        app.status,
        COUNT(app.appointmentId) AS nb_appointments,
        dep.codeDep
FROM doctors doc
INNER JOIN departments dep ON dep.codeDep = doc.codeDep
LEFT  JOIN appointments app ON app.doctorId = doc.doctorId
GROUP BY doc.doctorId, doc.name, dep.codeDep, dep.name, app.status;
```

### E3.2 Does a normal view store rows?

No. It stores only the query definition. Each time the view is queried, PostgreSQL runs the underlying query on the base tables. It behaves like a virtual table.

### E3.3 Normal vs materialized view

| | Normal view | Materialized view |
|---|---|---|
| Stores rows | No (definition only) | Yes (on disk) |
| Freshness | Always current | As of last `REFRESH` |
| Read speed | Query runs every time | Fast, like a table |
| Extra cost | None | Storage + refresh time |
| Indexes | Not possible | Possible |
| Best for | Frequently changing data | Heavy queries read often |

### E3.4–E3.5 A materialized view is a snapshot (test)

```sql
-- 1) baseline
SELECT * FROM monthly_revenue ORDER BY revenue_month;

-- 2) change the source data
INSERT INTO invoice (invoice_number, patientId, issue_date, due_date, status, total_amount)
VALUES ('INV-TEST-001', 1, CURRENT_DATE, CURRENT_DATE + 30, 'unpaid', 500.00);

-- 3) still the OLD result (stale snapshot)
SELECT * FROM monthly_revenue ORDER BY revenue_month;

-- 4) refresh: the new invoice now appears
REFRESH MATERIALIZED VIEW monthly_revenue;
SELECT * FROM monthly_revenue ORDER BY revenue_month;

-- 5) cleanup
DELETE FROM invoice WHERE invoice_number = 'INV-TEST-001';
REFRESH MATERIALIZED VIEW monthly_revenue;
```

### E3.6 When is a materialized view worth it?

When the query is expensive, read often, and slightly old data is acceptable. Refresh frequency is a trade-off: refreshing more often gives fresher data but adds load, while refreshing less often is cheaper but staler. For monthly revenue, a nightly refresh is enough. 

---

