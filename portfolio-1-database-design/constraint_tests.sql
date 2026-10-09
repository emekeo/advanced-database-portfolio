\set ON_ERROR_STOP off
\set VERBOSITY terse
SET search_path TO hospital, public;

\echo
\echo '=== TEST 1: Book Dr Ese Okoro at 09:15 on 8 Oct, overlapping his 09:00-09:30 slot (expect rejection)'
BEGIN;
INSERT INTO appointment (patient_id, doctor_id, starts_at, ends_at)
SELECT patient.patient_id, staff.staff_id, '2026-10-08 09:15+01', '2026-10-08 09:45+01'
FROM patient, staff
WHERE patient.hospital_no = 'OGH/2026/0002' AND staff.staff_no = 'OGH-0001';
ROLLBACK;

\echo
\echo '=== TEST 2: Book Dr Oghenekaro Edafe in the slot freed by a cancelled appointment (expect success)'
BEGIN;
INSERT INTO appointment (patient_id, doctor_id, starts_at, ends_at)
SELECT patient.patient_id, staff.staff_id, '2026-10-06 10:00+01', '2026-10-06 10:30+01'
FROM patient, staff
WHERE patient.hospital_no = 'OGH/2026/0007' AND staff.staff_no = 'OGH-0004';
ROLLBACK;

\echo
\echo '=== TEST 3: Book pharmacist Emeka Ani as the doctor (expect rejection)'
BEGIN;
INSERT INTO appointment (patient_id, doctor_id, starts_at, ends_at)
SELECT patient.patient_id, staff.staff_id, '2026-10-12 09:00+01', '2026-10-12 09:30+01'
FROM patient, staff
WHERE patient.hospital_no = 'OGH/2026/0002' AND staff.staff_no = 'OGH-0011';
ROLLBACK;

\echo
\echo '=== TEST 4: Admit a patient into Male Medical Ward bed B2, which is already occupied (expect rejection)'
BEGIN;
INSERT INTO admission (patient_id, bed_id, admitting_doctor_id, admitted_at, reason)
SELECT patient.patient_id, bed.bed_id, staff.staff_id, '2026-10-08 12:00+01', 'Observation'
FROM patient, bed, ward, staff
WHERE patient.hospital_no = 'OGH/2026/0007'
  AND ward.name = 'Male Medical Ward' AND bed.ward_id = ward.ward_id AND bed.bed_no = 'B2'
  AND staff.staff_no = 'OGH-0001';
ROLLBACK;

\echo
\echo '=== TEST 5: Admit Tega Omoregie to another bed while he is still admitted (expect rejection)'
BEGIN;
INSERT INTO admission (patient_id, bed_id, admitting_doctor_id, admitted_at, reason)
SELECT patient.patient_id, bed.bed_id, staff.staff_id, '2026-10-08 12:00+01', 'Second admission'
FROM patient, bed, ward, staff
WHERE patient.hospital_no = 'OGH/2026/0005'
  AND ward.name = 'Male Medical Ward' AND bed.ward_id = ward.ward_id AND bed.bed_no = 'B3'
  AND staff.staff_no = 'OGH-0001';
ROLLBACK;

\echo
\echo '=== TEST 6: Record a diagnosis linked to both an appointment and an admission (expect rejection)'
BEGIN;
INSERT INTO diagnosis (appointment_id, admission_id, disease_id)
SELECT appointment.appointment_id, admission.admission_id, disease.disease_id
FROM appointment, admission, disease, patient
WHERE patient.hospital_no = 'OGH/2026/0005'
  AND appointment.patient_id = patient.patient_id AND appointment.status = 'completed'
  AND admission.patient_id = patient.patient_id
  AND disease.name = 'Pneumonia';
ROLLBACK;

\echo
\echo '=== TEST 7: Mark the pending lab order as completed without a result (expect rejection)'
BEGIN;
UPDATE lab_order
SET status = 'completed', completed_at = now()
WHERE lab_order.status = 'sample_collected';
ROLLBACK;

\echo
\echo '=== TEST 8: Delete patient Oghenero Akpobome, who has clinical history (expect rejection)'
BEGIN;
DELETE FROM patient WHERE patient.hospital_no = 'OGH/2026/0001';
ROLLBACK;

\echo
\echo '=== TEST 9: Take 50 Salbutamol tablets when only 40 are in stock (expect rejection)'
BEGIN;
UPDATE medicine
SET quantity_on_hand = quantity_on_hand - 50
WHERE medicine.name = 'Salbutamol';
ROLLBACK;

\echo
\echo '=== TEST 10: Record a dispensed stock movement with no prescription (expect rejection)'
BEGIN;
INSERT INTO stock_movement (medicine_id, movement_type, quantity, recorded_by)
SELECT medicine.medicine_id, 'dispensed', -10, staff.staff_id
FROM medicine, staff
WHERE medicine.name = 'Ibuprofen' AND staff.staff_no = 'OGH-0012';
ROLLBACK;

\echo
\echo '=== TEST 11: Dispense 40 Amlodipine tablets on a prescription for 30 (expect rejection)'
BEGIN;
UPDATE prescription_item
SET quantity_dispensed = 40
FROM medicine
WHERE medicine.medicine_id = prescription_item.medicine_id AND medicine.name = 'Amlodipine';
ROLLBACK;

\echo
\echo '=== TEST 12: Record a payment of -5000 naira (expect rejection)'
BEGIN;
INSERT INTO payment (invoice_id, amount, method, received_by)
SELECT invoice.invoice_id, -5000, 'cash', staff.staff_id
FROM invoice, staff
WHERE invoice.invoice_no = 'INV-2026-000004' AND staff.staff_no = 'OGH-0014';
ROLLBACK;

\echo
\echo '=== TEST 13: Create a second September 2026 payslip for Dr Ese Okoro (expect rejection)'
BEGIN;
INSERT INTO payslip (payroll_run_id, staff_id, basic_pay, housing_allowance, transport_allowance)
SELECT payroll_run.payroll_run_id, staff.staff_id, 650000, 130000, 50000
FROM payroll_run, staff
WHERE payroll_run.period_month = '2026-09-01' AND staff.staff_no = 'OGH-0001';
ROLLBACK;

\echo
\echo '=== TEST 14: Set Dr Ese Okoro''s deductions higher than his gross pay (expect rejection)'
BEGIN;
UPDATE payslip
SET total_deductions = 900000
FROM staff
WHERE staff.staff_id = payslip.staff_id AND staff.staff_no = 'OGH-0001';
ROLLBACK;

\echo
\echo '=== TEST 15: Type in net pay directly instead of letting the database calculate it (expect rejection)'
BEGIN;
UPDATE payslip
SET net_pay = 2000000
FROM staff
WHERE staff.staff_id = payslip.staff_id AND staff.staff_no = 'OGH-0001';
ROLLBACK;

\echo
\echo '=== TEST 16: Give nurse Grace Ikpeba a new licence number with no licensing body or expiry (expect rejection)'
BEGIN;
UPDATE staff_profile
SET licensing_body = NULL, licence_expiry = NULL, licence_no = 'RN-999999'
FROM staff
WHERE staff.staff_id = staff_profile.staff_id AND staff.staff_no = 'OGH-0008';
ROLLBACK;

\echo
\echo '=== TEST 17: Save a 9-digit bank account number for Joy Ofili (expect rejection)'
BEGIN;
UPDATE staff
SET account_no = '012345671'
WHERE staff.staff_no = 'OGH-0013';
ROLLBACK;

\echo
\echo '=== TEST 18: Register a new patient with hospital number OGH/2026/0001, which already exists (expect rejection)'
BEGIN;
INSERT INTO patient (hospital_no, first_name, last_name, date_of_birth, sex)
VALUES ('OGH/2026/0001', 'Oghenero', 'Akpobome', '1965-03-12', 'M');
ROLLBACK;

\echo
\echo '=== TEST 19: Register a different patient with Oghenero Akpobome''s NHIS number (expect rejection)'
BEGIN;
INSERT INTO patient (hospital_no, first_name, last_name, date_of_birth, sex, nhis_no)
VALUES ('OGH/2026/0099', 'Peter', 'Eze', '1990-01-01', 'M', 'NHIS-DT-102345');
ROLLBACK;

\echo
\echo '=== TEST 20: Create a staff member with staff number OGH-0001, which already exists (expect rejection)'
BEGIN;
INSERT INTO staff (staff_no, first_name, last_name, role, department_id, grade_id, hire_date)
SELECT 'OGH-0001', 'Ese', 'Okoro', 'doctor', department.department_id, salary_grade.grade_id, '2026-10-08'
FROM department, salary_grade
WHERE department.name = 'General Medicine' AND salary_grade.code = 'CONMESS-03';
ROLLBACK;

\echo
\echo '=== TEST 21: Create a new staff member with Dr Ese Okoro''s email address (expect rejection)'
BEGIN;
INSERT INTO staff (staff_no, first_name, last_name, email, role, department_id, grade_id, hire_date)
SELECT 'OGH-0099', 'Esther', 'Okoro', 'ese.okoro@ogh.ng', 'nurse', department.department_id, salary_grade.grade_id, '2026-10-08'
FROM department, salary_grade
WHERE department.name = 'Nursing Services' AND salary_grade.code = 'CONHESS-07';
ROLLBACK;

\echo
\echo '=== TEST 22: Give Dr Tolulope Adebayo the MDCN licence number already held by Dr Ese Okoro (expect rejection)'
BEGIN;
UPDATE staff_profile
SET licence_no = 'MDCN/R/45120'
FROM staff
WHERE staff.staff_id = staff_profile.staff_id AND staff.staff_no = 'OGH-0005';
ROLLBACK;

\echo
\echo '=== TEST 23: Record a payment with a bank transfer reference that was already used (expect rejection)'
BEGIN;
INSERT INTO payment (invoice_id, amount, method, reference, received_by)
SELECT invoice.invoice_id, 8500, 'transfer', 'TRF-55120931', staff.staff_id
FROM invoice, staff
WHERE invoice.invoice_no = 'INV-2026-000004' AND staff.staff_no = 'OGH-0014';
ROLLBACK;

\echo
\echo '=== TEST 24: Duplicate check before registering "Chiamaka Okonkow" (misspelt) with the same birthday (expect Chiamaka Okonkwo to be found)'
SELECT * FROM find_possible_duplicate_patients('Chiamaka', 'Okonkow', '1992-07-25', '08099999999');

\echo
\echo '=== TEST 25: Duplicate check for a child registered with an existing patient''s phone number (expect a phone match for review)'
SELECT * FROM find_possible_duplicate_patients('Ese', 'Udoh', '2023-02-14', '08061230003');

\echo
\echo '=== TEST 26: Duplicate check for a genuinely new patient (expect no matches)'
SELECT * FROM find_possible_duplicate_patients('Ikechukwu', 'Bello', '1984-11-03', '08099999999');

\echo
\echo '=== Done. Every test was rolled back, so no data was changed.'
