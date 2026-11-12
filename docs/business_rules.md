# Business rules enforced by the schema

Every rule below is enforced by a database constraint, not by application code.
The tests in `tests/` prove that each one rejects invalid data.

## Departments, doctors and patients
| # | Rule | Enforced by |
|---|---|---|
| 1 | Every department, doctor and patient has a unique identifier | `serial` primary keys |
| 2 | Each doctor belongs to exactly one department; a department has many doctors | FK `doctors.codeDep` to `departments` |

## Appointments
| # | Rule | Enforced by |
|---|---|---|
| 3 | An appointment has exactly one patient and one doctor, both must exist | `patientId`, `doctorId` NOT NULL + FKs |
| 4 | An appointment has a mandatory date/time | `appointment_date_time` NOT NULL |
| 5 | Status is one of: scheduled, confirmed, cancelled, completed, no-show | CHECK on `status` |
| 6 | Creation timestamp is filled automatically | `DEFAULT current_timestamp` |
| 7 | A doctor cannot have two appointments starting at the same time | `UNIQUE (doctorId, appointment_date_time)` (`d_a_uk`) |

## Consultations
| # | Rule | Enforced by |
|---|---|---|
| 8 | Consultation type is appointment, walk_in or emergency (walk-ins and emergencies are allowed) | CHECK on `consultation_type` |
| 9 | A normal consultation must reference an appointment; walk-ins and emergencies must not | CHECK linking type and `appointmentId` |
| 10 | A consultation from an appointment requires that appointment to be **completed** | Composite FK with `appointment_status` + CHECK `= 'completed'` |
| 11 | The consultation has the same patient and doctor as its appointment | Composite FK `a_d_p_s_fk` to `appointments (appointmentId, patientId, doctorId, status)` |
| 12 | One appointment gives at most one consultation | `UNIQUE (appointmentId)` |
| 13 | Every consultation has an existing doctor and patient, including walk-ins | `doctorId`, `patientId` NOT NULL + FKs |
| 14 | An appointment that produced a consultation cannot be cancelled, changed or deleted | The composite FK blocks it |

## Prescriptions
| # | Rule | Enforced by |
|---|---|---|
| 15 | A consultation has many medications and a medication appears in many consultations | Associative table `prescription_line` |
| 16 | A medication appears at most once per consultation | PK `(consultationId, medicationId)` |
| 17 | Dosage, frequency, duration and quantity are stored per consultation, not on the medication | Columns of `prescription_line` |
| 18 | Duration and quantity must be positive | CHECK `> 0` |

## Rooms
| # | Rule | Enforced by |
|---|---|---|
| 19 | Room number is unique | `UNIQUE (room_number)` |
| 20 | Room type is private, shared or emergency; status is available, maintenance or closed | CHECKs |
| 21 | Capacity is at least 1 | CHECK `capacity > 0` |
| 22 | A private room holds exactly one patient | CHECK `room_type <> 'private' or capacity = 1` |

## Hospitalizations
| # | Rule | Enforced by |
|---|---|---|
| 23 | A hospitalization belongs to one patient, one responsible doctor and one room, all must exist | NOT NULL FKs |
| 24 | Discharge must be after admission | CHECK |
| 25 | Status is admitted, discharged or cancelled | CHECK |
| 26 | A stay has a discharge date if and only if its status is discharged | CHECK |
| 27 | The same patient, doctor, room and admission time cannot be recorded twice | Composite PK |
| 28 | Admission time defaults to now; a reason is mandatory | `DEFAULT`, NOT NULL |

## Invoices and billing lines
| # | Rule | Enforced by |
|---|---|---|
| 29 | An invoice belongs to one existing patient and has a unique invoice number | NOT NULL FK, `UNIQUE (invoice_number)` |
| 30 | Status is unpaid, partially_paid, paid or cancelled | CHECK |
| 31 | Total amount is positive | CHECK `total_amount > 0` |
| 32 | Due date is not before issue date | CHECK |
| 33 | A billing line belongs to an existing invoice | `invoiceId` NOT NULL + FK `il_invoice_fk` |
| 34 | Line type is consultation, medication, examination or hospitalization | CHECK |
| 35 | A consultation line references a consultation, a medication line references a medication, the other types reference nothing | CHECK on type vs reference columns |
| 36 | Referenced consultations and medications must exist | FKs `il_consult_fk`, `il_medication_fk` |
| 37 | A consultation is billed only once | `UNIQUE (consultationId)` (`il_consult_uk`) |
| 38 | A line fee cannot be negative | CHECK `fee >= 0` |

## Payments
| # | Rule | Enforced by |
|---|---|---|
| 39 | A payment belongs to exactly one existing invoice | `invoiceId` NOT NULL + FK |
| 40 | An invoice can be paid in several installments | 1:N, no unique on `invoiceId` |
| 41 | Amount is mandatory and positive | NOT NULL + CHECK `> 0` |
| 42 | Method is cash, card, bank_transfer, cheque or insurance; status is pending, completed, failed or refunded | CHECKs |
| 43 | The same method and reference cannot be used twice | `UNIQUE (method, reference)` (`m_r_uk`) |
| 44 | Paid, partially paid and unpaid balances are derived from completed payments | View `invoice_balance` |

## Referential protection (all tables)
| # | Rule | Enforced by |
|---|---|---|
| 45 | A parent row with dependent records cannot be deleted (a patient with appointments, a room with stays, an invoice with payments) | FKs with the default `NO ACTION` |
