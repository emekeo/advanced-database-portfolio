DROP SCHEMA IF EXISTS hospital CASCADE;
CREATE SCHEMA hospital;
SET search_path TO hospital;

CREATE EXTENSION IF NOT EXISTS btree_gist SCHEMA public;
SET search_path TO hospital, public;

CREATE TABLE department (
    department_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name          VARCHAR(80)  NOT NULL UNIQUE
);

CREATE TABLE salary_grade (
    grade_id            INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code                VARCHAR(10)   NOT NULL UNIQUE,
    title               VARCHAR(80)   NOT NULL,
    monthly_basic       NUMERIC(12,2) NOT NULL CHECK (monthly_basic > 0),
    housing_allowance   NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (housing_allowance >= 0),
    transport_allowance NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (transport_allowance >= 0)
);

CREATE TABLE staff (
    staff_id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    staff_no       VARCHAR(12)  NOT NULL UNIQUE,
    first_name     VARCHAR(50)  NOT NULL,
    last_name      VARCHAR(50)  NOT NULL,
    email          VARCHAR(120) UNIQUE,
    phone          VARCHAR(20),
    role           VARCHAR(20)  NOT NULL
                   CHECK (role IN ('doctor','nurse','lab_scientist','pharmacist',
                                   'records_officer','billing_officer','hr_officer','admin')),
    department_id  INT          NOT NULL REFERENCES department ON DELETE RESTRICT,
    grade_id       INT          NOT NULL REFERENCES salary_grade ON DELETE RESTRICT,
    hire_date      DATE         NOT NULL,
    status         VARCHAR(12)  NOT NULL DEFAULT 'active'
                   CHECK (status IN ('active','on_leave','terminated')),
    bank_name      VARCHAR(60),
    account_no     CHAR(10)     CHECK (account_no ~ '^[0-9]{10}$')
);

CREATE TABLE staff_profile (
    staff_id        INT          PRIMARY KEY REFERENCES staff ON DELETE CASCADE,
    date_of_birth   DATE         NOT NULL CHECK (date_of_birth > DATE '1940-01-01'),
    sex             CHAR(1)      NOT NULL CHECK (sex IN ('M','F')),
    home_address    VARCHAR(200),
    next_of_kin_name  VARCHAR(100),
    next_of_kin_phone VARCHAR(20),
    qualification   VARCHAR(100),
    specialty       VARCHAR(60),
    licensing_body  VARCHAR(6)   CHECK (licensing_body IN ('MDCN','NMCN','PCN','MLSCN')),
    licence_no      VARCHAR(20),
    licence_expiry  DATE,
    UNIQUE (licensing_body, licence_no),
    CHECK (num_nulls(licensing_body, licence_no, licence_expiry) IN (0, 3))
);

CREATE TABLE patient (
    patient_id           INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    hospital_no          VARCHAR(15)  NOT NULL UNIQUE,
    first_name           VARCHAR(50)  NOT NULL,
    last_name            VARCHAR(50)  NOT NULL,
    date_of_birth        DATE         NOT NULL CHECK (date_of_birth > DATE '1900-01-01'),
    sex                  CHAR(1)      NOT NULL CHECK (sex IN ('M','F')),
    phone                VARCHAR(20),
    address              VARCHAR(200),
    blood_group          VARCHAR(3)   CHECK (blood_group IN ('A+','A-','B+','B-','AB+','AB-','O+','O-')),
    genotype             VARCHAR(2)   CHECK (genotype IN ('AA','AS','AC','SS','SC')),
    nhis_no              VARCHAR(20)  UNIQUE,
    next_of_kin_name     VARCHAR(100),
    next_of_kin_phone    VARCHAR(20),
    registered_at        TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE disease (
    disease_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        VARCHAR(150) NOT NULL UNIQUE,
    icd10_code  VARCHAR(8)   UNIQUE
);

CREATE TABLE patient_condition (
    condition_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    patient_id      INT          NOT NULL REFERENCES patient ON DELETE RESTRICT,
    disease_id      INT          NOT NULL REFERENCES disease ON DELETE RESTRICT,
    condition_type  VARCHAR(10)  NOT NULL CHECK (condition_type IN ('chronic','past','surgical')),
    diagnosed_on    DATE,
    is_active       BOOLEAN      NOT NULL DEFAULT true,
    notes           VARCHAR(300),
    recorded_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    UNIQUE (patient_id, disease_id)
);

CREATE TABLE appointment (
    appointment_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    patient_id     INT          NOT NULL REFERENCES patient ON DELETE RESTRICT,
    doctor_id      INT          NOT NULL REFERENCES staff   ON DELETE RESTRICT,
    starts_at      TIMESTAMPTZ  NOT NULL,
    ends_at        TIMESTAMPTZ  NOT NULL,
    status         VARCHAR(10)  NOT NULL DEFAULT 'scheduled'
                   CHECK (status IN ('scheduled','completed','cancelled','no_show')),
    reason         VARCHAR(200),
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CHECK (ends_at > starts_at),
    CONSTRAINT no_doctor_double_booking
        EXCLUDE USING gist (doctor_id WITH =, tstzrange(starts_at, ends_at) WITH &&)
        WHERE (status <> 'cancelled')
);

CREATE TABLE ward (
    ward_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        VARCHAR(60)   NOT NULL UNIQUE,
    ward_type   VARCHAR(12)   NOT NULL
                CHECK (ward_type IN ('general','maternity','paediatric','surgical','icu')),
    daily_rate  NUMERIC(12,2) NOT NULL CHECK (daily_rate >= 0)
);

CREATE TABLE bed (
    bed_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ward_id  INT         NOT NULL REFERENCES ward ON DELETE RESTRICT,
    bed_no   VARCHAR(10) NOT NULL,
    status   VARCHAR(12) NOT NULL DEFAULT 'available'
             CHECK (status IN ('available','occupied','maintenance')),
    UNIQUE (ward_id, bed_no)
);

CREATE TABLE admission (
    admission_id        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    patient_id          INT          NOT NULL REFERENCES patient ON DELETE RESTRICT,
    bed_id              INT          NOT NULL REFERENCES bed     ON DELETE RESTRICT,
    admitting_doctor_id INT          NOT NULL REFERENCES staff   ON DELETE RESTRICT,
    admitted_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    discharged_at       TIMESTAMPTZ,
    reason              VARCHAR(200) NOT NULL,
    CHECK (discharged_at IS NULL OR discharged_at > admitted_at),
    CONSTRAINT no_bed_double_occupancy
        EXCLUDE USING gist (bed_id WITH =, tstzrange(admitted_at, discharged_at) WITH &&)
);

CREATE UNIQUE INDEX one_open_admission_per_patient
    ON admission (patient_id) WHERE discharged_at IS NULL;

CREATE TABLE diagnosis (
    diagnosis_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    appointment_id INT          REFERENCES appointment ON DELETE RESTRICT,
    admission_id   INT          REFERENCES admission   ON DELETE RESTRICT,
    disease_id     INT          NOT NULL REFERENCES disease ON DELETE RESTRICT,
    is_primary     BOOLEAN      NOT NULL DEFAULT false,
    notes          VARCHAR(300),
    diagnosed_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CHECK (num_nonnulls(appointment_id, admission_id) = 1)
);

CREATE TABLE lab_test (
    lab_test_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code         VARCHAR(10)   NOT NULL UNIQUE,
    name         VARCHAR(100)  NOT NULL,
    sample_type  VARCHAR(20)   NOT NULL CHECK (sample_type IN ('blood','urine','stool','swab','sputum','other')),
    price        NUMERIC(12,2) NOT NULL CHECK (price >= 0)
);

CREATE TABLE lab_order (
    lab_order_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    appointment_id INT          REFERENCES appointment ON DELETE RESTRICT,
    admission_id   INT          REFERENCES admission   ON DELETE RESTRICT,
    lab_test_id    INT          NOT NULL REFERENCES lab_test ON DELETE RESTRICT,
    ordered_by     INT          NOT NULL REFERENCES staff    ON DELETE RESTRICT,
    ordered_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    status         VARCHAR(16)  NOT NULL DEFAULT 'ordered'
                   CHECK (status IN ('ordered','sample_collected','completed','cancelled')),
    result_value   TEXT,
    performed_by   INT          REFERENCES staff ON DELETE RESTRICT,
    completed_at   TIMESTAMPTZ,
    CHECK (num_nonnulls(appointment_id, admission_id) = 1),
    CHECK (status <> 'completed'
           OR (result_value IS NOT NULL AND completed_at IS NOT NULL AND performed_by IS NOT NULL))
);

CREATE TABLE medicine (
    medicine_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name         VARCHAR(100)  NOT NULL,
    form         VARCHAR(12)   NOT NULL
                 CHECK (form IN ('tablet','capsule','syrup','injection','cream','infusion')),
    strength     VARCHAR(30)   NOT NULL,
    unit_price   NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0),
    quantity_on_hand INT       NOT NULL DEFAULT 0 CHECK (quantity_on_hand >= 0),
    reorder_level    INT       NOT NULL DEFAULT 0 CHECK (reorder_level >= 0),
    UNIQUE (name, form, strength)
);

CREATE TABLE patient_allergy (
    allergy_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    patient_id    INT          NOT NULL REFERENCES patient  ON DELETE RESTRICT,
    allergen      VARCHAR(100) NOT NULL,
    allergy_type  VARCHAR(14)  NOT NULL CHECK (allergy_type IN ('drug','food','environmental','other')),
    medicine_id   INT          REFERENCES medicine ON DELETE RESTRICT,
    severity      VARCHAR(16)  NOT NULL CHECK (severity IN ('mild','moderate','severe','life_threatening')),
    reaction      VARCHAR(200),
    recorded_by   INT          NOT NULL REFERENCES staff ON DELETE RESTRICT,
    recorded_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    UNIQUE (patient_id, allergen),
    CHECK (allergy_type = 'drug' OR medicine_id IS NULL)
);

CREATE TABLE prescription (
    prescription_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    appointment_id  INT          REFERENCES appointment ON DELETE RESTRICT,
    admission_id    INT          REFERENCES admission   ON DELETE RESTRICT,
    doctor_id       INT          NOT NULL REFERENCES staff ON DELETE RESTRICT,
    prescribed_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    notes           VARCHAR(300),
    CHECK (num_nonnulls(appointment_id, admission_id) = 1)
);

CREATE TABLE prescription_item (
    prescription_id   INT         NOT NULL REFERENCES prescription ON DELETE CASCADE,
    medicine_id       INT         NOT NULL REFERENCES medicine     ON DELETE RESTRICT,
    dosage            VARCHAR(50) NOT NULL,
    frequency         VARCHAR(30) NOT NULL,
    duration_days     INT         NOT NULL CHECK (duration_days > 0),
    quantity          INT         NOT NULL CHECK (quantity > 0),
    quantity_dispensed INT        NOT NULL DEFAULT 0,
    PRIMARY KEY (prescription_id, medicine_id),
    CHECK (quantity_dispensed BETWEEN 0 AND quantity)
);

CREATE TABLE stock_movement (
    movement_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    medicine_id     INT          NOT NULL REFERENCES medicine ON DELETE RESTRICT,
    movement_type   VARCHAR(10)  NOT NULL CHECK (movement_type IN ('received','dispensed','adjustment','expired')),
    quantity        INT          NOT NULL CHECK (quantity <> 0),
    prescription_id INT          REFERENCES prescription ON DELETE RESTRICT,
    supplier_ref    VARCHAR(40),
    recorded_by     INT          NOT NULL REFERENCES staff ON DELETE RESTRICT,
    recorded_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CHECK (movement_type <> 'dispensed' OR (prescription_id IS NOT NULL AND quantity < 0)),
    CHECK (movement_type <> 'received'  OR quantity > 0),
    CHECK (movement_type <> 'expired'   OR quantity < 0)
);

CREATE TABLE invoice (
    invoice_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    invoice_no  VARCHAR(20)  NOT NULL UNIQUE,
    patient_id  INT          NOT NULL REFERENCES patient ON DELETE RESTRICT,
    issued_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    due_date    DATE         NOT NULL,
    status      VARCHAR(10)  NOT NULL DEFAULT 'issued'
                CHECK (status IN ('draft','issued','part_paid','paid','void'))
);

CREATE TABLE invoice_item (
    invoice_id   INT           NOT NULL REFERENCES invoice ON DELETE CASCADE,
    line_no      SMALLINT      NOT NULL CHECK (line_no > 0),
    item_type    VARCHAR(12)   NOT NULL
                 CHECK (item_type IN ('consultation','lab','medicine','bed','procedure')),
    description  VARCHAR(200)  NOT NULL,
    quantity     INT           NOT NULL CHECK (quantity > 0),
    unit_price   NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0),
    line_total   NUMERIC(14,2) GENERATED ALWAYS AS (quantity * unit_price) STORED,
    PRIMARY KEY (invoice_id, line_no)
);

CREATE TABLE payment (
    payment_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    invoice_id   INT           NOT NULL REFERENCES invoice ON DELETE RESTRICT,
    amount       NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    method       VARCHAR(10)   NOT NULL CHECK (method IN ('cash','pos','transfer','nhis')),
    reference    VARCHAR(40)   UNIQUE,
    paid_at      TIMESTAMPTZ   NOT NULL DEFAULT now(),
    received_by  INT           NOT NULL REFERENCES staff ON DELETE RESTRICT
);

CREATE TABLE payroll_run (
    payroll_run_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    period_month   DATE         NOT NULL UNIQUE
                   CHECK (EXTRACT(DAY FROM period_month) = 1),
    status         VARCHAR(10)  NOT NULL DEFAULT 'draft'
                   CHECK (status IN ('draft','approved','paid')),
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    approved_by    INT          REFERENCES staff ON DELETE RESTRICT,
    CHECK (status = 'draft' OR approved_by IS NOT NULL)
);

CREATE TABLE payslip (
    payslip_id          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    payroll_run_id      INT           NOT NULL REFERENCES payroll_run ON DELETE RESTRICT,
    staff_id            INT           NOT NULL REFERENCES staff       ON DELETE RESTRICT,
    basic_pay           NUMERIC(12,2) NOT NULL CHECK (basic_pay >= 0),
    housing_allowance   NUMERIC(12,2) NOT NULL CHECK (housing_allowance >= 0),
    transport_allowance NUMERIC(12,2) NOT NULL CHECK (transport_allowance >= 0),
    total_deductions    NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (total_deductions >= 0),
    gross_pay           NUMERIC(12,2) GENERATED ALWAYS AS
                        (basic_pay + housing_allowance + transport_allowance) STORED,
    net_pay             NUMERIC(12,2) GENERATED ALWAYS AS
                        (basic_pay + housing_allowance + transport_allowance - total_deductions) STORED,
    UNIQUE (payroll_run_id, staff_id),
    CHECK (total_deductions <= basic_pay + housing_allowance + transport_allowance)
);

CREATE TABLE payslip_deduction (
    payslip_id     INT           NOT NULL REFERENCES payslip ON DELETE CASCADE,
    deduction_type VARCHAR(10)   NOT NULL CHECK (deduction_type IN ('paye','pension','nhf','nhis','loan')),
    amount         NUMERIC(12,2) NOT NULL CHECK (amount >= 0),
    PRIMARY KEY (payslip_id, deduction_type)
);

CREATE FUNCTION assert_staff_is_doctor() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_staff_id INT := (to_jsonb(NEW) ->> TG_ARGV[0])::INT;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM hospital.staff
                   WHERE staff_id = v_staff_id AND role = 'doctor') THEN
        RAISE EXCEPTION 'staff % is not a doctor (%.%)', v_staff_id, TG_TABLE_NAME, TG_ARGV[0]
              USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER appointment_doctor_check
    BEFORE INSERT OR UPDATE OF doctor_id ON appointment
    FOR EACH ROW EXECUTE FUNCTION assert_staff_is_doctor('doctor_id');

CREATE TRIGGER admission_doctor_check
    BEFORE INSERT OR UPDATE OF admitting_doctor_id ON admission
    FOR EACH ROW EXECUTE FUNCTION assert_staff_is_doctor('admitting_doctor_id');

CREATE TRIGGER prescription_doctor_check
    BEFORE INSERT OR UPDATE OF doctor_id ON prescription
    FOR EACH ROW EXECUTE FUNCTION assert_staff_is_doctor('doctor_id');

CREATE TRIGGER lab_order_doctor_check
    BEFORE INSERT OR UPDATE OF ordered_by ON lab_order
    FOR EACH ROW EXECUTE FUNCTION assert_staff_is_doctor('ordered_by');

CREATE VIEW invoice_balance_view AS
SELECT invoice.invoice_id,
       invoice.invoice_no,
       invoice.patient_id,
       invoice.status,
       COALESCE(invoice_totals.total, 0)                                     AS total_amount,
       COALESCE(payment_totals.paid, 0)                                      AS amount_paid,
       COALESCE(invoice_totals.total, 0) - COALESCE(payment_totals.paid, 0)  AS balance
FROM invoice
LEFT JOIN (SELECT invoice_id, SUM(line_total) AS total
           FROM invoice_item
           GROUP BY invoice_id) AS invoice_totals
       ON invoice_totals.invoice_id = invoice.invoice_id
LEFT JOIN (SELECT invoice_id, SUM(amount) AS paid
           FROM payment
           GROUP BY invoice_id) AS payment_totals
       ON payment_totals.invoice_id = invoice.invoice_id;

CREATE VIEW ward_occupancy_view AS
SELECT ward.ward_id,
       ward.name AS ward,
       ward.ward_type,
       COUNT(*)                                         AS total_beds,
       COUNT(*) FILTER (WHERE bed.status = 'occupied')    AS occupied,
       COUNT(*) FILTER (WHERE bed.status = 'available')   AS available,
       COUNT(*) FILTER (WHERE bed.status = 'maintenance') AS maintenance
FROM ward
JOIN bed ON bed.ward_id = ward.ward_id
GROUP BY ward.ward_id, ward.name, ward.ward_type;
