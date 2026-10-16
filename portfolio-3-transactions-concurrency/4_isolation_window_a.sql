SET search_path TO hospital, public;

DELETE FROM payment WHERE payment.reference IN ('P3-ISO-0001', 'P3-ISO-0002');

\echo
\echo '=== ISOLATION, WINDOW A: billing officer checks how much has been paid on INV-2026-000003, twice in one transaction'
\echo 'Start 4_isolation_window_b.sql in a second window, then follow the steps.'
\echo
\echo '##### PART 1: READ COMMITTED (the PostgreSQL default)'
\prompt 'Once window B is open, press Enter here for step 1: ' go

\set ECHO queries
BEGIN ISOLATION LEVEL READ COMMITTED;
SELECT SUM(payment.amount) AS amount_paid
FROM payment
JOIN invoice ON invoice.invoice_id = payment.invoice_id
WHERE invoice.invoice_no = 'INV-2026-000003';
\set ECHO none
\echo
\echo '>>> Next: step 2 in window B'
\prompt 'Do step 2 in window B first, then press Enter here for step 3: ' go

\set ECHO queries
SELECT SUM(payment.amount) AS amount_paid
FROM payment
JOIN invoice ON invoice.invoice_id = payment.invoice_id
WHERE invoice.invoice_no = 'INV-2026-000003';
COMMIT;
\set ECHO none
\echo 'Same query, same transaction, different answer: a non-repeatable read.'
\echo
\echo '##### PART 2: REPEATABLE READ'
\set ECHO queries
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT SUM(payment.amount) AS amount_paid
FROM payment
JOIN invoice ON invoice.invoice_id = payment.invoice_id
WHERE invoice.invoice_no = 'INV-2026-000003';
\set ECHO none
\echo
\echo '>>> Next: step 4 in window B'
\prompt 'Do step 4 in window B first, then press Enter here for step 5: ' go

\set ECHO queries
SELECT SUM(payment.amount) AS amount_paid
FROM payment
JOIN invoice ON invoice.invoice_id = payment.invoice_id
WHERE invoice.invoice_no = 'INV-2026-000003';
COMMIT;
\set ECHO none
\echo 'The answer did not change: the transaction keeps reading the snapshot taken at its first query.'
\echo
\echo '--- After COMMIT, a new query sees the second payment'
\set ECHO queries
SELECT SUM(payment.amount) AS amount_paid
FROM payment
JOIN invoice ON invoice.invoice_id = payment.invoice_id
WHERE invoice.invoice_no = 'INV-2026-000003';
\set ECHO none
\echo
\echo '--- Remove the two demo payments'
DELETE FROM payment WHERE payment.reference IN ('P3-ISO-0001', 'P3-ISO-0002');
\echo
\echo '=== Done.'
