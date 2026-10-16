SET search_path TO hospital, public;

\echo
\echo '=== LOST UPDATE, WINDOW A: pharmacist Emeka Ani dispenses 10 Salbutamol 4mg tablets'
\echo 'Start 3_lost_update_window_b.sql in a second window, then follow the steps.'
\echo
\echo '##### PART 1: read the stock, work out the new figure, write it back (no lock)'
\prompt 'Once window B is open, press Enter here for step 1: ' go

\set ECHO queries
BEGIN;
SELECT medicine.quantity_on_hand AS stock_seen
FROM medicine
WHERE medicine.name = 'Salbutamol' AND medicine.form = 'tablet' \gset
\set ECHO none
\echo 'Window A sees' :stock_seen 'tablets in stock'
\echo
\echo '>>> Next: step 2 in window B'
\prompt 'Do step 2 in window B first, then press Enter here for step 3: ' go

\set ECHO queries
UPDATE medicine
SET quantity_on_hand = :stock_seen - 10
WHERE medicine.name = 'Salbutamol' AND medicine.form = 'tablet';
COMMIT;
\set ECHO none
\echo 'Window A saved' :stock_seen '- 10 and committed'
\echo
\echo '>>> Next: step 4 in window B'
\prompt 'Do step 4 in window B first, then press Enter here for step 5: ' go

\echo
\echo '##### PART 2: the same, but the read locks the row with SELECT ... FOR UPDATE'
\set ECHO queries
BEGIN;
SELECT medicine.quantity_on_hand AS stock_seen
FROM medicine
WHERE medicine.name = 'Salbutamol' AND medicine.form = 'tablet'
FOR UPDATE \gset
\set ECHO none
\echo 'Window A sees' :stock_seen 'tablets in stock and holds a lock on the row'
\echo
\echo '>>> Next: step 6 in window B. Window B will wait.'
\prompt 'Do step 6 in window B first (it will wait), then press Enter here for step 7: ' go

\set ECHO queries
UPDATE medicine
SET quantity_on_hand = :stock_seen - 10
WHERE medicine.name = 'Salbutamol' AND medicine.form = 'tablet';
COMMIT;
\set ECHO none
\echo 'Window A saved' :stock_seen '- 10, committed and released the lock'
\echo
\echo '>>> Next: look at window B, which has now carried on by itself'
