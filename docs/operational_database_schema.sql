
select * from departments;
select * from doctors;
select * from patients;
select * from appointments;
select * from consultation;
select * from room;

create table departments (
	codeDep serial primary key,
	name varchar(30) not null,
	location varchar(40) not null,
	phone_extension char(9)
);

create table doctors(
	doctorId serial primary key,
	name varchar(30) not null,
	contact_details varchar(30),
	hire_date date  default current_date,
	specialty varchar(40)  not null,
	codeDep integer references departments(codeDep) on delete set null
);

create table patients (
	patientId serial primary key,
	name varchar(30) not null,
	dateOfBirth date not null,
	contact_details varchar(40),
	address varchar(50),
	registration_date date default current_date
);

create table appointments(
	appointmentId serial primary key,
	patientId integer not null references patients(patientId) ,
	doctorId integer not null references doctors(doctorId),
	appointment_date_time timestamp not null,
	reason text,
	status varchar(30) not null check ( status in ('scheduled', 'confirmed', 'cancelled', 'completed','no-show')),
	creation_timestamp timestamp not null default current_timestamp,
	constraint d_a_uk unique (doctorId,appointment_date_time),
	constraint a_p_d_s_uk unique (appointmentId, patientId , doctorId,status)
);






create table consultation(
	consultationId serial primary key,
	consultation_type VARCHAR(12) NOT NULL DEFAULT 'appointment',
	appointmentId integer unique references appointments(appointmentId) ,
	appointment_status varchar(30),
	doctorId integer not null references doctors(doctorId),
	patientId integer not null references patients(patientId),
	consult_datetime timestamp not null default current_timestamp,
	symptoms          TEXT,
    diagnosis         TEXT,
    notes             TEXT,
	CHECK (consultation_type IN ('appointment','walk_in','emergency')),
	CHECK (
        (consultation_type = 'appointment' AND appointmentId IS NOT NULL AND appointment_status = 'completed' and appointment_status is not null) OR
        (consultation_type <> 'appointment' AND appointmentId IS NULL AND  appointment_status is null)
    ),
	constraint a_d_p_s_fk foreign key (appointmentId, patientId , doctorId,appointment_status) references appointments(appointmentId, patientId , doctorId,status)
);



create table medications(
	medicationId serial primary key,
	name varchar(30) not null unique,
	form varchar(30),
	strength  VARCHAR(30)
);



create table prescription_line(
	medicationId integer not null references medications(medicationId) ,
	consulationId integer not null references consultation(consultationId) on delete cascade,
    dosage          VARCHAR(50) NOT NULL, 
    frequency       VARCHAR(50) NOT NULL,  
    duration_days   INT NOT NULL CHECK (duration_days > 0),
    quantity        INT NOT NULL CHECK (quantity > 0),
    PRIMARY KEY (consulationId, medicationId)
);


create table room(
    roomId serial primary key,
    room_number varchar(10) not null unique,
    room_type varchar(12) not null check (room_type in ('private','shared','emergency')),
    capacity integer not null check (capacity > 0),
    status varchar(15) not null default 'available' check (status in ('available','maintenance','closed')),

	-- a private room holds exactly one patient
	check (room_type <> 'private' or capacity = 1)
);



create table hospitalization(
    patientId integer not null references patients(patientId),
    doctorId integer not null references doctors(doctorId),
	roomId integer not null references room(roomId),
    admission_datetime timestamp not null default current_timestamp,
    discharge_datetime timestamp,
    reason text not null,
    status varchar(15) not null default 'admitted' check (status in ('admitted','discharged','cancelled')),

    check (discharge_datetime is null or discharge_datetime > admission_datetime),

    -- discharged <=> has a discharge date
    check (
        (status = 'discharged' and discharge_datetime is not null) or
        (status <> 'discharged' and discharge_datetime is null)
    ),

	primary key(patientId,admission_datetime)
);





create table invoice(
    invoiceId serial primary key,
    invoice_number varchar(20) not null unique,
    patientId integer not null references patients(patientId),
    issue_date date not null default current_date,
    due_date date not null,
    status varchar(15) not null default 'unpaid'
        check (status in ('unpaid','partially_paid','paid','cancelled')),
    total_amount numeric(10,2) not null check (total_amount >= 0),

    check (due_date >= issue_date)
);




create table billing_line(
    lineId serial primary key,
    invoiceId integer not null,
    line_type varchar(15) not null
        check (line_type in ('consultation','medication','examination','hospitalization')),
    description varchar(200) not null,
    fee numeric(10,2) not null check (fee > 0),
    consultationId integer,
    medicationId integer references medication(medicationId),

    check (
        (line_type = 'consultation'    and consultationId is not null
            and medicationId is null) or
        (line_type = 'medication'     and medicationId is not null
            and consultationId is null) or
        (line_type = 'hospitalization'
            and consultationId is null and medicationId is null) or
        (line_type = 'examination'     and consultationId is null
            and medicationId is null)
    ),

    constraint il_invoice_fk foreign key (invoiceId)
        references invoice (invoiceId),
    constraint il_consult_fk foreign key (consultationId)
        references consultation (consultationId),
		constraint il_medication_fk foreign key (medicationId)
        references medications (medicationId),
    constraint il_consult_uk unique (consultationId)
);



create table payment(
    paymentId serial primary key,
    invoiceId integer not null references invoice(invoiceId),
    payment_date timestamp not null default current_timestamp,
    amount numeric(10,2) not null check (amount > 0),
    method varchar(15) not null
        check (method in ('cash','card','bank_transfer','cheque','insurance')),
    reference varchar(50),
    status varchar(15) not null default 'completed'
        check (status in ('pending','completed','failed','refunded')),

    -- every method except cash needs a reference
    check (method = 'cash' or reference is not null),
    constraint p_method_ref_uk unique (method, reference)
);


