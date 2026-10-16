# Portfolio 3 – Transactions and Concurrency

Five examples from the hospital's daily work show how PostgreSQL keeps data correct when a task has several steps, when a step fails, and when two members of staff work on the same data at the same time. They run on the Portfolio 1 database. The Portfolio 2 bulk data can be loaded or not; nothing here depends on it.

| # | Example | What it shows | Files |
|---|---|---|---|
| 1 | Dispensing one dose of an inpatient's medicine | **Commit**: three changes saved together | `1_commit.sql` |
| 2 | Dispensing too many doses by mistake | **Rollback**: an error undoes the steps that had already worked | `2_rollback.sql` |
| 3 | Two pharmacists dispensing the same medicine at once | **Concurrency problem** (lost update) and **control** (row lock with `SELECT ... FOR UPDATE`) | `3_lost_update_window_a.sql`, `3_lost_update_window_b.sql` |
| 4 | A billing officer reading a balance while the patient pays | **Isolation levels**: `READ COMMITTED` and `REPEATABLE READ` | `4_isolation_window_a.sql`, `4_isolation_window_b.sql` |
| 5 | Two receptionists booking the same doctor's slot | **Control** by a constraint: the second booking waits, then is rejected | `5_double_booking_window_a.sql`, `5_double_booking_window_b.sql` |

Examples 3, 4 and 5 need two sessions, so each has a script for window A and one for window B. The scripts stop at `\prompt` before every step and say which window goes next, so you only have to press Enter in the right window. Each script turns on `\set ECHO queries` around the important statements, so the terminal shows the SQL as well as the results.

Examples 2 to 5 leave the database as they found it. Example 1 commits for real, so each run dispenses one more dose. The prescription allows 7 doses and the seed has dispensed 3, so example 1 can be run 4 times before the prescription is used up.

## 1. Commit

Pharmacist Ruth Okpako gives inpatient `OGH/2026/0005` one dose of Ceftriaxone 1g. Dispensing changes three tables:

1. `prescription_item.quantity_dispensed` goes up by 1.
2. A `dispensed` row of −1 is added to `stock_movement`.
3. `medicine.quantity_on_hand` goes down by 1.

If only some of these were saved, the prescription, the stock ledger and the stock level would disagree. Putting them between `BEGIN` and `COMMIT` makes them one unit (**atomicity**). Once `COMMIT` returns, the change is permanent even if the server stops (**durability**).

In the recorded run the stock went from 75 to 74, the doses dispensed from 3 to 4, and a −1 movement was added to the ledger (`evidence/1_commit_output.txt`).

## 2. Rollback

The same task, but 10 doses are typed instead of 1. The stock update and the stock movement both succeed, and a `SELECT` inside the transaction shows the stock already 10 lower. Then the `prescription_item` update breaks the check `quantity_dispensed BETWEEN 0 AND quantity`, because only 7 doses were prescribed.

After the error, PostgreSQL refuses every other statement in the transaction ("current transaction is aborted"), so nothing more can be done except `ROLLBACK`. After the rollback, the stock is back where it started and the −10 movement does not exist. A failure at the last step undid the steps that had already worked.

In the recorded run the stock was 64 inside the transaction, the update failed on `prescription_item_check`, and after `ROLLBACK` the stock was 74 again with no −10 movement (`evidence/2_rollback_output.txt`).

## 3. Lost update, and the fix

The pharmacy screen reads `quantity_on_hand`, takes off what is being dispensed, and saves the new figure. Two pharmacists do this at the same time with Salbutamol tablets: Emeka Ani (window A) takes 10 and Ruth Okpako (window B) takes 5.

| Step | Window A | Window B |
|---|---|---|
| 1 | Reads the stock: 40 | |
| 2 | | Reads the stock: also 40 |
| 3 | Saves 40 − 10 = 30 and commits | |
| 4 | | Saves 40 − 5 = 35 and commits |

15 tablets left the pharmacy, but the stock only went down by 5. Window B wrote over window A's change because it worked from a figure that was already out of date. `READ COMMITTED` does not stop this, because each statement on its own is correct.

Part 2 repeats the steps, but each window reads with `SELECT ... FOR UPDATE`, which locks the row:

| Step | Window A | Window B |
|---|---|---|
| 5 | Reads 40 and locks the row | |
| 6 | | Tries to read with `FOR UPDATE` and **waits** |
| 7 | Saves 30, commits and releases the lock | Gets the lock, reads 30, saves 25 and commits |

The stock now goes down by the full 15. The lock makes the second pharmacist wait for the first to finish (**pessimistic locking**).

Another fix would be to let the database do the arithmetic, `SET quantity_on_hand = quantity_on_hand - 10`. An `UPDATE` always works on the latest committed row, so nothing is lost. `FOR UPDATE` is shown because the screen needs to read the stock first, to check there is enough before dispensing.

After each part, window B resets the stock from the `stock_movement` ledger, since the demo did not record any movements. The recorded run gave exactly the figures in the two tables (`evidence/3_lost_update_window_a_output.txt` and `_b_output.txt`).

## 4. Isolation levels

Billing officer Samuel Uwadia (window A) checks how much has been paid on invoice `INV-2026-000003` twice in one transaction. Between the two reads, the patient pays 1,000 naira at the cashier (window B, saved and committed straight away).

| Isolation level | First read | Second read | Why |
|---|---|---|---|
| `READ COMMITTED` (default) | 8,000 | 9,000 | Each statement sees everything committed before it started, so the second read sees the new payment. This is a **non-repeatable read** |
| `REPEATABLE READ` | 9,000 | 9,000 | The transaction takes one snapshot at its first query and reads from it until it ends. The second payment only shows up after `COMMIT`, as 10,000 |

The seed has one payment of 8,000 naira on this invoice, out of a total of 12,860. A report that adds up several tables, such as a daily cash summary, should use `REPEATABLE READ`, so that every figure comes from the same moment.

PostgreSQL never allows **dirty reads**, meaning reading another transaction's uncommitted changes, even at `READ UNCOMMITTED`. That level behaves like `READ COMMITTED`, so it is not shown separately. `SERIALIZABLE` also prevents anomalies that `REPEATABLE READ` allows, but it can cancel a transaction that the application then has to retry. That is more than this case study needs.

The recorded run gave exactly these figures (`evidence/4_isolation_window_a_output.txt`). Window A deletes the two demo payments at the end.

## 5. Double booking

Two receptionists book Dr Ese Okoro at 10:00 on 20 October 2026 for two different patients.

| Step | Window A | Window B |
|---|---|---|
| 1 | `BEGIN`, inserts the booking (not committed) | |
| 2 | | `BEGIN`, inserts a booking for the same slot and **waits** |
| 3 | `COMMIT` | Is rejected by `no_doctor_double_booking` |

Window B's insert cannot be checked against the exclusion constraint until it knows whether window A's booking will be kept, so it waits. When A commits, B fails with a constraint violation. If A had rolled back, B's booking would have gone through. This is the Portfolio 1 constraint working as a concurrency control. Checking for a free slot in the application first and then inserting would not be safe, because both receptionists could see the slot as free at the same moment.

In the recorded run window B failed with `conflicting key value violates exclusion constraint "no_doctor_double_booking"`, and the slot held only window A's booking for `OGH/2026/0007` (`evidence/5_double_booking_window_b_output.txt`). The wait itself does not show in a text file, which is why the screenshot is taken while window B is waiting. Window B deletes the demo booking at the end.

## How to run

Run from the repository root, after the Portfolio 1 schema and seed are loaded.

Examples 1 and 2 run on their own, and their output can go straight to a file:

```bash
psql -U postgres -d ojougboh_hospital -f portfolio-3-transactions-concurrency/1_commit.sql > portfolio-3-transactions-concurrency/evidence/1_commit_output.txt 2>&1
```

```bash
psql -U postgres -d ojougboh_hospital -f portfolio-3-transactions-concurrency/2_rollback.sql > portfolio-3-transactions-concurrency/evidence/2_rollback_output.txt 2>&1
```

For examples 3, 4 and 5, open two terminals side by side. Start the window A command in the left one and the window B command in the right one, then follow the prompts. `tee` shows the output on screen and also saves it to a file, so each window gets its own evidence file. For example 3:

```bash
psql -U postgres -d ojougboh_hospital -f portfolio-3-transactions-concurrency/3_lost_update_window_a.sql 2>&1 | tee portfolio-3-transactions-concurrency/evidence/3_lost_update_window_a_output.txt
```

```bash
psql -U postgres -d ojougboh_hospital -f portfolio-3-transactions-concurrency/3_lost_update_window_b.sql 2>&1 | tee portfolio-3-transactions-concurrency/evidence/3_lost_update_window_b_output.txt
```

Example 4:

```bash
psql -U postgres -d ojougboh_hospital -f portfolio-3-transactions-concurrency/4_isolation_window_a.sql 2>&1 | tee portfolio-3-transactions-concurrency/evidence/4_isolation_window_a_output.txt
```

```bash
psql -U postgres -d ojougboh_hospital -f portfolio-3-transactions-concurrency/4_isolation_window_b.sql 2>&1 | tee portfolio-3-transactions-concurrency/evidence/4_isolation_window_b_output.txt
```

Example 5:

```bash
psql -U postgres -d ojougboh_hospital -f portfolio-3-transactions-concurrency/5_double_booking_window_a.sql 2>&1 | tee portfolio-3-transactions-concurrency/evidence/5_double_booking_window_a_output.txt
```

```bash
psql -U postgres -d ojougboh_hospital -f portfolio-3-transactions-concurrency/5_double_booking_window_b.sql 2>&1 | tee portfolio-3-transactions-concurrency/evidence/5_double_booking_window_b_output.txt
```

Start window B first, then window A. Each prompt names the step that has to run first in the other window, so the windows take turns and Enter is never pressed twice in a row in the same window. If one window runs all its steps alone, the two sessions never overlap and the example shows nothing. A screenshot of both windows at the end of each example shows the two sessions side by side, and goes in `evidence/` too.

## Files

| File | Purpose |
|------|---------|
| `1_commit.sql` | Dispenses one dose as a single committed transaction |
| `2_rollback.sql` | A dispensing error that rolls back the steps already done |
| `3_lost_update_window_a.sql` / `_b.sql` | Lost update without locking, then the same steps with `SELECT ... FOR UPDATE` |
| `4_isolation_window_a.sql` / `_b.sql` | The same read twice under `READ COMMITTED` and `REPEATABLE READ` |
| `5_double_booking_window_a.sql` / `_b.sql` | Two bookings for the same slot at once |
| `evidence/` | Output files for every example (one per window for 3–5) and screenshots |
