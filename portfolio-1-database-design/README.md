# Portfolio 1 – Database Design and Modelling

## 1. Case study: Ojougboh General Hospital

**Organisation.** Ojougboh General Hospital (OGH) is a simulated large general hospital in Agbo delta State, Nigeria. It runs outpatient clinics across several departments, inpatient wards, a laboratory and a pharmacy. All staff are paid monthly through the hospital payroll.

**Nature of the business.** OGH provides outpatient consultations, inpatient admission, laboratory testing and dispensing of medicines. Patients are billed for each service and pay by cash, POS, bank transfer or through their NHIS (National Health Insurance) cover.

**Users of the database.**

| User | What they do in the system |
|------|----------------------------|
| Front desk / records officers | Register patients, book and cancel appointments |
| Doctors | Record diagnoses, write prescriptions, order lab tests, admit and discharge patients |
| Nurses | Assign beds, manage ward occupancy |
| Lab scientists | Record lab results |
| Pharmacists | Dispense medicines, receive and adjust stock |
| Billing officers | Raise invoices, record payments |
| HR / payroll officers | Manage staff records and salary grades, run monthly payroll |
| Management | Reports on revenue, bed occupancy, staff cost and clinical activity |

**Major data stored.**

- **Organisation:** departments, staff, staff profiles (including professional licences), salary grades
- **Clinical:** patients, their allergies and chronic or past conditions, appointments, admissions, wards and beds, diagnoses, prescriptions, lab tests and results
- **Pharmacy:** medicine catalogue, stock levels and a log of every stock movement
- **Billing:** invoices, invoice lines, payments
- **Payroll:** monthly payroll runs, payslips and deductions (PAYE tax, pension, NHF)

**Key operations the database supports.**

1. Register a patient and retrieve their full medical history
2. Book an appointment without double-booking a doctor
3. Admit a patient to an available bed and discharge them
4. Record diagnoses, prescriptions and lab orders against an appointment or admission
5. Dispense medicines and reduce stock without it ever going below zero
6. Raise an invoice and record full or part payments
7. Run monthly payroll for all staff as a single all-or-nothing operation
8. Produce management reports (monthly revenue, bed occupancy, payroll cost by department)

## 2. Design decisions

| Decision | Reason |
|----------|--------|
| One `staff` table with a `role` column, plus a 1:1 `staff_profile` | Every employee is paid the same way, so payroll needs one table. Personal and professional details (qualification, specialty, licence) sit in `staff_profile`, which can be secured separately. Licence fields cover doctors (MDCN), nurses (NMCN), pharmacists (PCN) and lab scientists (MLSCN). |
| Trigger `assert_staff_is_doctor` on appointment, admission, prescription and lab_order | A foreign key only proves the staff member exists. One shared trigger function also checks their role, so only doctors can be booked, admit patients, prescribe or order lab tests. |
| Diagnoses, prescriptions and lab orders belong to *either* an appointment *or* an admission | Enforced with `CHECK (num_nonnulls(appointment_id, admission_id) = 1)` so a record can never be attached to both or neither. |
| Exclusion constraints on appointments and admissions | The database itself refuses overlapping appointments for the same doctor and overlapping stays in the same bed. |
| Money stored as `NUMERIC(12,2)` | Floating point types cause rounding errors with currency. |
| Stock level kept on `medicine`, every change logged in `stock_movement` | The current level is fast to read, and the movement log gives a full audit trail of what was received, dispensed or written off. |
| Background history in `patient_allergy` and `patient_condition` | Allergies and chronic or past conditions are structured and safety-critical, so they are kept relational. A drug allergy can link to a `medicine`, so prescriptions that clash with a recorded allergy can be detected. Vitals, clinical notes and family history vary in shape and are modelled in MongoDB in Portfolio 4. |
| `disease` lookup table referenced by `diagnosis` and `patient_condition` | Typing disease names on every record produces inconsistent spellings ("Malaria", "malaria", "MP positive") that break reporting. Each disease is stored once and referenced by `disease_id`, removing the repeated text (3NF). The table also holds the WHO ICD-10 code (e.g. B54 for malaria) used for NHIS claims. A `notes` field keeps the doctor's own wording. |
| Invoice totals are not stored | The view `invoice_balance_view` calculates each invoice's total, amount paid and balance from its lines and payments, so they can never disagree. |
| Function `find_possible_duplicate_patients` checks for existing records before registration | Unique constraints stop a repeated hospital or NHIS number, but cannot stop the same person being registered again under a new number, and names, birth dates and phone numbers are not unique (family members often share a phone). The function returns likely matches with a reason, using the `pg_trgm` extension so misspelt names (e.g. "Okonkow" for "Okonkwo") are still found. A records officer then decides whether it is the same person. |
| View `ward_occupancy_view` | Shows total, occupied, available and maintenance beds per ward without repeating the query each time. |
| Payslips store a snapshot of pay components | A payslip must stay exactly as issued even if the salary grade changes later. This is a deliberate, documented exception to normalisation. |
| `ON DELETE RESTRICT` on clinical and financial records | Medical and financial history must never disappear through a cascade. `CASCADE` is used only for pure child lines (invoice items, prescription items, deductions). |

## 3. Files

| File | Purpose |
|------|---------|
| `schema.sql` | Creates the `hospital` schema: all tables, keys, constraints, triggers and views |
| `seed.sql` | Sample data for every table: 16 staff, 10 patients, appointments, admissions, lab results, prescriptions, pharmacy stock, invoices and the September 2026 payroll. Runs in one transaction and can be re-run safely |
| `constraint_tests.sql` | 26 tests: 23 try to break the hospital's business rules (double-booking, overfilling beds, negative stock, duplicate patients and staff, duplicate payslips and more) and show the database refuses them; 3 show the duplicate-patient check at registration. Every test is rolled back, so no data changes |
| `evidence/constraint_tests_output.txt` | Output from running the constraint tests |
| `er-diagram.drawio` | ER diagram in seven pages: a module overview, then one page per module (Organisation, Patients, Clinical care, Pharmacy, Billing, Payroll). Open with draw.io or the VS Code Draw.io Integration extension |
