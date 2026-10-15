SET search_path TO hospital, public;

\if :{?explain}
\else
\set explain ''
\endif

\set hospital_no 'OGH/2022/34210'

\echo
\echo '=== QUERY 1: Visit history for one patient, newest first'
:explain
SELECT appointment.starts_at,
       appointment.status,
       staff.first_name || ' ' || staff.last_name AS doctor,
       disease.name AS primary_diagnosis
FROM patient
JOIN appointment ON appointment.patient_id = patient.patient_id
JOIN staff ON staff.staff_id = appointment.doctor_id
LEFT JOIN diagnosis ON diagnosis.appointment_id = appointment.appointment_id
                   AND diagnosis.is_primary
LEFT JOIN disease ON disease.disease_id = diagnosis.disease_id
WHERE patient.hospital_no = :'hospital_no'
ORDER BY appointment.starts_at DESC;

\echo
\echo '=== QUERY 2: Clinic list for one doctor on Monday 14 September 2026'
:explain
SELECT appointment.starts_at,
       patient.hospital_no,
       patient.first_name || ' ' || patient.last_name AS patient,
       appointment.status,
       appointment.reason
FROM staff
JOIN appointment ON appointment.doctor_id = staff.staff_id
JOIN patient ON patient.patient_id = appointment.patient_id
WHERE staff.staff_no = 'OGH-0017'
  AND appointment.starts_at >= '2026-09-14 00:00+01'
  AND appointment.starts_at <  '2026-09-15 00:00+01'
ORDER BY appointment.starts_at;

\echo
\echo '=== QUERY 3a: Outstanding invoices for one patient, using invoice_balance_view'
:explain
SELECT invoice_balance_view.invoice_no,
       invoice_balance_view.status,
       invoice_balance_view.total_amount,
       invoice_balance_view.amount_paid,
       invoice_balance_view.balance
FROM patient
JOIN invoice_balance_view ON invoice_balance_view.patient_id = patient.patient_id
WHERE patient.hospital_no = :'hospital_no'
  AND invoice_balance_view.balance > 0
ORDER BY invoice_balance_view.invoice_no;

\echo
\echo '=== QUERY 3b: Outstanding invoices for one patient, totals worked out per invoice'
:explain
SELECT invoice.invoice_no,
       invoice.status,
       invoice_totals.total_amount,
       payment_totals.amount_paid,
       invoice_totals.total_amount - payment_totals.amount_paid AS balance
FROM patient
JOIN invoice ON invoice.patient_id = patient.patient_id
CROSS JOIN LATERAL (SELECT COALESCE(SUM(invoice_item.line_total), 0) AS total_amount
                    FROM invoice_item
                    WHERE invoice_item.invoice_id = invoice.invoice_id) AS invoice_totals
CROSS JOIN LATERAL (SELECT COALESCE(SUM(payment.amount), 0) AS amount_paid
                    FROM payment
                    WHERE payment.invoice_id = invoice.invoice_id) AS payment_totals
WHERE patient.hospital_no = :'hospital_no'
  AND invoice_totals.total_amount - payment_totals.amount_paid > 0
ORDER BY invoice.invoice_no;

\echo
\echo '=== QUERY 4: Ten most common primary diagnoses in September 2026'
:explain
SELECT disease.name,
       disease.icd10_code,
       COUNT(*) AS cases
FROM diagnosis
JOIN disease ON disease.disease_id = diagnosis.disease_id
WHERE diagnosis.is_primary
  AND diagnosis.diagnosed_at >= '2026-09-01 00:00+01'
  AND diagnosis.diagnosed_at <  '2026-10-01 00:00+01'
GROUP BY disease.name, disease.icd10_code
ORDER BY cases DESC
LIMIT 10;

\echo
\echo '=== QUERY 5a: Duplicate check for "Chiamaka Okonkow", as written in find_possible_duplicate_patients'
:explain
SELECT patient.hospital_no,
       patient.first_name || ' ' || patient.last_name AS full_name,
       patient.date_of_birth,
       patient.phone,
       similarity(patient.first_name || ' ' || patient.last_name, 'Chiamaka Okonkow') AS name_similarity
FROM patient
WHERE patient.phone = '08099999999'
   OR (patient.date_of_birth = '1992-07-25'
       AND similarity(patient.first_name || ' ' || patient.last_name, 'Chiamaka Okonkow') > 0.3)
   OR similarity(patient.first_name || ' ' || patient.last_name, 'Chiamaka Okonkow') > 0.6
ORDER BY name_similarity DESC;

\echo
\echo '=== QUERY 5b: The same duplicate check written so it can use indexes'
SET pg_trgm.similarity_threshold = 0.6;
:explain
SELECT patient.hospital_no,
       patient.first_name || ' ' || patient.last_name AS full_name,
       patient.date_of_birth,
       patient.phone,
       similarity(patient.first_name || ' ' || patient.last_name, 'Chiamaka Okonkow') AS name_similarity
FROM patient
WHERE (patient.phone = '08099999999'
       OR patient.date_of_birth = '1992-07-25'
       OR (patient.first_name || ' ' || patient.last_name) % 'Chiamaka Okonkow')
  AND (patient.phone = '08099999999'
       OR (patient.date_of_birth = '1992-07-25'
           AND similarity(patient.first_name || ' ' || patient.last_name, 'Chiamaka Okonkow') > 0.3)
       OR similarity(patient.first_name || ' ' || patient.last_name, 'Chiamaka Okonkow') > 0.6)
ORDER BY name_similarity DESC;
RESET pg_trgm.similarity_threshold;
