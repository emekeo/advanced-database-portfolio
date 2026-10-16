SET search_path TO hospital, public;

\echo
\echo '=== DOUBLE BOOKING, WINDOW B: a second receptionist books the same slot for OGH/2026/0008'
\echo
\prompt 'Do step 1 in window A first, then press Enter here for step 2: ' go

\echo 'Window B now waits here until window A commits or rolls back.'
\set ECHO queries
BEGIN;
INSERT INTO appointment (patient_id, doctor_id, starts_at, ends_at, reason)
SELECT patient.patient_id, staff.staff_id, '2026-10-20 10:00+01', '2026-10-20 10:30+01', 'Painful urination'
FROM patient
JOIN staff ON staff.staff_no = 'OGH-0001'
WHERE patient.hospital_no = 'OGH/2026/0008';
ROLLBACK;
\set ECHO none
\echo 'Window A committed first, so the no_doctor_double_booking constraint rejected this booking.'
\echo
\echo '--- Bookings for Dr Ese Okoro at 10:00 on 20 October'
\set ECHO queries
SELECT appointment.appointment_id, patient.hospital_no, appointment.starts_at, appointment.ends_at, appointment.status
FROM appointment
JOIN patient ON patient.patient_id = appointment.patient_id
JOIN staff   ON staff.staff_id = appointment.doctor_id
WHERE staff.staff_no = 'OGH-0001'
  AND appointment.starts_at = '2026-10-20 10:00+01';
\set ECHO none
\echo
\echo '--- Remove the demo booking'
DELETE FROM appointment
USING staff
WHERE staff.staff_id = appointment.doctor_id
  AND staff.staff_no = 'OGH-0001'
  AND appointment.starts_at = '2026-10-20 10:00+01';
\echo
\echo '=== Done.'
