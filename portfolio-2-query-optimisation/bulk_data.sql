SET search_path TO hospital, public;

BEGIN;

SELECT setseed(0.42);

CREATE TEMP TABLE name_list ON COMMIT DROP AS
SELECT ARRAY['Oghenero','Efe','Tega','Ovie','Chukwuemeka','Obinna','Ikenna','Chinedu','Emeka','Kelechi',
             'Kingsley','Daniel','Samuel','Victor','Felix','Oghenekaro','Tunde','Kunle','Segun','Femi',
             'Ibrahim','Musa','Paul','Peter','John','Joseph','Godwin','Friday','Ifeanyi','Nnamdi',
             'Chidi','Ebuka','Jude','Tony','Osaze','Eseoghene','Uyi','Ejike','Onyekachi','Sunday'] AS male_first_names,
       ARRAY['Chiamaka','Adaeze','Ngozi','Rita','Funmilayo','Blessing','Grace','Mercy','Joy','Ruth',
             'Patience','Ifeoma','Nkechi','Adaobi','Eloho','Ufuoma','Precious','Faith','Esther','Mary',
             'Comfort','Peace','Gift','Amaka','Chioma','Uju','Omotola','Yetunde','Aisha','Hauwa',
             'Edith','Juliet','Vivian','Stella','Rose','Favour','Onyinye','Ebere','Oghenetega','Ejiro'] AS female_first_names,
       ARRAY['Okoro','Nwosu','Obi','Edafe','Ighodaro','Omonigho','Ikpeba','Onyeka','Etaghene','Ani',
             'Okpako','Ofili','Uwadia','Ugbomah','Emuobor','Akpobome','Okonkwo','Udoh','Nnamdi','Omoregie',
             'Ibe','Ehiede','Okolie','Osagie','Ajayi','Okafor','Eze','Okeke','Nwachukwu','Ogbu',
             'Ekwueme','Idahosa','Igbinedion','Oseghale','Ehigiator','Efemuai','Ovwigho','Omokaro','Eruotor','Ukueku',
             'Odili','Mordi','Nwanze','Ikem','Okocha','Ojo','Bello','Afolabi','Oyelaran','Ogbonna'] AS last_names,
       ARRAY['Old Lagos Asaba Road','Ime-Obi Street','Boji-Boji Road','Agbor-Obi Road','Alihame Road',
             'Owa Road','Orogodo Street','Alisimie Road','Baleke Street','Omumu Street','Ewuru Road',
             'Ika Close','Ekuku-Agbor Street','Idumu-Oza Street','Uromi Street','Hospital Road'] AS streets;

CREATE TEMP TABLE new_doctor ON COMMIT DROP AS
WITH doctor_sex AS MATERIALIZED (
    SELECT doctor_number,
           CASE WHEN random() < 0.5 THEN 'M' ELSE 'F' END AS sex,
           DATE '2008-01-01' + floor(random() * 5800)::int AS hire_date
    FROM generate_series(17, 56) AS doctor_number
)
SELECT doctor_sex.doctor_number,
       'OGH-' || lpad(doctor_sex.doctor_number::text, 4, '0') AS staff_no,
       doctor_sex.sex,
       doctor_sex.hire_date,
       CASE doctor_sex.sex
           WHEN 'M' THEN name_list.male_first_names[1 + floor(random() * cardinality(name_list.male_first_names))::int]
           ELSE name_list.female_first_names[1 + floor(random() * cardinality(name_list.female_first_names))::int]
       END AS first_name,
       name_list.last_names[1 + floor(random() * cardinality(name_list.last_names))::int] AS last_name,
       (ARRAY['General Medicine','Paediatrics','Obstetrics and Gynaecology','Surgery'])[1 + doctor_sex.doctor_number % 4] AS department_name,
       (ARRAY['CONMESS-02','CONMESS-03','CONMESS-05'])[1 + doctor_sex.doctor_number % 3] AS grade_code
FROM doctor_sex
CROSS JOIN name_list;

INSERT INTO staff (staff_no, first_name, last_name, email, phone, role, department_id, grade_id, hire_date, bank_name, account_no)
SELECT new_doctor.staff_no, new_doctor.first_name, new_doctor.last_name,
       lower(new_doctor.first_name || '.' || new_doctor.last_name || new_doctor.doctor_number) || '@ogh.ng',
       '0803' || lpad((5000000 + new_doctor.doctor_number)::text, 7, '0'),
       'doctor', department.department_id, salary_grade.grade_id, new_doctor.hire_date,
       (ARRAY['First Bank','Access Bank','GTBank','Zenith Bank','UBA'])[1 + new_doctor.doctor_number % 5],
       lpad(floor(random() * 10000000000)::bigint::text, 10, '0')
FROM new_doctor
JOIN department   ON department.name   = new_doctor.department_name
JOIN salary_grade ON salary_grade.code = new_doctor.grade_code
ORDER BY new_doctor.doctor_number;

INSERT INTO staff_profile (staff_id, date_of_birth, sex, home_address, qualification, specialty,
                           licensing_body, licence_no, licence_expiry)
SELECT staff.staff_id,
       (new_doctor.hire_date - make_interval(years => 26 + floor(random() * 10)::int))::date,
       new_doctor.sex,
       (1 + floor(random() * 60)::int) || ' ' || name_list.streets[1 + floor(random() * cardinality(name_list.streets))::int] || ', Agbor',
       'MBBS',
       CASE new_doctor.department_name
           WHEN 'General Medicine'           THEN 'General Practice'
           WHEN 'Paediatrics'                THEN 'Paediatrics'
           WHEN 'Obstetrics and Gynaecology' THEN 'Obstetrics'
           ELSE 'General Surgery'
       END,
       'MDCN', 'MDCN/R/' || (60000 + new_doctor.doctor_number), DATE '2027-12-31'
FROM new_doctor
JOIN staff ON staff.staff_no = new_doctor.staff_no
CROSS JOIN name_list;

INSERT INTO payslip (payroll_run_id, staff_id, basic_pay, housing_allowance, transport_allowance)
SELECT payroll_run.payroll_run_id, staff.staff_id, salary_grade.monthly_basic,
       salary_grade.housing_allowance, salary_grade.transport_allowance
FROM staff
JOIN salary_grade ON salary_grade.grade_id = staff.grade_id
CROSS JOIN payroll_run
WHERE payroll_run.period_month = '2026-09-01'
  AND staff.status = 'active'
  AND NOT EXISTS (SELECT 1
                  FROM payslip
                  WHERE payslip.payroll_run_id = payroll_run.payroll_run_id
                    AND payslip.staff_id = staff.staff_id);

INSERT INTO payslip_deduction (payslip_id, deduction_type, amount)
SELECT payslip.payslip_id, deduction.deduction_type,
       ROUND(CASE deduction.deduction_type
                 WHEN 'paye'    THEN payslip.gross_pay * 0.07
                 WHEN 'pension' THEN payslip.gross_pay * 0.08
                 WHEN 'nhf'     THEN payslip.basic_pay * 0.025
             END, 2)
FROM payslip
CROSS JOIN (VALUES ('paye'), ('pension'), ('nhf')) AS deduction (deduction_type)
WHERE NOT EXISTS (SELECT 1 FROM payslip_deduction WHERE payslip_deduction.payslip_id = payslip.payslip_id);

UPDATE payslip
SET total_deductions = (SELECT SUM(payslip_deduction.amount)
                        FROM payslip_deduction
                        WHERE payslip_deduction.payslip_id = payslip.payslip_id)
WHERE payslip.total_deductions = 0;

WITH new_patient AS MATERIALIZED (
    SELECT patient_number,
           CASE WHEN random() < 0.5 THEN 'M' ELSE 'F' END AS sex,
           TIMESTAMPTZ '2018-01-02 08:00+01'
               + floor(random() * 2190) * interval '1 day'
               + floor(random() * 540)  * interval '1 minute' AS registered_at,
           floor(random() * 1000000)::int AS name_roll
    FROM generate_series(1, 50000) AS patient_number
),
named_patient AS MATERIALIZED (
    SELECT new_patient.patient_number,
           new_patient.sex,
           new_patient.registered_at,
           CASE new_patient.sex
               WHEN 'M' THEN name_list.male_first_names[1 + floor(random() * cardinality(name_list.male_first_names))::int]
               ELSE name_list.female_first_names[1 + floor(random() * cardinality(name_list.female_first_names))::int]
           END AS first_name,
           name_list.last_names[1 + floor(random() * cardinality(name_list.last_names))::int] AS last_name
    FROM new_patient
    CROSS JOIN name_list
)
INSERT INTO patient (hospital_no, first_name, last_name, date_of_birth, sex, phone, address,
                     blood_group, genotype, nhis_no, next_of_kin_name, next_of_kin_phone, registered_at)
SELECT 'OGH/' || extract(year FROM named_patient.registered_at AT TIME ZONE 'Africa/Lagos') || '/' || lpad(named_patient.patient_number::text, 5, '0'),
       named_patient.first_name,
       named_patient.last_name,
       DATE '1940-01-01' + floor(random() * 28000)::int,
       named_patient.sex,
       '0' || (ARRAY['803','806','813','816','703','706','810','905'])[1 + floor(random() * 8)::int]
           || lpad(floor(random() * 10000000)::int::text, 7, '0'),
       (1 + floor(random() * 60)::int) || ' ' || name_list.streets[1 + floor(random() * cardinality(name_list.streets))::int] || ', Agbor',
       (ARRAY['O+','O+','O+','O+','A+','A+','B+','B+','AB+','O-','A-','B-','AB-'])[1 + floor(random() * 13)::int],
       (ARRAY['AA','AA','AA','AA','AA','AA','AA','AS','AS','AC','SS','SC'])[1 + floor(random() * 12)::int],
       CASE WHEN random() < 0.3 THEN 'NHIS-DT-' || (400000 + named_patient.patient_number) END,
       name_list.female_first_names[1 + floor(random() * cardinality(name_list.female_first_names))::int] || ' ' || named_patient.last_name,
       '0' || (ARRAY['803','806','813','816','703','706','810','905'])[1 + floor(random() * 8)::int]
           || lpad(floor(random() * 10000000)::int::text, 7, '0'),
       named_patient.registered_at
FROM named_patient
CROSS JOIN name_list
ORDER BY named_patient.registered_at;

WITH clinic_slot AS MATERIALIZED (
    SELECT staff.staff_id AS doctor_id,
           (clinic_day + interval '8 hours' + slot_number * interval '30 minutes') AT TIME ZONE 'Africa/Lagos' AS starts_at,
           random() AS status_roll
    FROM staff
    CROSS JOIN generate_series(TIMESTAMP '2024-01-01', TIMESTAMP '2026-09-30', interval '1 day') AS clinic_day
    CROSS JOIN generate_series(0, 15) AS slot_number
    WHERE staff.role = 'doctor'
      AND extract(isodow FROM clinic_day) < 6
      AND random() < 0.85
),
patient_range AS (
    SELECT min(patient.patient_id) AS first_id, max(patient.patient_id) AS last_id
    FROM patient
    WHERE patient.registered_at < '2024-01-01'
)
INSERT INTO appointment (patient_id, doctor_id, starts_at, ends_at, status, reason, created_at)
SELECT patient_range.first_id + floor(random() * (patient_range.last_id - patient_range.first_id + 1))::int,
       clinic_slot.doctor_id,
       clinic_slot.starts_at,
       clinic_slot.starts_at + interval '30 minutes',
       CASE WHEN clinic_slot.status_roll < 0.86 THEN 'completed'
            WHEN clinic_slot.status_roll < 0.92 THEN 'no_show'
            ELSE 'cancelled'
       END,
       (ARRAY['Fever','Headache and fever','Fever and vomiting','Cough','Abdominal pain','Body pains',
              'Painful urination','Routine review','Follow-up visit','Weakness and dizziness'])[1 + floor(random() * 10)::int],
       clinic_slot.starts_at - floor(random() * 15) * interval '1 day' - interval '3 hours'
FROM clinic_slot
CROSS JOIN patient_range
ORDER BY clinic_slot.starts_at, clinic_slot.doctor_id;

WITH completed_visit AS MATERIALIZED (
    SELECT appointment.appointment_id,
           appointment.starts_at,
           (ARRAY['Malaria','Malaria','Malaria','Malaria','Malaria','Malaria','Malaria','Malaria',
                  'Typhoid fever','Typhoid fever','Typhoid fever',
                  'Hypertension','Hypertension','Hypertension',
                  'Type 2 diabetes mellitus','Type 2 diabetes mellitus',
                  'Urinary tract infection','Urinary tract infection',
                  'Acute gastroenteritis','Acute gastroenteritis',
                  'Pneumonia','Asthma','Sickle cell disorder'])[1 + floor(random() * 23)::int] AS disease_name
    FROM appointment
    WHERE appointment.status = 'completed'
      AND appointment.starts_at < '2026-10-01'
)
INSERT INTO diagnosis (appointment_id, disease_id, is_primary, diagnosed_at)
SELECT completed_visit.appointment_id, disease.disease_id, true, completed_visit.starts_at + interval '20 minutes'
FROM completed_visit
JOIN disease ON disease.name = completed_visit.disease_name
ORDER BY completed_visit.appointment_id;

INSERT INTO lab_order (appointment_id, lab_test_id, ordered_by, ordered_at, status, result_value, performed_by, completed_at)
SELECT appointment.appointment_id,
       lab_test.lab_test_id,
       appointment.doctor_id,
       appointment.starts_at + interval '15 minutes',
       'completed',
       CASE lab_test.code
           WHEN 'MP'    THEN 'Plasmodium falciparum ' || (ARRAY['+','++','+++'])[1 + floor(random() * 3)::int]
           WHEN 'WIDAL' THEN 'S. typhi O 1:' || (ARRAY['80','160','320'])[1 + floor(random() * 3)::int]
                             || ', H 1:' || (ARRAY['80','160','320'])[1 + floor(random() * 3)::int]
           WHEN 'UA'    THEN 'Leucocytes ' || (ARRAY['+','++','+++'])[1 + floor(random() * 3)::int] || ', nitrites positive'
           WHEN 'FBS'   THEN round((6.5 + random() * 6)::numeric, 1) || ' mmol/L'
           ELSE 'WBC ' || round((4 + random() * 12)::numeric, 1) || ' x10^9/L, Hb '
                || round((8 + random() * 7)::numeric, 1) || ' g/dL'
       END,
       lab_scientist_list.staff_ids[1 + floor(random() * cardinality(lab_scientist_list.staff_ids))::int],
       appointment.starts_at + interval '2 hours'
FROM diagnosis
JOIN appointment ON appointment.appointment_id = diagnosis.appointment_id
JOIN disease     ON disease.disease_id = diagnosis.disease_id
JOIN (VALUES
    ('Malaria',                  'MP'),
    ('Typhoid fever',            'WIDAL'),
    ('Urinary tract infection',  'UA'),
    ('Type 2 diabetes mellitus', 'FBS'),
    ('Pneumonia',                'FBC'),
    ('Sickle cell disorder',     'FBC'),
    ('Acute gastroenteritis',    'FBC')
) AS disease_lab_test (disease_name, test_code) ON disease_lab_test.disease_name = disease.name
JOIN lab_test ON lab_test.code = disease_lab_test.test_code
CROSS JOIN (SELECT array_agg(staff.staff_id ORDER BY staff.staff_id) AS staff_ids
            FROM staff
            WHERE staff.role = 'lab_scientist') AS lab_scientist_list
WHERE appointment.starts_at < '2026-10-01'
  AND random() < 0.75
ORDER BY appointment.appointment_id;

INSERT INTO prescription (appointment_id, doctor_id, prescribed_at)
SELECT appointment.appointment_id, appointment.doctor_id, appointment.starts_at + interval '25 minutes'
FROM appointment
JOIN diagnosis ON diagnosis.appointment_id = appointment.appointment_id
WHERE appointment.starts_at < '2026-10-01'
  AND random() < 0.8
ORDER BY appointment.appointment_id;

INSERT INTO prescription_item (prescription_id, medicine_id, dosage, frequency, duration_days, quantity, quantity_dispensed)
SELECT prescription.prescription_id, medicine.medicine_id, disease_medicine.dosage, disease_medicine.frequency,
       disease_medicine.duration_days, disease_medicine.quantity, disease_medicine.quantity
FROM prescription
JOIN diagnosis ON diagnosis.appointment_id = prescription.appointment_id
JOIN disease   ON disease.disease_id = diagnosis.disease_id
JOIN (VALUES
    ('Malaria',                  'Artemether/Lumefantrine', 'tablet',  '4 tablets', 'twice daily',        3, 24),
    ('Malaria',                  'Paracetamol',             'tablet',  '2 tablets', 'three times daily',  3, 18),
    ('Typhoid fever',            'Ciprofloxacin',           'tablet',  '1 tablet',  'twice daily',        7, 14),
    ('Typhoid fever',            'Paracetamol',             'tablet',  '2 tablets', 'three times daily',  5, 30),
    ('Hypertension',             'Amlodipine',              'tablet',  '1 tablet',  'once daily',        30, 30),
    ('Type 2 diabetes mellitus', 'Metformin',               'tablet',  '1 tablet',  'twice daily',       30, 60),
    ('Urinary tract infection',  'Ciprofloxacin',           'tablet',  '1 tablet',  'twice daily',        5, 10),
    ('Acute gastroenteritis',    'Ciprofloxacin',           'tablet',  '1 tablet',  'twice daily',        3,  6),
    ('Pneumonia',                'Amoxicillin',             'capsule', '1 capsule', 'three times daily',  7, 21),
    ('Pneumonia',                'Paracetamol',             'tablet',  '2 tablets', 'three times daily',  5, 30),
    ('Asthma',                   'Salbutamol',              'tablet',  '1 tablet',  'three times daily',  5, 15),
    ('Sickle cell disorder',     'Folic acid',              'tablet',  '1 tablet',  'once daily',        30, 30),
    ('Sickle cell disorder',     'Ibuprofen',               'tablet',  '1 tablet',  'three times daily',  5, 15)
) AS disease_medicine (disease_name, medicine_name, medicine_form, dosage, frequency, duration_days, quantity)
    ON disease_medicine.disease_name = disease.name
JOIN medicine ON medicine.name = disease_medicine.medicine_name AND medicine.form = disease_medicine.medicine_form
WHERE prescription.prescribed_at < '2026-10-01'
ORDER BY prescription.prescription_id, medicine.medicine_id;

WITH bulk_dispensing AS (
    SELECT prescription_item.medicine_id,
           prescription_item.prescription_id,
           prescription_item.quantity_dispensed,
           prescription.prescribed_at
    FROM prescription_item
    JOIN prescription ON prescription.prescription_id = prescription_item.prescription_id
    WHERE prescription.prescribed_at < '2026-10-01'
),
pharmacist_list AS (
    SELECT array_agg(staff.staff_id ORDER BY staff.staff_id) AS staff_ids
    FROM staff
    WHERE staff.role = 'pharmacist'
),
monthly_delivery AS (
    SELECT bulk_dispensing.medicine_id,
           date_trunc('month', bulk_dispensing.prescribed_at AT TIME ZONE 'Africa/Lagos') AS delivery_month,
           SUM(bulk_dispensing.quantity_dispensed)::int AS quantity
    FROM bulk_dispensing
    GROUP BY bulk_dispensing.medicine_id, date_trunc('month', bulk_dispensing.prescribed_at AT TIME ZONE 'Africa/Lagos')
)
INSERT INTO stock_movement (medicine_id, movement_type, quantity, prescription_id, supplier_ref, recorded_by, recorded_at)
SELECT stock_change.medicine_id, stock_change.movement_type, stock_change.quantity, stock_change.prescription_id,
       stock_change.supplier_ref, stock_change.recorded_by, stock_change.recorded_at
FROM (
    SELECT monthly_delivery.medicine_id,
           'received' AS movement_type,
           monthly_delivery.quantity,
           NULL::int AS prescription_id,
           'SUP-' || to_char(monthly_delivery.delivery_month, 'YYYY-MM') || '-' || lpad(monthly_delivery.medicine_id::text, 2, '0') AS supplier_ref,
           pharmacist_list.staff_ids[1] AS recorded_by,
           (monthly_delivery.delivery_month + interval '7 hours') AT TIME ZONE 'Africa/Lagos' AS recorded_at
    FROM monthly_delivery
    CROSS JOIN pharmacist_list
    UNION ALL
    SELECT bulk_dispensing.medicine_id,
           'dispensed',
           -bulk_dispensing.quantity_dispensed,
           bulk_dispensing.prescription_id,
           NULL,
           pharmacist_list.staff_ids[1 + floor(random() * cardinality(pharmacist_list.staff_ids))::int],
           bulk_dispensing.prescribed_at + interval '30 minutes'
    FROM bulk_dispensing
    CROSS JOIN pharmacist_list
) AS stock_change
ORDER BY stock_change.recorded_at, stock_change.medicine_id;

UPDATE medicine
SET quantity_on_hand = (SELECT COALESCE(SUM(stock_movement.quantity), 0)
                        FROM stock_movement
                        WHERE stock_movement.medicine_id = medicine.medicine_id);

WITH billed_visit AS MATERIALIZED (
    SELECT appointment.appointment_id,
           appointment.patient_id,
           appointment.starts_at,
           random() AS payment_roll
    FROM appointment
    WHERE appointment.status = 'completed'
      AND appointment.starts_at < '2026-10-01'
)
INSERT INTO invoice (invoice_no, patient_id, issued_at, due_date, status)
SELECT 'INV-' || to_char(billed_visit.starts_at AT TIME ZONE 'Africa/Lagos', 'YYYY') || '-' || lpad(billed_visit.appointment_id::text, 7, '0'),
       billed_visit.patient_id,
       billed_visit.starts_at + interval '1 hour',
       (billed_visit.starts_at AT TIME ZONE 'Africa/Lagos')::date + 14,
       CASE WHEN billed_visit.payment_roll < 0.85 THEN 'paid'
            WHEN billed_visit.payment_roll < 0.92 THEN 'part_paid'
            ELSE 'issued'
       END
FROM billed_visit
ORDER BY billed_visit.appointment_id;

WITH bulk_invoice_line AS (
    SELECT appointment.appointment_id,
           1 AS line_group,
           0 AS line_order,
           'consultation' AS item_type,
           'Consultation - ' || department.name AS description,
           1 AS quantity,
           5000.00 AS unit_price
    FROM appointment
    JOIN staff      ON staff.staff_id = appointment.doctor_id
    JOIN department ON department.department_id = staff.department_id
    WHERE appointment.status = 'completed'
      AND appointment.starts_at < '2026-10-01'
    UNION ALL
    SELECT lab_order.appointment_id, 2, lab_test.lab_test_id, 'lab', lab_test.name, 1, lab_test.price
    FROM lab_order
    JOIN lab_test ON lab_test.lab_test_id = lab_order.lab_test_id
    WHERE lab_order.ordered_at < '2026-10-01'
    UNION ALL
    SELECT prescription.appointment_id, 3, medicine.medicine_id, 'medicine',
           medicine.name || ' ' || medicine.strength || ' ' || medicine.form,
           prescription_item.quantity_dispensed, medicine.unit_price
    FROM prescription_item
    JOIN prescription ON prescription.prescription_id = prescription_item.prescription_id
    JOIN medicine     ON medicine.medicine_id = prescription_item.medicine_id
    WHERE prescription.prescribed_at < '2026-10-01'
)
INSERT INTO invoice_item (invoice_id, line_no, item_type, description, quantity, unit_price)
SELECT invoice.invoice_id,
       row_number() OVER (PARTITION BY invoice.invoice_id
                          ORDER BY bulk_invoice_line.line_group, bulk_invoice_line.line_order),
       bulk_invoice_line.item_type,
       bulk_invoice_line.description,
       bulk_invoice_line.quantity,
       bulk_invoice_line.unit_price
FROM bulk_invoice_line
JOIN appointment ON appointment.appointment_id = bulk_invoice_line.appointment_id
JOIN invoice     ON invoice.invoice_no = 'INV-' || to_char(appointment.starts_at AT TIME ZONE 'Africa/Lagos', 'YYYY')
                                         || '-' || lpad(appointment.appointment_id::text, 7, '0');

WITH invoice_total AS (
    SELECT invoice_item.invoice_id, SUM(invoice_item.line_total) AS total
    FROM invoice_item
    GROUP BY invoice_item.invoice_id
),
bulk_payment AS MATERIALIZED (
    SELECT invoice.invoice_id,
           invoice.issued_at,
           CASE invoice.status WHEN 'paid' THEN invoice_total.total ELSE ROUND(invoice_total.total / 2, 2) END AS amount,
           CASE WHEN patient.nhis_no IS NOT NULL THEN 'nhis'
                ELSE (ARRAY['cash','pos','transfer'])[1 + floor(random() * 3)::int]
           END AS method
    FROM invoice
    JOIN invoice_total ON invoice_total.invoice_id = invoice.invoice_id
    JOIN patient       ON patient.patient_id = invoice.patient_id
    WHERE invoice.status IN ('paid', 'part_paid')
      AND invoice.issued_at < '2026-10-01'
)
INSERT INTO payment (invoice_id, amount, method, reference, paid_at, received_by)
SELECT bulk_payment.invoice_id,
       bulk_payment.amount,
       bulk_payment.method,
       CASE bulk_payment.method
           WHEN 'pos'      THEN 'POS-'      || lpad(bulk_payment.invoice_id::text, 8, '0')
           WHEN 'transfer' THEN 'TRF-'      || lpad(bulk_payment.invoice_id::text, 8, '0')
           WHEN 'nhis'     THEN 'NHIS-CLM-' || lpad(bulk_payment.invoice_id::text, 8, '0')
       END,
       bulk_payment.issued_at + interval '10 minutes',
       billing_officer.staff_id
FROM bulk_payment
CROSS JOIN (SELECT staff.staff_id FROM staff WHERE staff.staff_no = 'OGH-0014') AS billing_officer
ORDER BY bulk_payment.invoice_id;

COMMIT;

VACUUM ANALYZE;
