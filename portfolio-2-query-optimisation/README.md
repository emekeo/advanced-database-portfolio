# Portfolio 2 – Query Processing and Optimisation

## 1. Test data at realistic volume

The Portfolio 1 seed has 10 patients and 13 appointments. At that size PostgreSQL reads every table in full whatever indexes exist, because scanning a few rows is cheaper than using an index. Execution plans would look the same with or without indexes, so there would be nothing to measure.

`bulk_data.sql` adds about 2 years and 9 months of outpatient activity (January 2024 to September 2026) on top of the seed data:

| Table | Rows after loading | What was added |
|---|---|---|
| `patient` | 50,010 | 50,000 patients registered between 2018 and 2023 |
| `staff` | 56 | 40 more doctors across the four clinical departments, each with a profile, MDCN licence and a September 2026 payslip |
| `appointment` | 439,265 | Weekday clinics, 08:00 to 16:00 in 30-minute slots, about 85% of slots booked. 86% completed, 6% no-show, 8% cancelled |
| `diagnosis` | 377,761 | One primary diagnosis for each completed appointment. Malaria is the most common, as it is in Delta State |
| `lab_order` | 234,179 | The test that matches the diagnosis (malaria test for malaria, Widal for typhoid, and so on), with results |
| `prescription` / `prescription_item` | 302,812 / 474,059 | The standard treatment for each diagnosis, fully dispensed |
| `stock_movement` | 474,370 | A movement for every item dispensed, plus a monthly delivery for each medicine |
| `invoice` / `invoice_item` | 377,758 / 1,085,993 | One invoice per completed visit, with consultation, lab and medicine lines |
| `payment` | 347,643 | 85% of invoices paid in full, 7% part paid, 8% unpaid |

Wards, beds, admissions and payroll stay at seed size. No Portfolio 2 query needs them at volume.

**How the data was generated.** It is all plain SQL using `generate_series` and `random()`. Names, streets and phone prefixes are picked from Nigerian lists. `setseed(0.42)` at the start makes the random values the same on every run, so the results in this portfolio can be reproduced exactly.

**The business rules still apply.** The data goes in through the normal tables with every constraint and trigger switched on. The exclusion constraint checks that no doctor is double-booked, the trigger checks that every appointment, prescription and lab order is by a doctor, and every foreign key is checked. A few choices keep the bulk data consistent with Portfolio 1:

- Appointment slots are fixed per doctor, so no two bookings for a doctor overlap.
- Each month's medicine deliveries equal what was dispensed that month. The stock levels on `medicine` therefore end exactly where the seed left them, and the Portfolio 1 stock test still behaves the same.
- Bulk invoice numbers include the appointment number (for example `INV-2025-0123456`), so they can never clash with the seven seed invoices.
- All bulk activity is dated before 1 October 2026. Seed activity is from October 2026, so the two never overlap.

The script ends with `VACUUM ANALYZE`, so the planner has up-to-date statistics before any plans are captured.

**Effect on the Portfolio 1 tests.** All 26 tests still give the same result except test 24, the duplicate check for "Chiamaka Okonkow". On seed data it finds one match. With 50,000 patients it finds 24, because names such as "Chiamaka Okoro" are common and score just over the 0.6 similarity threshold. This is looked at in the query analysis below.

### How to run

Run this after the Portfolio 1 schema and seed, from the repository root. It takes about 6–7 minutes, mostly because every appointment is checked against the double-booking constraint.

```bash
psql -U postgres -d ojougboh_hospital -f portfolio-1-database-design/schema.sql
```

```bash
psql -U postgres -d ojougboh_hospital -f portfolio-1-database-design/seed.sql
```

```bash
psql -U postgres -d ojougboh_hospital -f portfolio-2-query-optimisation/bulk_data.sql
```

Check the row counts:

```bash
psql -U postgres -d ojougboh_hospital -c "SELECT relname, n_live_tup FROM pg_stat_user_tables WHERE schemaname = 'hospital' ORDER BY n_live_tup DESC;"
```

## 2. The queries

`queries.sql` holds five queries. Each one supports a key operation from the case study. Queries 3 and 5 each come in two versions: the original version (a) and a rewritten version (b) that can use indexes.

| # | Query | Who uses it | Indexes added for it |
|---|---|---|---|
| 1 | Visit history for one patient, newest first, with the primary diagnosis | Doctor reviewing a patient | `appointment (patient_id, starts_at)`, `diagnosis (appointment_id)` |
| 2 | One doctor's clinic list for a day | Front desk and doctors | `appointment (doctor_id, starts_at)` |
| 3a / 3b | Outstanding invoices for one patient | Billing | `invoice (patient_id)`, `payment (invoice_id)` |
| 4 | Ten most common primary diagnoses in a month | Management report | `diagnosis (diagnosed_at)` |
| 5a / 5b | Duplicate check when registering "Chiamaka Okonkow" (the same check as Portfolio 1 test 24) | Records officer | `patient (phone)`, `patient (date_of_birth)`, GIN trigram index on `first_name \|\| ' ' \|\| last_name` |

Queries 1 and 3 use patient `OGH/2022/34210`. With 24 visits and 22 invoices, this patient has the most visits in the bulk data. Query 2 uses doctor `OGH-0017` on Monday 14 September 2026. All results are in [evidence/query_results.txt](evidence/query_results.txt). In both pairs, the rewritten version returns exactly the same rows as the original.

The indexes are all in `indexes.sql`. The file ends with `ANALYZE` so the planner sees the new indexes straight away.

## 3. Execution plans before and after indexing

Each query was run with `EXPLAIN (ANALYZE, BUFFERS)`, once before `indexes.sql` and once after. The full plans are in [evidence/plans_before.txt](evidence/plans_before.txt) and [evidence/plans_after.txt](evidence/plans_after.txt).

| # | Before | After | Plan before | Plan after |
|---|---:|---:|---|---|
| 1 | 84.8 ms | 1.4 ms | Parallel sequential scans of `appointment` (439,265 rows) and `diagnosis` (377,761 rows) to find 24 visits | Bitmap index scan on `appointment_patient_starts_at_idx`, then one `diagnosis_appointment_idx` lookup per visit |
| 2 | 41.5 ms | 0.5 ms | Parallel sequential scan of `appointment`, about 438,600 rows thrown away by the filter | Bitmap index scan on `appointment_doctor_starts_at_idx` reads only the 11 appointments |
| 3a | 920.9 ms | 863.8 ms | Totals every one of 1,061,802 invoice lines and 347,648 payments, then keeps the patient's 22 invoices | Still totals everything. The new payment index only changes how the payments are grouped |
| 3b | 543.5 ms | 2.9 ms | Invoice lines found through the primary key, but `payment` scanned in full once per invoice (22 times) | Index lookups on `invoice_patient_idx`, `invoice_item_pkey` and `payment_invoice_idx` for the 22 invoices only |
| 4 | 43.6 ms | 8.6 ms | Parallel sequential scan of `diagnosis`, about 366,100 rows thrown away | Index range scan on `diagnosis_diagnosed_at_idx` reads only September's 11,646 diagnoses |
| 5a | 150.5 ms | 161.3 ms | Sequential scan of all 50,010 patients, `similarity()` worked out for each one | No change. No index can be used |
| 5b | 159.2 ms | 2.6 ms | Sequential scan, same as 5a | `BitmapOr` of the phone, date of birth and trigram indexes. Only 77 candidate rows are checked |

Times change by a few milliseconds between runs, so only the large differences matter. Some of the "before" times also include reading pages from disk (`read=` in the `Buffers` lines), while the "after" runs found more pages already in memory.

### What the plans show

**PostgreSQL does not index foreign keys automatically.** `appointment.patient_id`, `diagnosis.appointment_id`, `invoice.patient_id` and `payment.invoice_id` are all foreign keys. Without an index, finding one patient's rows meant reading the whole table, so query 1 read 439,265 appointments to return 24. With an index on the foreign key, PostgreSQL goes straight to the matching rows. Query 1 went from 84.8 ms to 1.4 ms, about 60 times faster.

**Column order matters in a composite index.** In `appointment (doctor_id, starts_at)`, the equality column comes first and the range column second. One doctor's appointments are then stored together in time order, so a day's clinic is a single short range in the index. The existing GiST index behind the `no_doctor_double_booking` constraint was not used for query 2, for two reasons. It indexes the expression `tstzrange(starts_at, ends_at)`, not `starts_at` itself. It is also a partial index (`WHERE status <> 'cancelled'`), but the clinic list has to show cancelled appointments too.

**A view can hide the real cost.** `invoice_balance_view` adds up every invoice and every payment in the hospital first, and only then joins to the invoices for the chosen patient. PostgreSQL cannot push the patient filter down into those `GROUP BY` subqueries. So indexing made almost no difference to query 3a (921 ms to 864 ms). Query 3b works out the totals with `LATERAL` subqueries, one invoice at a time, so it only touches this patient's 22 invoices. Before indexing, 3b was still slow, because it scanned `payment` in full for each invoice. Only the rewrite and the `payment (invoice_id)` index together brought it down to 2.9 ms, about 300 times faster than the view.

**An index cannot help a function call in the `WHERE` clause.** Query 5a filters on `similarity(...) > 0.6`, which PostgreSQL has to work out for every row. The GIN trigram index can only answer the `%` operator, which means "similarity is at least `pg_trgm.similarity_threshold`". Query 5b sets that threshold to 0.6. Its first condition (same phone, OR same date of birth, OR name `%` the new name) can be answered by three indexes combined with `BitmapOr`. The original exact rule then checks only those 77 candidates. The index expression `first_name || ' ' || last_name` has to be written exactly the same way in the query, or the index is not used.

**Small result, big table.** Query 4 returns 11,646 of the 377,761 diagnoses, about 3% of the table. At that size, an index range scan is cheaper than reading the whole table. For a whole year, which is about a third of the table, a sequential scan would probably win again. The planner makes that choice from the statistics collected by `ANALYZE`.

### Test 24 with real volumes

Queries 5a and 5b both find 24 possible duplicates for "Chiamaka Okonkow":

- 11 are named "Chiamaka Okonkwo" (similarity 0.7). Only one of them is the seed patient `OGH/2026/0002`, the only one with the same date of birth.
- 13 are named "Chiamaka Okoro" (similarity just over 0.6).

Query 5b fixes the speed, but not the usefulness of the result. With common Nigerian names, matching on the name alone at 0.6 brings back many people who are clearly different. The real match also appears 11th, because the results are sorted by name similarity alone. A better rule would put matches on date of birth or phone first, and either raise the name-only threshold or drop it.

### Cost of the indexes

Indexes are not free. Every insert or update on a table also has to update each of its indexes, and every index takes disk space. `appointment` now has three indexes to update on each booking: the two new B-trees and the GiST index for the double-booking constraint. A clinic books a few hundred appointments a day but looks them up far more often, so the trade is worth it here. No index was added for a column that no query searches on.

### Left unchanged in Portfolio 1

`find_possible_duplicate_patients` still uses the 5a form, and `invoice_balance_view` still totals every invoice. Changing either one would change the Portfolio 1 schema. The fix for each is shown here as queries 5b and 3b.

### How to run

Run these after loading the bulk data, from the repository root, in this order. `queries.sql` runs on its own to show the results. With `-v explain=...`, psql puts `EXPLAIN (ANALYZE, BUFFERS)` in front of every query, so the same file prints the plans instead.

```bash
psql -U postgres -d ojougboh_hospital -f portfolio-2-query-optimisation/queries.sql > portfolio-2-query-optimisation/evidence/query_results.txt 2>&1
```

```bash
psql -U postgres -d ojougboh_hospital -v explain="EXPLAIN (ANALYZE, BUFFERS)" -f portfolio-2-query-optimisation/queries.sql > portfolio-2-query-optimisation/evidence/plans_before.txt 2>&1
```

```bash
psql -U postgres -d ojougboh_hospital -f portfolio-2-query-optimisation/indexes.sql > portfolio-2-query-optimisation/evidence/indexes_output.txt 2>&1
```

```bash
psql -U postgres -d ojougboh_hospital -v explain="EXPLAIN (ANALYZE, BUFFERS)" -f portfolio-2-query-optimisation/queries.sql > portfolio-2-query-optimisation/evidence/plans_after.txt 2>&1
```

## Files

| File | Purpose |
|------|---------|
| `bulk_data.sql` | Adds realistic volumes of patients, doctors, appointments, diagnoses, lab orders, prescriptions, stock movements, invoices and payments on top of the Portfolio 1 seed |
| `queries.sql` | The five queries, run plain for results or with `-v explain=...` for execution plans |
| `indexes.sql` | The nine indexes added after the baseline plans were captured |
| `evidence/query_results.txt` | Output of every query |
| `evidence/plans_before.txt` | Execution plans with only the Portfolio 1 indexes |
| `evidence/indexes_output.txt` | Output of creating the indexes |
| `evidence/plans_after.txt` | Execution plans after `indexes.sql` |
