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
\echo '=== ROLLBACK: the pharmacist types 10 doses instead of 1, which is more than the prescription allows'
\echo
\echo '--- Before the transaction'
SELECT medicine.quantity_on_hand, prescription_item.quantity AS prescribed, prescription_item.quantity_dispensed
FROM prescription_item
JOIN medicine ON medicine.medicine_id = prescription_item.medicine_id
WHERE prescription_item.prescription_id = :prescription_id
  AND prescription_item.medicine_id = :medicine_id;

\set ECHO queries

BEGIN;

UPDATE medicine
SET quantity_on_hand = medicine.quantity_on_hand - 10
WHERE medicine.medicine_id = :medicine_id;

INSERT INTO stock_movement (medicine_id, movement_type, quantity, prescription_id, recorded_by)
SELECT :medicine_id, 'dispensed', -10, :prescription_id, staff.staff_id
FROM staff
WHERE staff.staff_no = 'OGH-0012';

SELECT medicine.quantity_on_hand AS stock_inside_transaction
FROM medicine
WHERE medicine.medicine_id = :medicine_id;

UPDATE prescription_item
SET quantity_dispensed = prescription_item.quantity_dispensed + 10
WHERE prescription_item.prescription_id = :prescription_id
  AND prescription_item.medicine_id = :medicine_id;

SELECT medicine.quantity_on_hand
FROM medicine
WHERE medicine.medicine_id = :medicine_id;

ROLLBACK;

\set ECHO none

\echo
\echo '--- After ROLLBACK: the stock update and the stock movement were undone as well'
SELECT medicine.quantity_on_hand, prescription_item.quantity AS prescribed, prescription_item.quantity_dispensed
FROM prescription_item
JOIN medicine ON medicine.medicine_id = prescription_item.medicine_id
WHERE prescription_item.prescription_id = :prescription_id
  AND prescription_item.medicine_id = :medicine_id;

SELECT COUNT(*) AS movements_of_minus_10
FROM stock_movement
WHERE stock_movement.prescription_id = :prescription_id
  AND stock_movement.quantity = -10;
