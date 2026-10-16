SET search_path TO hospital, public;

\echo
\echo '=== ISOLATION, WINDOW B: the patient pays at the cashier while window A is reading'
\echo
\prompt 'Do step 1 in window A first, then press Enter here for step 2: ' go

\set ECHO queries
INSERT INTO payment (invoice_id, amount, method, reference, received_by)
SELECT invoice.invoice_id, 1000.00, 'cash', 'P3-ISO-0001', staff.staff_id
FROM invoice
JOIN staff ON staff.staff_no = 'OGH-0014'
WHERE invoice.invoice_no = 'INV-2026-000003';
\set ECHO none
\echo 'A payment of 1,000 naira is saved and committed straight away (autocommit).'
\echo
\echo '>>> Next: step 3 in window A'
\prompt 'Do step 3 in window A first, then press Enter here for step 4: ' go

\set ECHO queries
INSERT INTO payment (invoice_id, amount, method, reference, received_by)
SELECT invoice.invoice_id, 1000.00, 'cash', 'P3-ISO-0002', staff.staff_id
FROM invoice
JOIN staff ON staff.staff_no = 'OGH-0014'
WHERE invoice.invoice_no = 'INV-2026-000003';
\set ECHO none
\echo 'A second payment of 1,000 naira is saved and committed.'
\echo
\echo '>>> Next: step 5 in window A'
\echo
\echo '=== Done in window B.'
