SET search_path TO hospital, public;

DELETE FROM appointment
USING staff
WHERE staff.staff_id = appointment.doctor_id
  AND staff.staff_no = 'OGH-0001'
  AND appointment.starts_at = '2026-10-20 10:00+01';

\echo
\echo '=== DOUBLE BOOKING, WINDOW A: receptionist books Dr Ese Okoro at 10:00 on 20 October for OGH/2026/0007'
\echo 'Start 5_double_booking_window_b.sql in a second window, then follow the steps.'
\echo
\prompt 'Once window B is open, press Enter here for step 1: ' go

\set ECHO queries
BEGIN;
INSERT INTO appointment (patient_id, doctor_id, starts_at, ends_at, reason)
SELECT patient.patient_id, staff.staff_id, '2026-10-20 10:00+01', '2026-10-20 10:30+01', 'Follow-up visit'
FROM patient
JOIN staff ON staff.staff_no = 'OGH-0001'
WHERE patient.hospital_no = 'OGH/2026/0007';
\set ECHO none
\echo 'The booking is saved inside the transaction but not committed yet.'
\echo
\echo '>>> Next: step 2 in window B. Window B will wait.'
\prompt 'Do step 2 in window B first, then press Enter here for step 3: ' go

\set ECHO queries
COMMIT;
\set ECHO none
\echo
\echo '>>> Next: look at window B, which has now carried on by itself'
