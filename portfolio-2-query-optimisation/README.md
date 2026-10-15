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

## Files

| File | Purpose |
|------|---------|
| `bulk_data.sql` | Adds realistic volumes of patients, doctors, appointments, diagnoses, lab orders, prescriptions, stock movements, invoices and payments on top of the Portfolio 1 seed |
