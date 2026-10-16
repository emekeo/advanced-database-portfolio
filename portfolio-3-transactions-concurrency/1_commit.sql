SET search_path TO hospital, public;

SELECT prescription_item.prescription_id, prescription_item.medicine_id
FROM prescription_item
JOIN prescription ON prescription.prescription_id = prescription_item.prescription_id
JOIN admission    ON admission.admission_id = prescription.admission_id
JOIN patient      ON patient.patient_id = admission.patient_id
JOIN medicine     ON medicine.medicine_id = prescription_item.medicine_id
WHERE patient.hospital_no = 'OGH/2026/0005'
  AND medicine.name = 'Ceftriaxone'
  AND medicine.form = 'injection' \gset

\echo
\echo '=== COMMIT: pharmacist Ruth Okpako dispenses one dose of Ceftriaxone 1g to inpatient OGH/2026/0005'
\echo
\echo '--- Before the transaction'
SELECT medicine.quantity_on_hand, prescription_item.quantity AS prescribed, prescription_item.quantity_dispensed
FROM prescription_item
JOIN medicine ON medicine.medicine_id = prescription_item.medicine_id
WHERE prescription_item.prescription_id = :prescription_id
  AND prescription_item.medicine_id = :medicine_id;

\set ECHO queries

BEGIN;

UPDATE prescription_item
SET quantity_dispensed = prescription_item.quantity_dispensed + 1
WHERE prescription_item.prescription_id = :prescription_id
  AND prescription_item.medicine_id = :medicine_id;

INSERT INTO stock_movement (medicine_id, movement_type, quantity, prescription_id, recorded_by)
SELECT :medicine_id, 'dispensed', -1, :prescription_id, staff.staff_id
FROM staff
WHERE staff.staff_no = 'OGH-0012';

UPDATE medicine
SET quantity_on_hand = medicine.quantity_on_hand - 1
WHERE medicine.medicine_id = :medicine_id;

COMMIT;

\set ECHO none

\echo
\echo '--- After COMMIT: all three changes are saved together'
SELECT medicine.quantity_on_hand, prescription_item.quantity AS prescribed, prescription_item.quantity_dispensed
FROM prescription_item
JOIN medicine ON medicine.medicine_id = prescription_item.medicine_id
WHERE prescription_item.prescription_id = :prescription_id
  AND prescription_item.medicine_id = :medicine_id;

SELECT stock_movement.movement_id, stock_movement.movement_type, stock_movement.quantity, stock_movement.recorded_at
FROM stock_movement
WHERE stock_movement.prescription_id = :prescription_id
  AND stock_movement.medicine_id = :medicine_id
ORDER BY stock_movement.movement_id DESC
LIMIT 1;
