SET search_path TO hospital, public;

\echo
\echo '=== LOST UPDATE, WINDOW B: pharmacist Ruth Okpako dispenses 5 Salbutamol 4mg tablets'
\echo
\echo '##### PART 1: read the stock, work out the new figure, write it back (no lock)'
\prompt 'Do step 1 in window A first, then press Enter here for step 2: ' go

\set ECHO queries
BEGIN;
SELECT medicine.quantity_on_hand AS stock_seen
FROM medicine
WHERE medicine.name = 'Salbutamol' AND medicine.form = 'tablet' \gset
\set ECHO none
\echo 'Window B sees' :stock_seen 'tablets in stock'
\echo
\echo '>>> Next: step 3 in window A'
\prompt 'Do step 3 in window A first, then press Enter here for step 4: ' go

\set ECHO queries
UPDATE medicine
SET quantity_on_hand = :stock_seen - 5
WHERE medicine.name = 'Salbutamol' AND medicine.form = 'tablet';
COMMIT;
SELECT medicine.quantity_on_hand AS stock_now
FROM medicine
WHERE medicine.name = 'Salbutamol' AND medicine.form = 'tablet';
\set ECHO none
\echo '15 tablets left the pharmacy, but the stock only went down by 5. Window A''s update was lost.'
\echo
\echo '--- Put the stock back from the stock_movement ledger (no movements were recorded in this demo)'
\set ECHO queries
UPDATE medicine
SET quantity_on_hand = (SELECT COALESCE(SUM(stock_movement.quantity), 0)
                        FROM stock_movement
                        WHERE stock_movement.medicine_id = medicine.medicine_id)
WHERE medicine.name = 'Salbutamol' AND medicine.form = 'tablet';
SELECT medicine.quantity_on_hand AS stock_now
FROM medicine
WHERE medicine.name = 'Salbutamol' AND medicine.form = 'tablet';
\set ECHO none
\echo
\echo '>>> Next: step 5 in window A'
\prompt 'Do step 5 in window A first, then press Enter here for step 6: ' go

\echo
\echo '##### PART 2: the same, but the read locks the row with SELECT ... FOR UPDATE'
\echo 'Window B now waits here until window A commits.'
\set ECHO queries
BEGIN;
SELECT medicine.quantity_on_hand AS stock_seen
FROM medicine
WHERE medicine.name = 'Salbutamol' AND medicine.form = 'tablet'
FOR UPDATE \gset
\set ECHO none
\echo 'Window B got the lock and sees' :stock_seen 'tablets, the figure after window A''s change'

\set ECHO queries
UPDATE medicine
SET quantity_on_hand = :stock_seen - 5
WHERE medicine.name = 'Salbutamol' AND medicine.form = 'tablet';
COMMIT;
SELECT medicine.quantity_on_hand AS stock_now
FROM medicine
WHERE medicine.name = 'Salbutamol' AND medicine.form = 'tablet';
\set ECHO none
\echo 'The stock went down by 15, so both pharmacists'' changes were kept.'
\echo
\echo '--- Put the stock back from the stock_movement ledger'
\set ECHO queries
UPDATE medicine
SET quantity_on_hand = (SELECT COALESCE(SUM(stock_movement.quantity), 0)
                        FROM stock_movement
                        WHERE stock_movement.medicine_id = medicine.medicine_id)
WHERE medicine.name = 'Salbutamol' AND medicine.form = 'tablet';
\set ECHO none
\echo
\echo '=== Done.'
